import 'dart:async';
import 'dart:developer';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import '../context.dart';
import '../primitive_renderer.dart';
import '../text/text_renderer.dart';
import 'constraints.dart';
import 'cursors.dart';
import 'math.dart';
import 'render_loop.dart';
import 'widget.dart';
import 'widget_base.dart';

final _frameEventsContoller = StreamController<()>.broadcast(sync: true);
final frameEvents = _frameEventsContoller.stream;

Future<void> runBraidApp({
  String name = 'braid app',
  int windowWidth = 1000,
  int windowHeight = 750,
  int targetFps = 60,
  bool experimentalReloadHook = false,
  Logger? baseLogger,
  required WidgetBuilder widget,
}) async {
  loadOpenGL();
  loadGLFW('resources/lib/libglfw.so.3');
  initDiamondGL(logger: baseLogger);

  if (glfw.init() != glfwTrue) {
    glfw.terminate();

    final errorPointer = ffi.malloc<ffi.Pointer<ffi.Char>>();
    glfw.getError(errorPointer);

    final errorString = errorPointer.cast<ffi.Utf8>().toDartString();
    ffi.malloc.free(errorPointer);

    throw BraidInitializationException('GLFW initialization error: $errorString');
  }

  if (baseLogger != null) {
    attachGlErrorCallback();

    _glfwLogger = Logger('${baseLogger.name}.glfw');
    glfw.setErrorCallback(ffi.Pointer.fromFunction(_onGlfwError));
  }

  void Function()? reloadCallback;
  void Function()? reloadHookCancel;

  if (experimentalReloadHook) {
    reloadHookCancel = await _setupReloadHook(() => reloadCallback?.call());
    if (reloadHookCancel != null) {
      baseLogger?.info('reload hook attached successfully');
    }
  }

  final window = Window(windowWidth, windowHeight, name);
  glfw.makeContextCurrent(window.handle);

  final renderContext = RenderContext(
    window,
    await Future.wait([
      _vertFragProgram('blit', 'blit', 'blit'),
      _vertFragProgram('text', 'text', 'text'),
      _vertFragProgram('solid_fill', 'pos', 'solid_fill'),
      _vertFragProgram('texture_fill', 'pos_uv', 'texture_fill'),
      _vertFragProgram('rounded_rect_solid', 'pos', 'rounded_rect_solid'),
      _vertFragProgram('rounded_rect_outline', 'pos', 'rounded_rect_outline'),
      _vertFragProgram('circle_solid', 'pos', 'circle_solid'),
      _vertFragProgram('gradient_fill', 'pos_uv', 'gradient_fill'),
      // _vertFragProgram('blur', 'position', 'blur'),
    ]),
  );

  final cascadia = FontFamily('CascadiaCode', 30);
  final notoSans = FontFamily('NotoSans', 30);
  final nunito = FontFamily('Nunito', 30);
  final materialSymbols = FontFamily('MaterialSymbols', 32);
  final textRenderer = TextRenderer(renderContext, notoSans, {
    'Noto Sans': notoSans,
    'CascadiaCode': cascadia,
    'Nunito': nunito,
    'MaterialSymbols': materialSymbols,
  });

  final primitives = PrimitiveRenderer(renderContext);

  final projection = makeOrthographicMatrix(0, window.width.toDouble(), window.height.toDouble(), 0, -10, 10);
  window.onResize.listen((event) {
    gl.viewport(0, 0, event.width, event.height);
    setOrthographicMatrix(projection, 0, event.width.toDouble(), event.height.toDouble(), 0, -10, 10);
  });

  var drawBoundingBoxes = false;
  window.onKey.where((event) => event.action == glfwPress && event.key == glfwKeyLeftShift).listen((event) {
    drawBoundingBoxes = !drawBoundingBoxes;
  });

  gl.enable(glBlend);

  final cursorController = CursorController.ofWindow(window);
  var rootWidget = AppScaffold(root: widget())
    ..layout(
      LayoutContext(textRenderer),
      Constraints.tight(Size(window.width.toDouble(), window.height.toDouble())),
    );

  reloadCallback = () {
    baseLogger?.info('hot reload detected, rebuilding root widget');
    rootWidget = AppScaffold(root: widget())
      ..layout(
        LayoutContext(textRenderer),
        Constraints.tight(Size(window.width.toDouble(), window.height.toDouble())),
      );
  };

  window.onResize.listen((event) {
    rootWidget.layout(
      LayoutContext(textRenderer),
      Constraints.tight(Size(event.width.toDouble(), event.height.toDouble())),
    );
  });

  window.onMouseButton
      .where((event) => event.action == glfwPress && event.button == glfwMouseButtonLeft)
      .listen((event) {
    final state = HitTestState();
    rootWidget.hitTest(window.cursorX, window.cursorY, state);

    state.firstWhere(
      (widget) => widget is MouseListener && (widget as MouseListener).onMouseDown(),
    );
  });

  window.onMouseScroll.listen((event) {
    final state = HitTestState();
    rootWidget.hitTest(window.cursorX, window.cursorY, state);

    state.firstWhere(
      (widget) => widget is MouseListener && (widget as MouseListener).onMouseScroll(event.xOffset, event.yOffset),
    );
  });

  final oneFrame = 1 / targetFps;
  var lastFrameTimestamp = glfw.getTime();

  glfw.swapInterval(0);
  while (glfw.windowShouldClose(window.handle) != glfwTrue) {
    final measuredDelta = glfw.getTime() - lastFrameTimestamp;

    await Future.delayed(Duration(
      microseconds: max(((oneFrame - measuredDelta) * 1000000).toInt(), 0),
    ));

    final effectiveDelta = glfw.getTime() - lastFrameTimestamp;
    lastFrameTimestamp = glfw.getTime();

    _frameEventsContoller.add(const ());
    drawFrame(
      DrawContext(renderContext, primitives, projection, textRenderer, drawBoundingBoxes: drawBoundingBoxes),
      cursorController,
      rootWidget,
      effectiveDelta,
    );
  }

  glfw.terminate();
  reloadHookCancel?.call();
}

Future<void Function()?> _setupReloadHook(void Function() callback) async {
  final serviceUri = (await Service.getInfo()).serverWebSocketUri;
  if (serviceUri == null) return null;

  final service = await vmServiceConnectUri(serviceUri.toString());
  await service.streamListen(EventStreams.kIsolate);

  service.onIsolateEvent.listen((event) {
    if (event.kind != 'IsolateReload') return;
    callback();
  });

  return () => service.dispose();
}

Logger? _glfwLogger;
void _onGlfwError(int errorCode, ffi.Pointer<ffi.Char> description) =>
    _glfwLogger?.severe('GLFW Error: ${description.cast<ffi.Utf8>().toDartString()} ($errorCode)');

Future<GlProgram> _vertFragProgram(String name, String vert, String frag) async {
  final shaders = await Future.wait([
    GlShader.fromFile(File('resources/shader/$vert.vert'), GlShaderType.vertex),
    GlShader.fromFile(File('resources/shader/$frag.frag'), GlShaderType.fragment),
  ]);

  return GlProgram(name, shaders);
}

class BraidInitializationException implements Exception {
  final String message;
  BraidInitializationException(this.message);

  @override
  String toString() => 'error during braid initialization: $message';
}
