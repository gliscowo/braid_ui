import 'dart:ffi';
import 'dart:io';

import 'package:braid_ui/src/core/render_loop.dart';
import 'package:braid_ui/src/primitive_renderer.dart';
import 'package:dart_glfw/dart_glfw.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../text/text_renderer.dart';

Future<void> runBraidApp({String name = 'braid app', Logger? baseLogger}) async {
  loadOpenGL();
  loadGLFW('resources/lib/libglfw.so.3');
  initDiamondGL(logger: baseLogger);

  if (glfw.init() != glfwTrue) {
    glfw.terminate();

    final errorPointer = malloc<Pointer<Char>>();
    glfw.getError(errorPointer);

    final errorString = errorPointer.cast<Utf8>().toDartString();
    malloc.free(errorPointer);

    throw BraidInitializationException('GLFW initialization error: $errorString');
  }

  if (baseLogger != null) {
    attachGlErrorCallback();

    _glfwLogger = Logger('${baseLogger.name}.glfw');
    glfw.setErrorCallback(Pointer.fromFunction(_onGlfwError));
  }

  final window = Window(1000, 750, name);
  glfw.makeContextCurrent(window.handle);

  final renderContext = RenderContext(
    window,
    await Future.wait([
      _vertFragProgram('text', 'text', 'text'),
      _vertFragProgram('hsv', 'position', 'hsv'),
      _vertFragProgram('pos_color', 'position', 'position'),
      _vertFragProgram('pos_color_uniform', 'position', 'position_color'),
      _vertFragProgram('rounded_rect', 'position', 'rounded'),
      _vertFragProgram('rounded_rect_outline', 'position', 'rounded_outline'),
      _vertFragProgram('circle', 'position', 'circle'),
      _vertFragProgram('blur', 'position', 'blur'),
      _vertFragProgram('pos_uv_color', 'pos_uv_color', 'pos_uv_color'),
      _vertFragProgram('gradient', 'gradient', 'gradient'),
    ]),
  );

  final cascadia = FontFamily('CascadiaCode', 30);
  final notoSans = FontFamily('NotoSans', 30);
  final textRenderer = TextRenderer(renderContext, notoSans, {
    'Noto Sans': notoSans,
    'CascadiaCode': cascadia,
  });

  final primitives = PrimitiveRenderer(renderContext);

  final projection = makeOrthographicMatrix(0, window.width.toDouble(), window.height.toDouble(), 0, -10, 10);
  window.onResize.listen((event) {
    gl.viewport(0, 0, event.width, event.height);
    setOrthographicMatrix(projection, 0, event.width.toDouble(), event.height.toDouble(), 0, -10, 10);
  });

  gl.enable(glBlend);

  while (glfw.windowShouldClose(window.handle) != glfwTrue) {
    drawFrame(DrawContext(renderContext, primitives, projection, textRenderer));
  }

  glfw.terminate();
}

Logger? _glfwLogger;
void _onGlfwError(int errorCode, Pointer<Char> description) =>
    _glfwLogger?.severe('GLFW Error: ${description.cast<Utf8>().toDartString()} ($errorCode)');

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
