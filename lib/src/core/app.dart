import 'dart:async';
import 'dart:collection';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
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
import 'constraints.dart';
import 'cursors.dart';
import 'math.dart';
import 'reload_hook.dart';

Future<void> runBraidApp({required AppState app, int targetFps = 60, bool experimentalReloadHook = false}) async {
  void Function()? reloadCancelCallback;

  if (experimentalReloadHook) {
    reloadCancelCallback = await setupReloadHook(() {
      app.logger?.info('hot reload detected, rebuilding root widget');
      app.rebuildRoot();
    });

    if (reloadCancelCallback != null) {
      app.logger?.info('reload hook attached successfully');
    }
  }

  final oneFrame = 1 / targetFps;
  var lastFrameTimestamp = glfw.getTime();

  gl.enable(glBlend);
  glfw.swapInterval(0);
  while (glfw.windowShouldClose(app.window.handle) != glfwTrue && app._running) {
    final measuredDelta = glfw.getTime() - lastFrameTimestamp;

    await Future.delayed(Duration(microseconds: max(((oneFrame - measuredDelta) * 1000000).toInt(), 0)));

    final effectiveDelta = glfw.getTime() - lastFrameTimestamp;
    lastFrameTimestamp = glfw.getTime();

    gl.viewport(0, 0, app.context.window.width, app.context.window.height);
    gl.clearColor(0, 0, 0, 1);
    gl.clear(glColorBufferBit);

    app.updateWidgetsAndInteractions(effectiveDelta);
    app.draw();

    app.context.nextFrame();
  }

  app.dispose();

  reloadCancelCallback?.call();
}

