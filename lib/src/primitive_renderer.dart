import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import 'context.dart';
import 'vertex_descriptors.dart';

class PrimitiveRenderer {
  final RenderContext _context;

  final MeshBuffer<PosColorVertexFunction> _posColorBuffer;
  final MeshBuffer<PosUvVertexFunction> _gradientBuffer;
  final MeshBuffer<PosColorVertexFunction> _roundedBuffer;
  final MeshBuffer<PosColorVertexFunction> _roundedOutlineBuffer;
  final MeshBuffer<PosColorVertexFunction> _circleBuffer;
  final MeshBuffer<PosColorVertexFunction> _blurBuffer;

  final GlFramebuffer _blurFramebuffer;

  PrimitiveRenderer(this._context)
      : _posColorBuffer = MeshBuffer(posColorVertexDescriptor, _context.findProgram('pos_color')),
        _gradientBuffer = MeshBuffer(posUvVertexDescriptor, _context.findProgram('gradient')),
        _circleBuffer = MeshBuffer(posColorVertexDescriptor, _context.findProgram('circle')),
        _blurBuffer = MeshBuffer(posColorVertexDescriptor, _context.findProgram('blur')),
        _roundedBuffer = MeshBuffer(posColorVertexDescriptor, _context.findProgram('rounded_rect')),
        _roundedOutlineBuffer = MeshBuffer(posColorVertexDescriptor, _context.findProgram('rounded_rect_outline')),
        _blurFramebuffer = GlFramebuffer.trackingWindow(_context.window);

  void roundedRect(double width, double height, double radius, Color color, Matrix4 transform, Matrix4 projection,
      {double? outlineThickness}) {
    final buffer = outlineThickness == null ? _roundedBuffer : _roundedOutlineBuffer;
    buffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniform1f('uRadius', radius)
      ..uniform2f('uSize', width, height)
      ..use();

    if (outlineThickness != null) buffer.program.uniform1f('uThickness', outlineThickness);

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    buffer.clear();
    buildRect(buffer.vertex, 0, 0, width, height, color);
    buffer
      ..upload(dynamic: true)
      ..draw();
  }

  void rect(double width, double height, Color color, Matrix4 transform, Matrix4 projection) {
    _posColorBuffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..use();

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    _posColorBuffer.clear();
    buildRect(_posColorBuffer.vertex, 0, 0, width, height, color);
    _posColorBuffer
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

  void blur(double width, double height, Color color, Matrix4 transform, Matrix4 projection) {
    _blurFramebuffer.clear(color: Color.black);
    gl.blitNamedFramebuffer(0, _blurFramebuffer.fbo, 0, 0, _context.window.width, _context.window.height, 0, 0,
        _blurFramebuffer.width, _blurFramebuffer.height, glColorBufferBit, glLinear);

    _blurBuffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniformSampler('uInput', _blurFramebuffer.colorAttachment, 0)
      ..use();

    gl.disable(glBlend);

    _posColorBuffer.clear();
    buildRect(_posColorBuffer.vertex, 0, 0, width, height, color);
    _posColorBuffer
      ..upload(dynamic: true)
      ..draw();

    gl.enable(glBlend);
  }

  void circle(double x, double y, double radius, Color color, Matrix4 projection) {
    _circleBuffer.program
      ..uniformMat4('uTransform', Matrix4.identity())
      ..uniformMat4('uProjection', projection)
      ..uniform2f('uLocation', x, _context.window.height - y - radius * 2)
      ..uniform1f('uRadius', radius)
      ..use();

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    _circleBuffer.clear();
    buildRect(_circleBuffer.vertex, x, y, radius * 2, radius * 2, color);
    _circleBuffer
      ..upload(dynamic: true)
      ..draw();
  }

  void buildRect(
    PosColorVertexFunction vertex,
    double x,
    double y,
    double width,
    double height,
    Color color,
  ) {
    vertex(Vector3(x, y, 0), color);
    vertex(Vector3(x, y + height, 0), color);
    vertex(Vector3(x + width, y + height, 0), color);
    vertex(Vector3(x + width, y + height, 0), color);
    vertex(Vector3(x + width, y, 0), color);
    vertex(Vector3(x, y, 0), color);
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
