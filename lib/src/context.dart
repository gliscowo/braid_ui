import 'dart:async';

import 'package:clawclip/clawclip.dart';
import 'package:vector_math/vector_math.dart';

import 'core/math.dart';
import 'primitive_renderer.dart';
import 'resources.dart';
import 'text/text_renderer.dart';

class BraidShader {
  final BraidResources source;
  final String name;
  final String vert;
  final String frag;

  BraidShader({required this.source, required this.name, required this.vert, required this.frag});

  Future<GlCall<GlProgram>> loadAndCompile() async {
    final (vertSource, fragSource) = await (source.loadShader('$vert.vert'), source.loadShader('$frag.frag')).wait;

    return GlCall(() {
      final shaders = [GlShader('$vert.vert', vertSource, .vertex), GlShader('$frag.frag', fragSource, .fragment)];

      return GlProgram(name, shaders);
    });
  }
}

typedef ProgramLookup = GlProgram Function(String);

class RenderContext {
  final Window window;
  final Map<String, BraidShader> _shaderStore = {};
  final Map<String, GlProgram> _programStore = {};
  final StreamController<()> _frameEventsContoller = StreamController<()>.broadcast(sync: true);

  RenderContext(this.window);

  Future<GlCall<void>> addShader(BraidShader shader) {
    if (_programStore.containsKey(shader.name)) {
      throw ArgumentError('Duplicate shader name ${shader.name}', 'shader');
    }

    _shaderStore[shader.name] = shader;
    return _reloadShader(shader);
  }

  Future<GlCall<void>> reloadShaders() async => GlCall.allOf(await Future.wait(_shaderStore.values.map(_reloadShader)));

  Future<GlCall<void>> _reloadShader(BraidShader shader) async {
    final compileCall = await shader.loadAndCompile();
    return compileCall.then((program) => _programStore[shader.name] = program);
  }

  // TODO: this might wanna move
  void nextFrame() {
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
