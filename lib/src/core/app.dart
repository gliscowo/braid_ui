import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:diamond_gl/diamond_gl.dart' as dgl;
import 'package:diamond_gl/glfw.dart';
import 'package:diamond_gl/opengl.dart';
import 'package:image/image.dart';
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../events_binding.dart';
import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import '../primitive_renderer.dart';
import '../resources.dart';
import '../surface.dart';
import '../text/text_renderer.dart';
import '../widgets/basic.dart';
import '../widgets/focus.dart';
import '../widgets/image.dart';
import '../widgets/inspector.dart';
import 'constraints.dart';
import 'cursors.dart';
import 'math.dart';
import 'reload_hook.dart';

Future<void> runBraidApp({required AppState app, int targetFps = 60, bool reloadHook = false}) async {
  StreamSubscription<()>? reloadSubscription;

  if (reloadHook) {
    reloadSubscription = (await getReloadHook()).listen((event) {
      app.rebuildRoot();
    });
  }

  final oneFrame = Duration(microseconds: Duration.microsecondsPerSecond ~/ targetFps);

  final timeSource = Stopwatch()..start();
  var lastFrameTimestamp = timeSource.elapsedMicroseconds;

  final finished = Completer();
  Timer.periodic(oneFrame, (timer) {
    if (!app._running) {
      timer.cancel();
      finished.complete();

      return;
    }

    final effectiveDelta = Duration(microseconds: timeSource.elapsedMicroseconds - lastFrameTimestamp);
    lastFrameTimestamp = timeSource.elapsedMicroseconds;

    app.updateWidgetsAndInteractions(effectiveDelta);

    app.surface.beginDrawing();
    app.draw();
    app.surface.endDrawing();
  });

  await finished.future;

  app.dispose();

  reloadSubscription?.cancel();
}

Future<(AppState, dgl.Window)> createBraidAppWithWindow({
  String name = 'braid app',
  Logger? baseLogger,
  int width = 1000,
  int height = 750,
  bool enableInspector = true,
  required BraidResources resources,
  required String defaultFontFamily,
  required Widget widget,
}) async {
  final surface = WindowSurface.createWindow(title: name, width: width, height: height, logger: baseLogger);
  final events = WindowEventsBinding(window: surface.window);

  final app = await createBraidApp(
    baseLogger: baseLogger,
    enableInspector: enableInspector,
    surface: surface,
    eventsBinding: events,
    resources: resources,
    defaultFontFamily: defaultFontFamily,
    widget: widget,
  );

  return (app, surface.window);
}

/// Initialize all state necessary to drive the braid application
/// represented by [widget]. This function will:
/// 1. Ensure OpenGL and GLFW are available and loaded, loading them if
///    necessary
/// 2. If necessary, initialize DiamondGL logging with [baseLogger]
/// 3. If no [window] was provided, create one and associate it with
///    the application
/// 4. Load the default shaders and fonts
///
/// If everything succeeds, an [AppState] encapsulating all application state
/// is created and returned
///
/// See also:
/// - [runBraidApp]
/// - [AppState]
/// - [Widget]
Future<AppState> createBraidApp({
  Logger? baseLogger,
  bool enableInspector = true,
  required Surface surface,
  required EventsBinding eventsBinding,
  required BraidResources resources,
  required String defaultFontFamily,
  required Widget widget,
}) async {
  final renderContext = await surface.createRenderContext(resources);

  final (defaultFont, materialSymbols) = await (
    FontFamily.load(resources, defaultFontFamily),
    FontFamily.load(resources, 'MaterialSymbols'),
  ).wait;

  final textRenderer = TextRenderer(renderContext, defaultFont, {
    'default': defaultFont,
    'MaterialSymbols': materialSymbols,
  });

  final projection = makeOrthographicMatrix(0, surface.width.toDouble(), surface.height.toDouble(), 0, -10, 10);
  surface.onResize.listen((event) {
    setOrthographicMatrix(projection, 0, event.newWidth.toDouble(), event.newHeight.toDouble(), 0, -10, 10);
  });

  return AppState(
    resources,
    surface,
    eventsBinding,
    projection,
    renderContext,
    textRenderer,
    PrimitiveRenderer(renderContext),
    enableInspector,
    widget,
    logger: baseLogger,
  );
}

// ---

class _RootWidget extends SingleChildInstanceWidget {
  final BuildScope rootBuildScope;

  _RootWidget({required super.child, required this.rootBuildScope});

