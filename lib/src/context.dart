import 'package:braid_ui/src/core/math.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import 'primitive_renderer.dart';
import 'text/text_renderer.dart';

typedef ProgramLookup = GlProgram Function(String);

class RenderContext {
  final Window window;
  final Map<String, GlProgram> _programStore = {};

  RenderContext(this.window, List<GlProgram> programs) {
    for (final program in programs) {
      if (_programStore[program.name] != null) {
        throw ArgumentError('Duplicate program name ${program.name}', 'programs');
      }

      _programStore[program.name] = program;
    }
  }

  GlProgram findProgram(String name) {
    final program = _programStore[name];
    if (program == null) throw StateError('Missing required program $name');

    return program;
  }
}

class DrawContext {
  final RenderContext renderContext;
  final PrimitiveRenderer primitives;

  final Matrix4 projection;
  final Matrix4Stack transform = Matrix4Stack.identity();

  final TextRenderer textRenderer;

  final bool drawBoundingBoxes;

  DrawContext(
    this.renderContext,
    this.primitives,
    this.projection,
    this.textRenderer, {
    this.drawBoundingBoxes = false,
  });
}

class LayoutContext {
  final TextRenderer textRenderer;
  LayoutContext(this.textRenderer);
}
