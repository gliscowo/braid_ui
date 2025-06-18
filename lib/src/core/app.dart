import 'dart:async';
import 'dart:collection';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:diamond_gl/glfw.dart';
import 'package:diamond_gl/opengl.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

import '../baked_assets.g.dart' as assets;
import '../context.dart';
import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import '../primitive_renderer.dart';
import '../resources.dart';
import '../text/text_renderer.dart';
import '../widgets/basic.dart';
import '../widgets/inspector.dart';
import 'constraints.dart';
import 'cursors.dart';
import 'key_modifiers.dart';
import 'math.dart';
import 'reload_hook.dart';

Future<void> runBraidApp({required AppState app, int targetFps = 60, bool reloadHook = false}) async {
  void Function()? reloadCancelCallback;

  if (reloadHook) {
    reloadCancelCallback = await setupReloadHook(() {
      app.rebuildRoot();
    });

    if (reloadCancelCallback != null) {
      app.logger?.info('reload hook attached successfully');
    }
  }

  final oneFrame = 1 / targetFps;
  var lastFrameTimestamp = glfw.getTime();

  glfw.swapInterval(0);

  while (glfw.windowShouldClose(app.window.handle) != glfwTrue && app._running) {
    final measuredDelta = glfw.getTime() - lastFrameTimestamp;

    await Future.delayed(Duration(microseconds: max(((oneFrame - measuredDelta) * 1_000_000).toInt(), 0)));

    final effectiveDelta = glfw.getTime() - lastFrameTimestamp;
    lastFrameTimestamp = glfw.getTime();

    app.updateWidgetsAndInteractions(effectiveDelta);

    glfw.makeContextCurrent(app.window.handle);
    gl.viewport(0, 0, app.context.window.width, app.context.window.height);
    gl.clearColor(0, 0, 0, 1);
    gl.clear(glColorBufferBit);
    glfw.makeContextCurrent(ffi.nullptr);

    await app.draw();
  }

  app.dispose();

  reloadCancelCallback?.call();
}

/// Initialize all state necessary to drive the braid application
/// represented by [widget]. This function will:
/// 1. Ensure OpenGL and GLFW are available and loaded, loading them if
///    necessary
/// 2. If necessary, initialize DiamondGL logging with [baseLogger]
/// 3. If no [window] was provided, create one and associate it with
///    the application
/// 4. Load the defauĺt shaders and fonts
///
/// If everything succeeds, an [AppState] encapsulating all application state
/// is created and returned
///
/// See also:
/// - [runBraidApp]
/// - [AppState]
/// - [Widget]
Future<AppState> createBraidApp({
  required BraidResources resources,
  required String defaultFontFamily,
  String name = 'braid app',
  Window? window,
  int windowWidth = 1000,
  int windowHeight = 750,
  Logger? baseLogger,
  required Widget widget,
}) async {
  loadOpenGLFromPath();
  loadGLFW(BraidNatives.activeLibraries.glfw);

  if (!diamondGLInitialized) {
    initDiamondGL(logger: baseLogger);
  }

  Window braidWindow;
  if (window == null) {
    if (glfw.init() != glfwTrue) {
      glfw.terminate();

      final errorPointer = ffi.malloc<ffi.Pointer<ffi.Char>>();
      glfw.getError(errorPointer);

      final errorString = errorPointer.cast<ffi.Utf8>().toDartString();
      ffi.malloc.free(errorPointer);

      throw BraidInitializationException('GLFW initialization error: $errorString');
    }

    if (baseLogger != null) {
      attachGlfwErrorCallback();
    }

    braidWindow = Window(windowWidth, windowHeight, name);
    braidWindow.setIcon(assets.braidIcon);
  } else {
    braidWindow = window;
  }

  braidWindow.activateContext();
  if (baseLogger != null && window == null) {
    attachGlErrorCallback();
  }

  final renderContext = RenderContext(braidWindow);
  await Future.wait(
    [
      BraidShader(source: resources, name: 'blit', vert: 'blit', frag: 'blit'),
      BraidShader(source: resources, name: 'text', vert: 'text', frag: 'text'),
      BraidShader(source: resources, name: 'solid_fill', vert: 'pos', frag: 'solid_fill'),
      BraidShader(source: resources, name: 'colored_fill', vert: 'pos_color', frag: 'colored_fill'),
      BraidShader(source: resources, name: 'texture_fill', vert: 'pos_uv', frag: 'texture_fill'),
      BraidShader(source: resources, name: 'rounded_rect_solid', vert: 'pos', frag: 'rounded_rect_solid'),
      BraidShader(source: resources, name: 'rounded_rect_outline', vert: 'pos', frag: 'rounded_rect_outline'),
      BraidShader(source: resources, name: 'circle_solid', vert: 'pos', frag: 'circle_solid'),
      BraidShader(source: resources, name: 'circle_sector', vert: 'pos', frag: 'circle_sector'),
      BraidShader(source: resources, name: 'gradient_fill', vert: 'pos_uv', frag: 'gradient_fill'),
      BraidShader(source: resources, name: 'blur', vert: 'pos', frag: 'blur'),
    ].map(renderContext.addShader).toList(),
  );

  final (defaultFont, materialSymbols) = await (
    FontFamily.load(resources, defaultFontFamily),
    FontFamily.load(resources, 'MaterialSymbols'),
  ).wait;

  final textRenderer = TextRenderer(renderContext, defaultFont, {
    'default': defaultFont,
    'MaterialSymbols': materialSymbols,
  });

  final projection = makeOrthographicMatrix(0, braidWindow.width.toDouble(), braidWindow.height.toDouble(), 0, -10, 10);
  braidWindow.onResize.listen((event) {
    setOrthographicMatrix(projection, 0, event.width.toDouble(), event.height.toDouble(), 0, -10, 10);
  });

  return AppState(
    resources,
    braidWindow,
    projection,
    renderContext,
    textRenderer,
    PrimitiveRenderer(renderContext),
    widget,
    logger: baseLogger,
  );
}