  @override
  SingleChildWidgetInstance<InstanceWidget> instantiate() => _RootInstance(widget: this);

  @override
  _RootProxy proxy() => _RootProxy(this);
}

class _RootProxy extends SingleChildInstanceWidgetProxy with RootProxyMixin {
  _RootProxy(super.widget);

  @override
  BuildScope get buildScope => (widget as _RootWidget).rootBuildScope;

  @override
  bool get mounted => _bootstrapped;
  bool _bootstrapped = false;

  void bootstrap(InstanceHost instanceHost, ProxyHost proxyHost) {
    _bootstrapped = true;
    lifecycle = ProxyLifecycle.live;

    host = proxyHost;

    rebuild();
    depth = 0;

    instance.depth = 0;
    instance.attachHost(instanceHost);
  }
}

class _RootInstance extends SingleChildWidgetInstance with ShrinkWrapLayout {
  _RootInstance({required super.widget});
}

class _UserRoot extends VisitorWidget {
  final void Function(WidgetProxy userRootProxy) proxyCallback;
  final void Function(WidgetInstance userRootInstance) instanceCallback;

  const _UserRoot({required this.proxyCallback, required this.instanceCallback, required super.child});

  @override
  VisitorProxy<VisitorWidget> proxy() {
    final proxy = VisitorProxy<_UserRoot>(this, (widget, instance) => widget.instanceCallback(instance));
    proxyCallback(proxy);

    return proxy;
  }
}

class _AppWidget extends InheritedWidget {
  final AppState app;
  _AppWidget({required this.app, required super.child});

  @override
  bool mustRebuildDependents(covariant _AppWidget newWidget) {
    if (newWidget.app != app) {
      throw UnsupportedError('changing the AppState of a widget tree is not supported');
    }

    return false;
  }
}

// ---

/// ### Overview
/// An app state manages all resources required to drive a braid application
/// and provides the necessary functionality to draw frames and perform layout.
/// It is also responsible for dispatching input events and acts as the application's
/// [InstanceHost] and [ProxyHost].
///
/// For users, the app state is the central and only handle necessary to implement a braid
/// application - all other parts of the framework are managed by and accessible through it.
///
/// ### Lifecycle
/// Upon construction, the app state bootstraps the widget, proxy and instance trees. It also subscribes
/// the the [surface]'s input events and sets up appropriate forwarding to the instance tree.
///
/// After initialization, [updateWidgetsAndInteractions] can be called for the first time to perform
/// the initial layout pass. Subsequently, the app is ready for drawing with [draw]. This is an idemoptent
/// operation and may be invoked multiple times.
///
/// To begin the next frame, invoke [updateWidgetsAndInteractions] again to flush the rebuild and layout
/// queues. After completion, the next frame can now be drawn with [draw]. This update/draw loop continues
/// until the end of the application's life.
///
/// Once the application is no longer needed, call [dispose] to clean up all resources associated with it.
/// This invalidates the app state.
///
/// ### See also:
/// - [createBraidApp]
/// - [runBraidApp]
/// - [rebuildRoot]
/// - [loadFontFamily]
class AppState implements InstanceHost, ProxyHost {
  final BraidResources resources;
  final Logger? logger;

  @override
  final Surface surface;
  @override
  final EventsBinding eventsBinding;

  final Matrix4 projection;

  final RenderContext context;
  @override
  final TextRenderer textRenderer;
  late final ImageCache _imageCache;
  final PrimitiveRenderer primitives;
  final Queue<GlCall> _queuedGlCalls = Queue();

  final BuildScope _rootBuildScope = BuildScope();
  Queue<AnimationCallback> _animationCallbacks = DoubleLinkedQueue();
  Queue<Callback> _postLayoutCallbacks = DoubleLinkedQueue();
  late _RootProxy _root;

  ({double x, double y}) _cursorPosition = const (x: 0, y: 0);

  Set<MouseListener> _hovered = {};
  MouseListener? _dragging;
  int? _draggingButton;
  CursorStyle? _draggingCursorStyle;
  bool _dragStarted = false;

  final StreamController<KeyDownEvent> keyDownController = StreamController.broadcast(sync: true);
  final StreamController<KeyUpEvent> keyUpController = StreamController.broadcast(sync: true);
  final StreamController<CharEvent> charController = StreamController.broadcast(sync: true);

  final List<StreamSubscription> _subscriptions = [];
  bool _running = true;

  // --- debug properties ---

  final BraidInspector? _inspector;
  final _RebuildTimingTracker _rebuildTimingTracker = _RebuildTimingTracker();
  bool debugDrawInstanceBoxes = false;

