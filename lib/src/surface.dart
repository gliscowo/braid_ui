import 'package:diamond_gl/diamond_gl.dart' as dgl;
import 'package:diamond_gl/opengl.dart';

import 'context.dart';
import 'core/cursors.dart';

typedef SurfaceResizeEvent = ({int newWidth, int newHeight});

abstract interface class Surface {
  int get width;
  int get height;

  Stream<SurfaceResizeEvent> get onResize;

  CursorStyle get cursorStyle;
  set cursorStyle(CursorStyle value);

  RenderContext createRenderContext();

  void beginFrame();
  void endFrame();

  void dispose();
}

class WindowSurface implements Surface {
  final dgl.Window window;
  final CursorController _cursorController;

  WindowSurface({required this.window}) : _cursorController = CursorController.ofWindow(window);

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
  RenderContext createRenderContext() => RenderContext(window);

  @override
  void beginFrame() {
    window.activateContext();

    dgl.gl.viewport(0, 0, window.width, window.height);

    dgl.gl.clearColor(0, 0, 0, 1);
    dgl.gl.clear(glColorBufferBit | glDepthBufferBit);
  }

  @override
  void endFrame() {
    window.nextFrame();
    dgl.Window.dropContext();
  }

  @override
  void dispose() {
    // this is a no-op for now, although once the surface manages
    // the window, this is where we get rid of it
  }
}