Future<AppState> createBraidApp({
  required BraidResources resources,
  String name = 'braid app',
  Window? window,
  int windowWidth = 1000,
  int windowHeight = 750,
  Logger? baseLogger,
  required Widget widget,
}) async {
  loadOpenGL();
  loadGLFW(BraidNatives.activeLibraries.spec.glfw);

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
  final programs = Stream.fromFutures([
    _vertFragProgram(resources, 'blit', 'blit', 'blit'),
    _vertFragProgram(resources, 'text', 'text', 'text'),
    _vertFragProgram(resources, 'solid_fill', 'pos', 'solid_fill'),
    _vertFragProgram(resources, 'texture_fill', 'pos_uv', 'texture_fill'),
    _vertFragProgram(resources, 'rounded_rect_solid', 'pos', 'rounded_rect_solid'),
    _vertFragProgram(resources, 'rounded_rect_outline', 'pos', 'rounded_rect_outline'),
    _vertFragProgram(resources, 'circle_solid', 'pos', 'circle_solid'),
    _vertFragProgram(resources, 'gradient_fill', 'pos_uv', 'gradient_fill'),
  ]);

  await for (final program in programs) {
    renderContext.addProgram(program);
  }

  final (notoSans, materialSymbols) =
      await (FontFamily.load(resources, 'NotoSans'), FontFamily.load(resources, 'MaterialSymbols')).wait;

  final textRenderer = TextRenderer(renderContext, notoSans, {
    'Noto Sans': notoSans,
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

Future<GlProgram> _vertFragProgram(BraidResources resources, String name, String vert, String frag) async {
  final (vertSource, fragSource) = await (resources.loadShader('$vert.vert'), resources.loadShader('$frag.frag')).wait;

  final shaders = [
    GlShader('$vert.vert', vertSource, GlShaderType.vertex),
    GlShader('$frag.frag', fragSource, GlShaderType.fragment),
  ];

  return GlProgram(name, shaders);
}

final class BraidInitializationException implements Exception {
  final String message;
  final Object? cause;
  BraidInitializationException(this.message, {this.cause});

  @override
  String toString() =>
      cause != null
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

// ---

class AppState implements InstanceHost, ProxyHost {
  final BraidResources resources;
  final Logger? logger;

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
  bool _dragStarted = false;
  KeyboardListener? _focused;

  final List<StreamSubscription> _subscriptions = [];
  bool _running = true;

  // --- debug properties ---

  bool debugDrawInstanceBoxes = false;

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
    _root = _RootWidget(child: root, rootBuildScope: _rootBuildScope).proxy();
    _root.bootstrap(this, this);

    _scheduleScaffoldLayout(force: true, global: true);
    _subscriptions.add(window.onResize.listen((event) => _scheduleScaffoldLayout(force: true)));

    // ---

    _subscriptions.addAll([
      window.onMouseButton.where((event) => event.action == glfwPress && event.button == glfwMouseButtonLeft).listen((
        event,
      ) {
        final state = _hitTest();

        final clicked = state.firstWhere(
          (hit) =>
              hit.instance is MouseListener &&
              (hit.instance as MouseListener).onMouseDown(hit.coordinates.x, hit.coordinates.y),
        );

        if (clicked != null) {
          _dragging = clicked.instance as MouseListener;
          _dragStarted = false;
        }

        _focused?.onFocusLost();
        _focused = state.firstWhere((instance) => instance is KeyboardListener)?.instance as KeyboardListener?;
        _focused?.onFocusGained();
      }),
      window.onMouseMove.listen((event) {
        if (_dragging == null) return;

        if (!_dragStarted) {
          _dragging!.onMouseDragStart();
          _dragStarted = true;
        }

        final (x, y) = _dragging!.globalToWidgetCoordinates(window.cursorX, window.cursorY);

        // apply *only the rotation* of the instance's transform
        // to the mouse movement
        final delta = Vector4(event.deltaX, event.deltaY, 0, 0);
        _dragging!.transform.toWidget.transform(delta);

        _dragging!.onMouseDrag(x, y, delta.x, delta.y);
      }),
      window.onMouseButton.where((event) => event.action == glfwRelease && event.button == glfwMouseButtonLeft).listen((
        event,
      ) {
        if (_dragStarted) {
          _dragging?.onMouseDragEnd();
        }

        _dragging = null;
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
        if (event.action == glfwPress &&
            (event.key == glfwKeyI || event.key == glfwKeyP) &&
            (event.mods & (glfwModAlt | glfwModShift)) != 0) {
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

        if (event.action == glfwPress || event.action == glfwRepeat) {
          _focused?.onKeyDown(event.key, event.mods);
        } else if (event.action == glfwRelease) {
          _focused?.onKeyUp(event.key, event.mods);
        }
      }),
      // ---
      window.onChar.listen((event) {
        _focused?.onChar(event, 0);
      }),
    ]);
  }

  void draw() {
    final ctx = DrawContext(context, primitives, projection, textRenderer, drawBoundingBoxes: debugDrawInstanceBoxes);
    ctx.transform.scopedTransform(rootInstance.transform.transformToParent, (_) => rootInstance.draw(ctx));
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

    _rootBuildScope.rebuildDirtyProxies();
    flushLayoutQueue();

    // ---

    final state = _hitTest();

    final nowHovered = <MouseListener>{};
    for (final listener in state.occludedTrace.map((e) => e.instance).whereType<MouseListener>()) {
      nowHovered.add(listener);

      if (_hovered.contains(listener)) {
        _hovered.remove(listener);
      } else {
        listener.onMouseEnter();
      }
    }

    for (final noLongerHovered in _hovered) {
      noLongerHovered.onMouseExit();
    }

    _hovered = nowHovered;

    // ---

    CursorStyle? activeStyle;
    if (_dragging != null) {
      activeStyle = _dragging!.cursorStyle;
    } else {
      final cursorStyleSource = state.firstWhere(
        (hit) => hit.instance is MouseListener && (hit.instance as MouseListener).cursorStyle != null,
      );

      activeStyle = (cursorStyleSource?.instance as MouseListener?)?.cursorStyle;
    }

    cursorController.style = activeStyle ?? CursorStyle.none;
  }

  void rebuildRoot() {
    final watch = Stopwatch()..start();

    _root.reassemble();
    _scheduleScaffoldLayout(force: true, global: true);

    final elapesd = watch.elapsedMicroseconds;
    logger?.fine('completed full app rebuild in ${elapesd}us');
  }

  // TODO: there should be a separate function that doesn't go
  // through the [BraidResources] abstraction
  Future<void> loadFontFamily(String familyName, [String? identifier]) async {
    final family = await FontFamily.load(resources, familyName);
    textRenderer.addFamily(identifier ?? familyName, family);

    rootInstance.clearLayoutCache();
    scheduleLayout(rootInstance);
    // _doScaffoldLayout(force: true);
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

  void _scheduleScaffoldLayout({bool force = false, bool global = false}) {
    if (force) {
      rootInstance.clearLayoutCache(recursive: global);
    }

    scheduleLayout(rootInstance);
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
  void scheduleAnimationCallback(AnimationCallback callback) => _callbacks.add(callback);
}