  // ------------------------

  AppState(
    this.resources,
    this.surface,
    this.eventsBinding,
    this.projection,
    this.context,
    this.textRenderer,
    this.primitives,
    bool enableInspector,
    Widget root, {
    this.logger,
  }) : _inspector = enableInspector ? BraidInspector() : null {
    _imageCache = ImageCache(_queuedGlCalls.add);

    _root = _RootWidget(
      child: _AppWidget(
        app: this,
        child: InstancePicker(
          activateEvents: _inspector?.onPick ?? const Stream.empty(),
          pickCallback: _inspector?.revealInstance ?? (_) {},
          child: RootFocusScope(
            onKeyDown: keyDownController.stream,
            onKeyUp: keyUpController.stream,
            onChar: charController.stream,
            child: _UserRoot(
              proxyCallback: (userRootProxy) => _inspector?.rootProxy = userRootProxy,
              instanceCallback: (userRootInstance) => _inspector?.rootInstance = userRootInstance,
              child: root,
            ),
          ),
        ),
      ),
      rootBuildScope: _rootBuildScope,
    ).proxy();
    _root.bootstrap(this, this);
    scheduleLayout(rootInstance);

    _subscriptions.add(surface.onResize.listen((event) => rootInstance.markNeedsLayout()));
  }

  void draw() {
    final ctx = DrawContext(context, primitives, projection, textRenderer, drawBoundingBoxes: debugDrawInstanceBoxes);

    dgl.gl.enable(glBlend);

    ctx.transform.scopedTransform(rootInstance.transform.transformToParent, (_) => rootInstance.draw(ctx));

    while (_queuedGlCalls.isNotEmpty) {
      _queuedGlCalls.removeFirst()();
    }

    context.nextFrame();
  }

  void updateWidgetsAndInteractions(Duration delta) {
    _pollAndDispatchEvents();

    final state = _hitTest();

    final nowHovered = <MouseListener>{};
    for (final hit in state.occludedTrace.where((element) => element.instance is MouseListener)) {
      final listener = hit.instance as MouseListener;

      nowHovered.add(listener);
      if (_hovered.contains(listener)) {
        _hovered.remove(listener);
      } else {
        listener.onMouseEnter();
      }

      if (listener.lastMousePosition != hit.coordinates) {
        listener.lastMousePosition = hit.coordinates;
        listener.onMouseMove(hit.coordinates.x, hit.coordinates.y);
      }
    }

    for (final noLongerHovered in _hovered) {
      noLongerHovered.onMouseExit();
      noLongerHovered.lastMousePosition = null;
    }

    _hovered = nowHovered;

    // ---

    CursorStyle? activeStyle;
    if (_dragging != null) {
      activeStyle = _draggingCursorStyle;
    } else {
      final cursorStyleSource = state.firstWhere(
        (hit) =>
            hit.instance is MouseListener &&
            (hit.instance as MouseListener).cursorStyleAt(hit.coordinates.x, hit.coordinates.y) != null,
      );

      if (cursorStyleSource != null) {
        activeStyle = (cursorStyleSource.instance as MouseListener).cursorStyleAt(
          cursorStyleSource.coordinates.x,
          cursorStyleSource.coordinates.y,
        );
      }
    }

    surface.cursorStyle = activeStyle ?? CursorStyle.none;

    // ---

    if (_animationCallbacks.isNotEmpty) {
      final callbacksForThisFrame = _animationCallbacks;
      _animationCallbacks = DoubleLinkedQueue();

      while (callbacksForThisFrame.isNotEmpty) {
        final callback = callbacksForThisFrame.removeFirst();
        callback(delta);
      }
    }

    var anyTreeMutations = false;

    if (_rebuildTimingTracker.trackNextIteration) {
      final watch = Stopwatch()..start();
      anyTreeMutations |= _rootBuildScope.rebuildDirtyProxies();
      _rebuildTimingTracker.buildTime = watch.elapsed;

      watch.reset();
      anyTreeMutations |= flushLayoutQueue();
      _rebuildTimingTracker.layoutTime = watch.elapsed;

      _rebuildTimingTracker.trackNextIteration = false;
      logger?.info('completed full app rebuild in ${_rebuildTimingTracker.formatted}');
    } else {
      anyTreeMutations |= _rootBuildScope.rebuildDirtyProxies();
      anyTreeMutations |= flushLayoutQueue();
    }

    if (anyTreeMutations) {
      _inspector?.refresh();
    }

    if (_postLayoutCallbacks.isNotEmpty) {
      final callbacksForThisFrame = _postLayoutCallbacks;
      _postLayoutCallbacks = DoubleLinkedQueue();

      while (callbacksForThisFrame.isNotEmpty) {
        final callback = callbacksForThisFrame.removeFirst();
        callback();
      }
    }
  }

