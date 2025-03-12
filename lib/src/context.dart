import 'dart:async';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import 'core/math.dart';
import 'primitive_renderer.dart';
import 'text/text_renderer.dart';

typedef ProgramLookup = GlProgram Function(String);

class RenderContext {
  final Window window;
  final Map<String, GlProgram> _programStore = {};
  final StreamController<()> _frameEventsContoller = StreamController<()>.broadcast(sync: true);

  RenderContext(this.window);

  void addProgram(GlProgram program) {
    if (_programStore.containsKey(program.name)) {
      throw ArgumentError('Duplicate program name ${program.name}', 'programs');
    }

    _programStore[program.name] = program;
  }

  void nextFrame() {
    window.nextFrame();
    _frameEventsContoller.add(const ());
  }

  GlProgram findProgram(String name) {
    final program = _programStore[name];
    if (program == null) throw StateError('Missing required program $name');

    return program;
  }

  Stream<()> get frameEvents => _frameEventsContoller.stream;
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
