import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/text/text_renderer.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

class AppState {
  final Window window;
  final CursorController cursorController;
  final Matrix4 projection;

  final RenderContext context;
  final TextRenderer textRenderer;
  final PrimitiveRenderer primitives;
  final AppScaffold scaffold;

  AppState(
    this.window,
    this.cursorController,
    this.projection,
    this.context,
    this.textRenderer,
    this.primitives,
    this.scaffold,
  );
}