  void _pollAndDispatchEvents() {
    final events = eventsBinding.poll();
    for (final event in events) {
      switch (event) {
        case MouseButtonPressEvent(:final button):
          final state = _hitTest();

          (state.firstWhere((hit) => hit.instance is FocusClickAreaInstance)?.instance as FocusClickAreaInstance?)
              ?.widget
              .clickCallback
              .call();

          final clicked = state.firstWhere(
            (hit) =>
                hit.instance is MouseListener &&
                (hit.instance as MouseListener).onMouseDown(hit.coordinates.x, hit.coordinates.y, button),
          );

          if (clicked != null) {
            _dragging = clicked.instance as MouseListener;
            _draggingButton = button;
            _draggingCursorStyle = (clicked.instance as MouseListener).cursorStyleAt(
              clicked.coordinates.x,
              clicked.coordinates.y,
            );
            _dragStarted = false;
          }
        case MouseMoveEvent(x: final cursorX, y: final cursorY, :final deltaX, :final deltaY):
          _cursorPosition = (x: cursorX, y: cursorY);

          if (_dragging == null) continue;

          if (!_dragStarted) {
            _dragging!.onMouseDragStart(_draggingButton!);
            _dragStarted = true;
          }

          final globalTransform = _dragging!.computeTransformFrom(ancestor: null);
          final (x, y) = globalTransform.transform2(cursorX, cursorY);

          // apply *only the rotation* of the instance's transform
          // to the mouse movement
          final delta = Vector4(deltaX, deltaY, 0, 0);
          globalTransform.transform(delta);

          _dragging!.onMouseDrag(x, y, delta.x, delta.y);
        case MouseButtonReleaseEvent(:final button):
          _hitTest().firstWhere(
            (hit) =>
                hit.instance is MouseListener &&
                (hit.instance as MouseListener).onMouseUp(_cursorPosition.x, _cursorPosition.y, button),
          );

          if (button == _draggingButton) {
            if (_dragStarted) {
              _dragging?.onMouseDragEnd();
            }

            _dragging = null;
          }
        case MouseScrollEvent(:var xOffset, :var yOffset):
          // whether enforcing this behavoir at the framework level is smart is... questionable
          if (xOffset == 0 &&
              (eventsBinding.isKeyPressed(glfwKeyLeftShift) || eventsBinding.isKeyPressed(glfwKeyRightShift))) {
            xOffset = yOffset;
            yOffset = 0;
          }

          _hitTest().firstWhere(
            (hit) =>
                hit.instance is MouseListener &&
                (hit.instance as MouseListener).onMouseScroll(hit.coordinates.x, hit.coordinates.y, xOffset, yOffset),
          );
        case KeyPressEvent(:final glfwKeycode, :final modifiers):
          if ((glfwKeycode == glfwKeyI || glfwKeycode == glfwKeyP) && modifiers.alt && modifiers.shift) {
            final treeFile = File('widget_tree.dot');
            final out = treeFile.openWrite();
            out.writeln('''
digraph {
splines=false;
node [shape="box"];
''');
            glfwKeycode == glfwKeyI ? dumpInstancesGraphviz(rootInstance, out) : dumpProxiesGraphviz(_root, out);
            out
              ..writeln('}')
              ..flush().then((value) {
                Process.start('dot', [
                  '-Tsvg',
                  '-owidget_tree.svg',
                  'widget_tree.dot',
                ], mode: ProcessStartMode.inheritStdio).then(
                  (proc) => proc.exitCode.then((_) {
                    return treeFile.delete();
                  }),
                );
              });
          }

          if (_inspector != null && glfwKeycode == glfwKeyI && modifiers.ctrl && modifiers.shift) {
            _inspector.activate();
            continue;
          }

          if (_inspector != null && glfwKeycode == glfwKeyC && modifiers.ctrl && modifiers.shift) {
            if (_inspector.currentApp == null) {
              // TODO: start the inspector as a hidden window in this case
              //  so as to not obscure the widget we're trying to pick. this
              //  requires being able to set window properties in
              //  createBraidAppWithWindow and consequently WindowSurface.createWindow
              _inspector.activate();
            }

            _inspector.pick();

            continue;
          }

          if (glfwKeycode == glfwKeyR && modifiers.ctrl && modifiers.shift) {
            context.reloadShaders().then((call) {
              _queuedGlCalls.add(call);
              _queuedGlCalls.add(GlCall(() => primitives.clearShaderCache()));
            });
            continue;
          }

          keyDownController.add((keyCode: glfwKeycode, modifiers: modifiers));
        case KeyReleaseEvent(:final glfwKeycode, :final modifiers):
          keyUpController.add((keyCode: glfwKeycode, modifiers: modifiers));
        case CharInputEvent(:final codepoint, :final modifiers):
          charController.add((charCode: codepoint, modifiers: modifiers));
        case FilesDroppedEvent(:final paths):
          final dropArea = _hitTest().firstWhere((hit) => hit.instance is FileDropAreaInstance)?.instance.widget;
          if (dropArea != null) {
            (dropArea as FileDropArea).onDrop(paths);
          }
        case CloseEvent():
          _running = false;
      }
    }
  }