final class BraidInitializationException implements Exception {
  final String message;
  final Object? cause;
  BraidInitializationException(this.message, {this.cause});

  @override
  String toString() => cause != null
      ? '''
error during braid initialization: $message
cause: $cause
'''
      : 'error during braid initialization: $message';
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

// ---

/// ### Overview
/// An app state manages all resources required to drive a braid application
/// and provides the necessary functionality to draw frames and perform layout.
/// It is also responsible for dispatching input events and acts as the application's
/// [InstanceHost] and [ProxyHost].
///
/// For users, the app state is the central and only handle necessary to implement a braid
/// application - all other parts of the framework is managed by and accessible through it.
///
/// ### Lifecycle
/// Upon construction, the app state bootstraps the widget, proxy and instance trees. It also subscribes
/// the the [window]'s input events and sets up appropriate forwarding to the instance tree.
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
  final Window window;
  final CursorController cursorController;
  final Matrix4 projection;

  final RenderContext context;
  @override
  final TextRenderer textRenderer;
  final PrimitiveRenderer primitives;

  final BuildScope _rootBuildScope = BuildScope();
  Queue<AnimationCallback> _callbacks = DoubleLinkedQueue();
  late _RootProxy _root;

  Set<MouseListener> _hovered = {};
  MouseListener? _dragging;
  int? _draggingButton;
  CursorStyle? _draggingCursorStyle;
  bool _dragStarted = false;

  List<KeyboardListener> _focused = [];

  final List<StreamSubscription> _subscriptions = [];
  bool _running = true;

  // --- debug properties ---

  final BraidInspector _inspector = BraidInspector();
  final _RebuildTimingTracker _rebuildTimingTracker = _RebuildTimingTracker();
  bool debugDrawInstanceBoxes = false;
  bool debugReloadShadersNextFrame = false;

  // ------------------------

