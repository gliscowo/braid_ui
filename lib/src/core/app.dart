import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';

import '../baked_assets.g.dart' as assets;
import '../context.dart';
import '../immediate/foundation.dart';
import '../primitive_renderer.dart';
import '../resources.dart';
import '../text/text_renderer.dart';
import 'constraints.dart';
import 'cursors.dart';
import 'math.dart';
import 'reload_hook.dart';
import 'widget.dart';
import 'widget_base.dart';

Future<void> runBraidApp({
  required AppState app,
  int targetFps = 60,
  bool experimentalReloadHook = false,
}) async {
  void Function()? reloadCancelCallback;

  if (experimentalReloadHook) {
    reloadCancelCallback = await setupReloadHook(() {
      app.logger?.info('hot reload detected, rebuilding root widget');
      app.dangerouslyRebuildRoot();
    });

    if (reloadCancelCallback != null) {
      app.logger?.info('reload hook attached successfully');
    }
  }

  final oneFrame = 1 / targetFps;
  var lastFrameTimestamp = glfw.getTime();

  gl.enable(glBlend);
  glfw.swapInterval(0);
  while (glfw.windowShouldClose(app.window.handle) != glfwTrue) {
    final measuredDelta = glfw.getTime() - lastFrameTimestamp;

    await Future.delayed(Duration(
      microseconds: max(((oneFrame - measuredDelta) * 1000000).toInt(), 0),
    ));

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

  final (notoSans, materialSymbols) = await (
    FontFamily.load(resources, 'NotoSans'),
    FontFamily.load(resources, 'MaterialSymbols'),
  ).wait;

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
  final (vertSource, fragSource) = await (
    resources.loadShader('$vert.vert'),
    resources.loadShader('$frag.frag'),
  ).wait;

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
  String toString() => cause != null
      ? '''
error during braid initialization: $message
cause: $cause
'''
      : 'error during braid initialization: $message';
}

// ---

class AppState {
  final BraidResources resources;
  final Logger? logger;

  final Window window;
  final CursorController cursorController;
  final Matrix4 projection;

  final RenderContext context;
  final TextRenderer textRenderer;
  final PrimitiveRenderer primitives;

  late Widget _root;
  late AppScaffold _scaffold;

  Set<MouseListener> _hovered = {};
  KeyboardListener? _focused;

  final List<StreamSubscription> _subscriptions = [];

  AppState(
    this.resources,
    this.window,
    this.projection,
    this.context,
    this.textRenderer,
    this.primitives,
    this._root, {
    this.logger,
  }) : cursorController = CursorController.ofWindow(window) {
    _scaffold = AppScaffold(root: _root.assemble().instantiate());

    _doScaffoldLayout();
    _subscriptions.add(window.onResize.listen((event) => _doScaffoldLayout()));

    // ---

    _subscriptions.addAll([
      window.onMouseButton
          .where((event) => event.action == glfwPress && event.button == glfwMouseButtonLeft)
          .listen((event) {
        final state = _hitTest();

        state.firstWhere(
          (widget) => widget is MouseListener && (widget as MouseListener).onMouseDown(),
        );

        _focused?.onFocusLost();
        _focused = state.firstWhere((widget) => widget is KeyboardListener)?.widget as KeyboardListener?;
        _focused?.onFocusGained();
      }),
      // ---
      window.onMouseScroll.listen((event) {
        _hitTest().firstWhere(
          (widget) => widget is MouseListener && (widget as MouseListener).onMouseScroll(event.xOffset, event.yOffset),
        );
      }),
      // ---
      window.onKey.listen((event) {
        if (event.key == glfwKeyD && (event.mods & glfwModAlt) != 0) {
          final treeFile = File('widget_tree.dot');
          final out = treeFile.openWrite();
          out.writeln('''
digraph {
splines=false;
node [shape="box"];
''');
          dumpGraphviz(scaffold, out);
          out
            ..writeln('}')
            ..flush().then((value) {
              Process.start('dot', ['-Tsvg', '-owidget_tree.svg', 'widget_tree.dot'],
                      mode: ProcessStartMode.inheritStdio)
                  .then((proc) => proc.exitCode.then((_) => treeFile.delete()));
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
    final ctx = DrawContext(context, primitives, projection, textRenderer);
    ctx.transform.scopedTransform(
      scaffold.transform.transformToParent,
      (_) => scaffold.draw(ctx),
    );
  }

  void updateWidgetsAndInteractions(double delta) {
    scaffold.update(delta);

    // ---

    final state = _hitTest();

    final nowHovered = <MouseListener>{};
    for (final listener in state.occludedTrace.map((e) => e.widget).whereType<MouseListener>()) {
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

    final cursorStyleSource = state.firstWhere(
        (widgetInstance) => widgetInstance is MouseAreaInstance && widgetInstance.widget.cursorStyle != null);
    if (cursorStyleSource
        case (widget: MouseAreaInstance(widget: MouseArea(cursorStyle: var cursorStyle?)), coordinates: _)) {
      cursorController.style = cursorStyle;
    } else {
      cursorController.style = CursorStyle.none;
    }
  }

  @experimental
  void dangerouslyRebuildRoot() {
    final newRoot = _root.assemble();
    if (Widget.canUpdate(_scaffold.root.widget, newRoot)) {
      newRoot.updateInstance(_scaffold.root);
    } else {
      _scaffold.root = newRoot.instantiate();
    }

    _doScaffoldLayout(force: true);
  }

  // TODO: there should be a separate function that doesn't go
  // through the [BraidResources] abstraction
  Future<void> loadFontFamily(String familyName, [String? identifier]) async {
    final family = await FontFamily.load(resources, familyName);
    textRenderer.addFamily(identifier ?? familyName, family);

    _doScaffoldLayout(force: true);
  }

  void dispose() {
    cursorController.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    _scaffold.dispose();
  }

  // ---

  AppScaffold get scaffold => _scaffold;

  // ---

  HitTestState _hitTest([(double x, double y)? coordinates]) {
    final (x, y) = coordinates ?? (window.cursorX, window.cursorY);

    final state = HitTestState();
    scaffold.hitTest(x, y, state);

    return state;
  }

  void _doScaffoldLayout({bool force = false}) {
    if (force) {
      scaffold.clearLayoutCache();
    }

    scaffold.layout(
      LayoutContext(textRenderer, window),
      Constraints.tight(Size(window.width.toDouble(), window.height.toDouble())),
    );
  }
}