  void rebuildRoot() {
    final watch = Stopwatch()..start();

    _root.reassemble();
    _rebuildTimingTracker.reassembleTime = watch.elapsed;
    _rebuildTimingTracker.trackNextIteration = true;
  }

  // TODO: there should be a separate function that doesn't go
  //  through the [BraidResources] abstraction
  Future<void> loadFontFamily(String familyName, [String? identifier]) async {
    final family = await FontFamily.load(resources, familyName);
    textRenderer.addFamily(identifier ?? familyName, family);

    rootInstance.clearLayoutCache();
    scheduleLayout(rootInstance);
  }

  void dispose() {
    _inspector?.close();

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    _root.unmount();

    surface.dispose();
    eventsBinding.dispose();
  }

  void scheduleShutdown() {
    _running = false;
  }

  Future<Image> debugCapture() {
    final completer = Completer<Image>();
    _queuedGlCalls.add(surface.capture().then((capture) => completer.complete(capture)));

    return completer.future;
  }

  // ---

  SingleChildWidgetInstance get rootInstance => _root.instance;

  @override
  ImageCache get imageCache => _imageCache;

  // ---

  HitTestState _hitTest() {
    final (:x, :y) = _cursorPosition;

    final state = HitTestState();
    rootInstance.hitTest(x, y, state);

    return state;
  }

  // ---

  List<WidgetInstance> _layoutQueue = [];
  bool _mergeToLayoutQueue = false;

  bool flushLayoutQueue() {
    if (_layoutQueue.isEmpty) return false;

    while (_layoutQueue.isNotEmpty) {
      final queue = _layoutQueue;
      _layoutQueue = <WidgetInstance>[];

      queue.sort();
      for (final (idx, instance) in queue.indexed) {
        if (_mergeToLayoutQueue) {
          _mergeToLayoutQueue = false;

          if (_layoutQueue.isNotEmpty) {
            _layoutQueue.addAll(queue.getRange(idx, queue.length));
            break;
          }
        }

        if (instance.needsLayout) {
          instance.layout(
            instance.hasParent
                ? instance.constraints!
                : Constraints.tight(Size(surface.width.toDouble(), surface.height.toDouble())),
          );
        }
      }

      _mergeToLayoutQueue = false;
    }

    return true;
  }

  @override
  void scheduleLayout(WidgetInstance<InstanceWidget> instance) => _layoutQueue.add(instance);

  @override
  void notifySubtreeRebuild() => _mergeToLayoutQueue = true;

  @override
  void scheduleAnimationCallback(AnimationCallback callback) => _animationCallbacks.add(callback);

  @override
  void schedulePostLayoutCallback(Callback callback) => _postLayoutCallbacks.add(callback);

  // ---

  static AppState of(BuildContext context) {
    return context.getAncestor<_AppWidget>()!.app;
  }
}

class _RebuildTimingTracker {
  Duration reassembleTime = Duration.zero;
  Duration buildTime = Duration.zero;
  Duration layoutTime = Duration.zero;

  bool trackNextIteration = false;

  String get formatted {
    String formatMs(Duration duration) => '${(duration.inMicroseconds / 1000).toStringAsFixed(2)}ms';

    final totalTime = reassembleTime + buildTime + layoutTime;
    return '${formatMs(totalTime)} (reassemble: ${formatMs(reassembleTime)}, rebuild: ${formatMs(buildTime)}, layout: ${formatMs(layoutTime)})';
  }
}
