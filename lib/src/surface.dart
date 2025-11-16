import 'dart:ffi' as ffi;

import 'package:diamond_gl/diamond_gl.dart' as dgl;
import 'package:diamond_gl/glfw.dart';
import 'package:diamond_gl/opengl.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'package:image/image.dart';
import 'package:logging/logging.dart';

import 'baked_assets.g.dart' as assets;
import 'context.dart';
import 'core/cursors.dart';
import 'errors.dart';
import 'native/arena.dart';
import 'resources.dart';

typedef SurfaceResizeEvent = ({int newWidth, int newHeight});

abstract interface class Surface {
  int get width;
  int get height;

  Stream<SurfaceResizeEvent> get onResize;

  CursorStyle get cursorStyle;
  set cursorStyle(CursorStyle value);

  Future<RenderContext> createRenderContext(BraidResources resources);

  void beginDrawing();
  void endDrawing();

  void dispose();

  GlCall<Image> capture();
}

class WindowSurface implements Surface {
  final dgl.Window window;
  final CursorController _cursorController;

  WindowSurface.ofWindow({required this.window}) : _cursorController = CursorController.ofWindow(window);

  factory WindowSurface.createWindow({
    required String title,
    int width = 1000,
    int height = 750,
    List<dgl.WindowFlag> flags = const [],
    Logger? logger,
  }) {
    if (!dgl.diamondGLInitialized) {
      dgl.initDiamondGL(logger: logger);
    }

    if (glfwInit() != glfwTrue) {
      final errorPointer = ffi.malloc<ffi.Pointer<ffi.Char>>();
      glfwGetError(errorPointer);

      final errorString = errorPointer.cast<ffi.Utf8>().toDartString();
      ffi.malloc.free(errorPointer);

      throw BraidInitializationException('GLFW initialization error: $errorString');
    }

    if (logger != null) {
      dgl.attachGlfwErrorCallback();
    }

    final window = dgl.Window(width, height, title, flags: flags);
    window.setIcon(assets.braidIcon);

    window.activateContext();
    glfwSwapInterval(0);

    if (logger != null) {
      dgl.attachGlErrorCallback();
    }

    dgl.Window.dropContext();

    return WindowSurface.ofWindow(window: window);
  }

  @override
  int get width => window.width;

  @override
  int get height => window.height;

  @override
  Stream<SurfaceResizeEvent> get onResize => window.onFramebufferResize;

  @override
  CursorStyle get cursorStyle => _cursorController.style;

  @override
  set cursorStyle(CursorStyle value) => _cursorController.style = value;

  @override
  Future<RenderContext> createRenderContext(BraidResources resources) async {
    final context = RenderContext(window);

    final shaderSetup = await Future.wait(
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
      ].map(context.addShader).toList(),
    );

    window.activateContext();
    GlCall.allOf(shaderSetup)();
    dgl.Window.dropContext();

    return context;
  }

  @override
  void beginDrawing() {
    window.activateContext();

    glViewport(0, 0, window.width, window.height);

    glClearColor(0, 0, 0, 1);
    glClear(gl_colorBufferBit | gl_depthBufferBit);
  }

  @override
  void endDrawing() {
    window.nextFrame();
    // wtf??
    glfwPollEvents();
    dgl.Window.dropContext();
  }

  @override
  void dispose() {
    window.dispose();
  }

  // ---

  @override
  GlCall<Image> capture() => GlCall(
    () => ffi.malloc.arena((arena) {
      final bufferSize = width * height * 4;

      final pixelBuffer = arena<ffi.Uint8>(bufferSize);
      glReadPixels(0, 0, width, height, gl_rgba, gl_unsignedByte, pixelBuffer.cast());

      final pixels = pixelBuffer.asTypedList(bufferSize);
      final image = Image.fromBytes(width: width, height: height, bytes: pixels.buffer, numChannels: 4);

      return flipVertical(image);
    }),
  );
}
