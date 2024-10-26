import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

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
  final builtWidget = widget()
    ..layout(
      LayoutContext(textRenderer),
      Constraints.tight(Size(window.width.toDouble(), window.height.toDouble())),
    );

  window.onResize.listen((event) {
    builtWidget.layout(
      LayoutContext(textRenderer),
      Constraints.tight(Size(event.width.toDouble(), event.height.toDouble())),
    );
  });

  window.onMouseButton
      .where((event) => event.action == glfwPress && event.button == glfwMouseButtonLeft)
      .listen((event) {
    final state = HitTestState();
    builtWidget.hitTest(window.cursorX, window.cursorY, state);

    final hit = state.firstWhere((widget) => widget is MouseListener);
    if (hit case (var receiver, _)) {
      (receiver as MouseListener).onMouseDown();
    }
  });

  while (glfw.windowShouldClose(window.handle) != glfwTrue) {
    _frameEventsContoller.add(const ());
    drawFrame(
      DrawContext(renderContext, primitives, projection, textRenderer, drawBoundingBoxes: drawBoundingBoxes),
      cursorController,
      builtWidget,
    );
  }

  glfw.terminate();
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
