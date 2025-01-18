import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import 'context.dart';
import 'vertex_descriptors.dart';

class PrimitiveRenderer {
  final RenderContext _context;

  final MeshBuffer<PosVertexFunction> _solidBuffer;
  final MeshBuffer<PosUvVertexFunction> _gradientBuffer;
  final MeshBuffer<PosVertexFunction> _roundedSolidBuffer;
  final MeshBuffer<PosVertexFunction> _roundedOutlineBuffer;
  final MeshBuffer<PosVertexFunction> _circleBuffer;
  MeshBuffer<BlitVertexFunction>? _blitBuffer;

  PrimitiveRenderer(this._context)
      : _solidBuffer = MeshBuffer(posVertexDescriptor, _context.findProgram('solid_fill')),
        _gradientBuffer = MeshBuffer(posUvVertexDescriptor, _context.findProgram('gradient_fill')),
        _circleBuffer = MeshBuffer(posVertexDescriptor, _context.findProgram('circle_solid')),
        _roundedSolidBuffer = MeshBuffer(posVertexDescriptor, _context.findProgram('rounded_rect_solid')),
        _roundedOutlineBuffer = MeshBuffer(posVertexDescriptor, _context.findProgram('rounded_rect_outline'));

  void roundedRect(
    double width,
    double height,
    double radius,
    Color color,
    Matrix4 transform,
    Matrix4 projection, {
    double? outlineThickness,
  }) {
    final buffer = outlineThickness == null ? _roundedSolidBuffer : _roundedOutlineBuffer;
    buffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniform4vf('uColor', color.asVector())
      ..uniform1f('uRadius', radius)
      ..uniform2f('uSize', width, height)
      ..use();

    if (outlineThickness != null) buffer.program.uniform1f('uThickness', outlineThickness);

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    buffer.clear();
    buildRect(buffer.vertex, 0, 0, width, height);
    buffer
      ..upload(dynamic: true)
      ..draw();
  }

  void rect(double width, double height, Color color, Matrix4 transform, Matrix4 projection) {
    _solidBuffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniform4vf('uColor', color.asVector())
      ..use();

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    _solidBuffer.clear();
    buildRect(_solidBuffer.vertex, 0, 0, width, height);
    _solidBuffer
      ..upload(dynamic: true)
      ..draw();
  }

  void gradientRect(
    double width,
    double height,
    Color startColor,
    Color endColor,
    double position,
    double size,
    double angle,
    Matrix4 transform,
    Matrix4 projection,
  ) {
    _gradientBuffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniform4vf('uStartColor', startColor.asVector())
      ..uniform4vf('uEndColor', endColor.asVector())
      ..uniform1f('uPosition', position)
      ..uniform1f('uSize', size)
      ..uniform1f('uAngle', angle)
      ..use();

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    _gradientBuffer.clear();
    buildGradientRect(_gradientBuffer.vertex, 0, 0, width, height);
    _gradientBuffer
      ..upload(dynamic: true)
      ..draw();
  }

  // void blur(double width, double height, Color color, Matrix4 transform, Matrix4 projection) {
  //   _blurFramebuffer.clear(color: Color.black);
  //   gl.blitNamedFramebuffer(0, _blurFramebuffer.fbo, 0, 0, _context.window.width, _context.window.height, 0, 0,
  //       _blurFramebuffer.width, _blurFramebuffer.height, glColorBufferBit, glLinear);

  //   _blurBuffer.program
  //     ..uniformMat4('uTransform', transform)
  //     ..uniformMat4('uProjection', projection)
  //     ..uniformSampler('uInput', _blurFramebuffer.colorAttachment, 0)
  //     ..use();

  //   gl.disable(glBlend);

  //   _solidBuffer.clear();
  //   buildRect(_solidBuffer.vertex, 0, 0, width, height, color);
  //   _solidBuffer
  //     ..upload(dynamic: true)
  //     ..draw();

  //   gl.enable(glBlend);
  // }

  void circle(double radius, Color color, Matrix4 transform, Matrix4 projection) {
    _circleBuffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniform4vf('uColor', color.asVector())
      ..uniform1f('uRadius', radius)
      ..use();

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    _circleBuffer.clear();
    buildRect(_circleBuffer.vertex, 0, 0, radius * 2, radius * 2);
    _circleBuffer
      ..upload(dynamic: true)
      ..draw();
  }

  void blitFramebuffer(GlFramebuffer framebuffer) {
    final mesh = _blitBuffer ??= (() {
      final buffer = MeshBuffer(blitVertexDescriptor, _context.findProgram('blit'));
      buffer
        ..vertex(Vector2.zero())
        ..vertex(Vector2(1, 0))
        ..vertex(Vector2(1, 1))
        ..vertex(Vector2.zero())
        ..vertex(Vector2(1, 1))
        ..vertex(Vector2(0, 1));
      return buffer..upload();
    })();

    gl.disable(glBlend);

    mesh.program
      ..uniformSampler('sFramebuffer', framebuffer.colorAttachment, 0)
      ..use();

    gl.enable(glBlend);

    mesh.draw();
  }

  void buildRect(
    PosVertexFunction vertex,
    double x,
    double y,
    double width,
    double height,
  ) {
    vertex(Vector3(x, y, 0));
    vertex(Vector3(x, y + height, 0));
    vertex(Vector3(x + width, y + height, 0));
    vertex(Vector3(x + width, y + height, 0));
    vertex(Vector3(x + width, y, 0));
    vertex(Vector3(x, y, 0));
  }

  void buildGradientRect(
    PosUvVertexFunction vertex,
    double x,
    double y,
    double width,
    double height,
  ) {
    vertex(Vector3(x, y, 0), Vector2.zero());
    vertex(Vector3(x, y + height, 0), Vector2(0, 1));
    vertex(Vector3(x + width, y + height, 0), Vector2.all(1));
    vertex(Vector3(x + width, y + height, 0), Vector2.all(1));
    vertex(Vector3(x + width, y, 0), Vector2(1, 0));
    vertex(Vector3(x, y, 0), Vector2.zero());
  }
}
