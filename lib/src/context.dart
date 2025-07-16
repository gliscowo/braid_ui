import 'dart:async';
import 'dart:ffi';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import 'core/math.dart';
import 'primitive_renderer.dart';
import 'resources.dart';
import 'text/text_renderer.dart';

/// A function which requires an active OpenGL context
/// in order to run. In debug builds, this preconditions
/// is asserted through an explicit check - in production
/// it falls through directly to the representation type
///
/// Note: This type should be used by asynchronous functions
/// which must perform some type of OpenGL setup after they
/// have crossed their async gap(s). Only the minimal amount
/// of code (ie. only the actual calls to OpenGL functions)
/// should be in the returned closure
extension type const GlCall<T>(T Function() _fn) {
  T call() {
    assert(glfw.getCurrentContext() != nullptr, 'an OpenGL context must be active to invoke a GlCall');
    return _fn();
  }

  /// Create a new GlCall which completes with the
  /// result of calling [fn] on the result of [this]
  GlCall<S> then<S>(S Function(T) fn) => GlCall(() => fn(_fn()));

  /// Create a new GlCall wichh completes with a list
  /// of all results from invoking every call in [calls]
  static GlCall<List<T>> allOf<T>(Iterable<GlCall<T>> calls) => GlCall(() => calls.map((e) => e()).toList());
}

// ---

class BraidShader {
  final BraidResources source;
  final String name;
  final String vert;
  final String frag;

  BraidShader({required this.source, required this.name, required this.vert, required this.frag});

  Future<GlCall<GlProgram>> loadAndCompile() async {
    final (vertSource, fragSource) = await (source.loadShader('$vert.vert'), source.loadShader('$frag.frag')).wait;

    return GlCall(() {
      final shaders = [
        GlShader('$vert.vert', vertSource, GlShaderType.vertex),
        GlShader('$frag.frag', fragSource, GlShaderType.fragment),
      ];

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
    final program = await shader.loadAndCompile();
    return program.then((program) => _programStore[shader.name] = program);
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
