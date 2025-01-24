import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:math';

import 'package:braid_ui/src/core/app_state.dart';
import 'package:braid_ui/src/resources.dart';
import 'package:dart_glfw/dart_glfw.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../primitive_renderer.dart';
import '../text/text_renderer.dart';
import 'render_loop.dart';
import 'widget.dart';

final _frameEventsContoller = StreamController<()>.broadcast(sync: true);
final frameEvents = _frameEventsContoller.stream;

Future<void> runBraidApp({
  required AppState app,
  int targetFps = 60,
  bool experimentalReloadHook = false,
}) async {
  // void Function()? reloadCallback;
  // void Function()? reloadHookCancel;

  // if (experimentalReloadHook) {
  //   reloadHookCancel = await _setupReloadHook(() => reloadCallback?.call());
  //   if (reloadHookCancel != null) {
  //     baseLogger?.info('reload hook attached successfully');
  //   }
  // }

  // reloadCallback = () {
  //   baseLogger?.info('hot reload detected, rebuilding root widget');
  //   rootWidget = AppScaffold(root: widget())
  //     ..layout(
  //       LayoutContext(textRenderer, window),
  //       Constraints.tight(Size(window.width.toDouble(), window.height.toDouble())),
  //     );
  // };

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

    // TODO: this must move somewhere else
    _frameEventsContoller.add(const ());

    // TODO: this must become a contextless function on [AppState]
    drawFrame(
      DrawContext(app.context, app.primitives, app.projection, app.textRenderer /*, drawBoundingBoxes: false*/),
      app.cursorController,
      app.scaffold,
      effectiveDelta,
    );
  }

  glfw.terminate();
  // reloadHookCancel?.call();
}

Future<AppState> createBraidApp({
  required BraidResources resources,
  String name = 'braid app',
  Window? window,
  int windowWidth = 1000,
  int windowHeight = 750,
  Logger? baseLogger,
  required WidgetBuilder widget,
}) async {
  loadOpenGL();
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
  } else {
    braidWindow = window;
  }

  braidWindow.activateContext();
  if (baseLogger != null && window == null) {
    attachGlErrorCallback();
  }

  final renderContext = RenderContext(
    braidWindow,
    await Future.wait([
      _vertFragProgram(resources, 'blit', 'blit', 'blit'),
      _vertFragProgram(resources, 'text', 'text', 'text'),
      _vertFragProgram(resources, 'solid_fill', 'pos', 'solid_fill'),
      _vertFragProgram(resources, 'texture_fill', 'pos_uv', 'texture_fill'),
      _vertFragProgram(resources, 'rounded_rect_solid', 'pos', 'rounded_rect_solid'),
      _vertFragProgram(resources, 'rounded_rect_outline', 'pos', 'rounded_rect_outline'),
      _vertFragProgram(resources, 'circle_solid', 'pos', 'circle_solid'),
      _vertFragProgram(resources, 'gradient_fill', 'pos_uv', 'gradient_fill'),
      // _vertFragProgram(resources, 'blur', 'position', 'blur'),
    ]),
  );

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
  );
}

// Future<void Function()?> _setupReloadHook(void Function() callback) async {
//   final serviceUri = (await Service.getInfo()).serverWebSocketUri;
//   if (serviceUri == null) return null;

//   final service = await vmServiceConnectUri(serviceUri.toString());
//   await service.streamListen(EventStreams.kIsolate);

//   service.onIsolateEvent.listen((event) {
//     if (event.kind != 'IsolateReload') return;
//     callback();
//   });

//   return () => service.dispose();
// }

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