  AppState(
    this.resources,
    this.window,
    this.projection,
    this.context,
    this.textRenderer,
    this.primitives,
    Widget root, {
    this.logger,
  }) : cursorController = CursorController.ofWindow(window) {
    _root = _RootWidget(
      child: InspectableTree(
        inspector: _inspector,
        tree: _UserRoot(
          proxyCallback: (userRootProxy) => _inspector.rootProxy = userRootProxy,
          instanceCallback: (userRootInstance) => _inspector.rootInstance = userRootInstance,
          child: root,
        ),
      ),
      rootBuildScope: _rootBuildScope,
    ).proxy();
    _root.bootstrap(this, this);
    scheduleLayout(rootInstance);

    _subscriptions.add(window.onResize.listen((event) => rootInstance.markNeedsLayout()));

    // ---

    _subscriptions.addAll([
      window.onMouseButton.where((event) => event.action == glfwPress).listen((event) {
        final state = _hitTest();

        _updateFocus(
          state.occludedTrace.map((e) => e.instance).firstWhereOrNull((element) => element is KeyboardListener)
              as KeyboardListener?,
        );

        final clicked = state.firstWhere(
          (hit) =>
              hit.instance is MouseListener &&
              (hit.instance as MouseListener).onMouseDown(hit.coordinates.x, hit.coordinates.y, event.button),
        );

        if (clicked != null) {
          _dragging = clicked.instance as MouseListener;
          _draggingButton = event.button;
          _draggingCursorStyle = (clicked.instance as MouseListener).cursorStyleAt(
            clicked.coordinates.x,
            clicked.coordinates.y,
          );
          _dragStarted = false;
        }
      }),
      window.onMouseMove.listen((event) {
        if (_dragging == null) return;

        if (!_dragStarted) {
          _dragging!.onMouseDragStart(_draggingButton!);
          _dragStarted = true;
        }

        final globalTransform = _dragging!.computeTransformFrom(ancestor: null);
        final (x, y) = globalTransform.transform2(window.cursorX, window.cursorY);

        // apply *only the rotation* of the instance's transform
        // to the mouse movement
        final delta = Vector4(event.deltaX, event.deltaY, 0, 0);
        globalTransform.transform(delta);

        _dragging!.onMouseDrag(x, y, delta.x, delta.y);
      }),
      window.onMouseButton.where((event) => event.action == glfwRelease).listen((event) {
        if (event.button == _draggingButton) {
          if (_dragStarted) {
            _dragging?.onMouseDragEnd();
          }

          _dragging = null;
        }
      }),
      // ---
      window.onMouseScroll.listen((event) {
        _hitTest().firstWhere(
          (hit) =>
              hit.instance is MouseListener &&
              (hit.instance as MouseListener).onMouseScroll(
                hit.coordinates.x,
                hit.coordinates.y,
                event.xOffset,
                event.yOffset,
              ),
        );
      }),
      // ---
      window.onKey.listen((event) {
        final modifiers = KeyModifiers(event.mods);

        if (event.action == glfwPress &&
            (event.key == glfwKeyI || event.key == glfwKeyP) &&
            modifiers.alt &&
            modifiers.shift) {
          final treeFile = File('widget_tree.dot');
          final out = treeFile.openWrite();
          out.writeln('''
digraph {
splines=false;
node [shape="box"];
''');
          event.key == glfwKeyI ? dumpInstancesGraphviz(rootInstance, out) : dumpProxiesGraphviz(_root, out);
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

        if (event.action == glfwPress && event.key == glfwKeyI && modifiers.ctrl && modifiers.shift) {
          _inspector.activate();
          return;
        }

        if (event.action == glfwPress && event.key == glfwKeyR && modifiers.ctrl && modifiers.shift) {
          debugReloadShadersNextFrame = true;
          return;
        }

        if (event.action == glfwPress || event.action == glfwRepeat) {
          _focused.firstWhereOrNull((listener) => listener.onKeyDown(event.key, KeyModifiers(event.mods)));
        } else if (event.action == glfwRelease) {
          _focused.firstWhereOrNull((listener) => listener.onKeyUp(event.key, KeyModifiers(event.mods)));
        }
      }),
      // ---
      window.onCharMods.listen((event) {
        _focused.firstWhereOrNull((listener) => listener.onChar(event.codepoint, KeyModifiers(event.mods)));
      }),
    ]);
  }

  Future<void> draw() async {
    if (debugReloadShadersNextFrame) {
      debugReloadShadersNextFrame = false;

      await context.reloadShaders();
      primitives.clearShaderCache();
    }

    final ctx = DrawContext(context, primitives, projection, textRenderer, drawBoundingBoxes: debugDrawInstanceBoxes);

    glfw.makeContextCurrent(window.handle);
    gl.enable(glBlend);

    ctx.transform.scopedTransform(rootInstance.transform.transformToParent, (_) => rootInstance.draw(ctx));
    context.nextFrame();

    glfw.makeContextCurrent(ffi.nullptr);
  }

  void updateWidgetsAndInteractions(double delta) {
    if (_callbacks.isNotEmpty) {
      final callbacksForThisFrame = _callbacks;
      _callbacks = DoubleLinkedQueue();

      while (callbacksForThisFrame.isNotEmpty) {
        final callback = callbacksForThisFrame.removeFirst();
        callback(delta);
      }
    }

    if (_rebuildTimingTracker.trackNextIteration) {
      final watch = Stopwatch()..start();
      _rootBuildScope.rebuildDirtyProxies();
      _rebuildTimingTracker.buildTime = watch.elapsed;

      watch.reset();
      flushLayoutQueue();
      _rebuildTimingTracker.layoutTime = watch.elapsed;

      _rebuildTimingTracker.trackNextIteration = false;
      logger?.info('completed full app rebuild in ${_rebuildTimingTracker.formatted}');
    } else {
      _rootBuildScope.rebuildDirtyProxies();
      flushLayoutQueue();
    }

    // ---

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

    cursorController.style = activeStyle ?? CursorStyle.none;
  }

  void _updateFocus(KeyboardListener? listener) {
    final nowFocused = listener != null
        ? [listener].followedBy(listener.ancestors.whereType<KeyboardListener>()).toList()
        : const <KeyboardListener>[];

    for (final listener in nowFocused) {
      if (_focused.contains(listener)) {
        _focused.remove(listener);
      } else {
        listener.onFocusGained();
      }
    }

    for (final noLongerFocused in _focused) {
      noLongerFocused.onFocusLost();
    }

    _focused = nowFocused;
  }

  void rebuildRoot() {
    final watch = Stopwatch()..start();

    _root.reassemble();
    _rebuildTimingTracker.reassembleTime = watch.elapsed;
    _rebuildTimingTracker.trackNextIteration = true;
  }

  // TODO: there should be a separate function that doesn't go
  // through the [BraidResources] abstraction
  Future<void> loadFontFamily(String familyName, [String? identifier]) async {
    final family = await FontFamily.load(resources, familyName);
    textRenderer.addFamily(identifier ?? familyName, family);

    rootInstance.clearLayoutCache();
    scheduleLayout(rootInstance);
  }

  void dispose() {
    cursorController.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    _root.unmount();
  }

  void scheduleShutdown() {
    _running = false;
  }

  // ---

  SingleChildWidgetInstance get rootInstance => _root.instance;

  // ---

  HitTestState _hitTest() {
    final (x, y) = (window.cursorX, window.cursorY);

    final state = HitTestState();
    rootInstance.hitTest(x, y, state);

    return state;
  }

  // ---

  List<WidgetInstance> _layoutQueue = [];
  bool _mergeToLayoutQueue = false;

  void flushLayoutQueue() {
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
                : Constraints.tight(Size(window.width.toDouble(), window.height.toDouble())),
          );
        }
      }

      _mergeToLayoutQueue = false;
    }
  }

  @override
  void scheduleLayout(WidgetInstance<InstanceWidget> instance) => _layoutQueue.add(instance);

  @override
  void notifySubtreeRebuild() => _mergeToLayoutQueue = true;

  @override
  void moveFocusTo(KeyboardListener<InstanceWidget> focusTarget) {
    _updateFocus(focusTarget);
  }

  @override
  void scheduleAnimationCallback(AnimationCallback callback) => _callbacks.add(callback);
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
