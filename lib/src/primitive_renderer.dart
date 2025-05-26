import 'dart:collection';
import 'dart:math';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:diamond_gl/opengl.dart';
import 'package:vector_math/vector_math.dart';

import 'context.dart';
import 'core/math.dart';
import 'vertex_descriptors.dart';

class PrimitiveRenderer {
  final RenderContext _context;

  final Map<Symbol, MeshBuffer> _buffers = HashMap();

  PrimitiveRenderer(this._context);

  void clearShaderCache() {
    for (final buffer in _buffers.values) {
      buffer.delete();
    }

    _buffers.clear();
  }

  MeshBuffer<VF> _getBuffer<VF extends Function>(Symbol symbol, VertexDescriptor<VF> descriptor, String program) {
    return (_buffers[symbol] ??= MeshBuffer<VF>(descriptor, _context.findProgram(program))) as MeshBuffer<VF>;
  }

  void roundedRect(
    double width,
    double height,
    CornerRadius radius,
    Color color,
    Matrix4 transform,
    Matrix4 projection, {
    double? outlineThickness,
  }) {
    final buffer =
        outlineThickness == null
            ? _getBuffer(#roundedSolid, posVertexDescriptor, 'rounded_rect_solid')
            : _getBuffer(#roundedOutline, posVertexDescriptor, 'rounded_rect_outline');

    buffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniform4vf('uColor', color.asVector())
      ..uniform4f('uRadius', radius.bottomRight, radius.topRight, radius.bottomLeft, radius.topLeft)
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
    final buffer = _getBuffer(#solid, posVertexDescriptor, 'solid_fill');

    buffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniform4vf('uColor', color.asVector())
      ..use();

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    buffer.clear();
    buildRect(buffer.vertex, 0, 0, width, height);
    buffer
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
    final buffer = _getBuffer(#gradient, posUvVertexDescriptor, 'gradient_fill');

    buffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniform4vf('uStartColor', startColor.asVector())
      ..uniform4vf('uEndColor', endColor.asVector())
      ..uniform1f('uPosition', position)
      ..uniform1f('uSize', size)
      ..uniform1f('uAngle', angle)
      ..use();

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    buffer.clear();
    buildGradientRect(buffer.vertex, 0, 0, width, height);
    buffer
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

  void circle(
    double radius,
    Color color,
    Matrix4 transform,
    Matrix4 projection, {
    double? innerRadius,
    double? toAngle,
    double? angleOffset,
  }) {
    final solid = innerRadius == null && toAngle == null && angleOffset != null;

    final buffer =
        solid
            ? _getBuffer(#circleSolid, posVertexDescriptor, 'circle_solid')
            : _getBuffer(#circleSector, posVertexDescriptor, 'circle_sector');

    buffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniform4vf('uColor', color.asVector())
      ..uniform1f('uRadius', radius)
      ..use();

    if (!solid) {
      buffer.program.uniform1f('uInnerRadius', innerRadius ?? -1);

      buffer.program.uniform1f('uAngleOffset', ((angleOffset ?? 0) + pi / 2) % (pi * 2));
      buffer.program.uniform1f('uAngleTo', toAngle ?? pi * 2);
    }

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    buffer.clear();
    buildRect(buffer.vertex, 0, 0, radius * 2, radius * 2);
    buffer
      ..upload(dynamic: true)
      ..draw();
  }

  void blitFramebuffer(GlFramebuffer framebuffer) {
    final mesh =
        _buffers[#blit] ??=
            (() {
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

  void buildRect(PosVertexFunction vertex, double x, double y, double width, double height) {
    vertex(Vector3(x, y, 0));
    vertex(Vector3(x, y + height, 0));
    vertex(Vector3(x + width, y + height, 0));
    vertex(Vector3(x + width, y + height, 0));
    vertex(Vector3(x + width, y, 0));
    vertex(Vector3(x, y, 0));
  }

  void buildGradientRect(PosUvVertexFunction vertex, double x, double y, double width, double height) {
    vertex(Vector3(x, y, 0), Vector2.zero());
    vertex(Vector3(x, y + height, 0), Vector2(0, 1));
    vertex(Vector3(x + width, y + height, 0), Vector2.all(1));
    vertex(Vector3(x + width, y + height, 0), Vector2.all(1));
    vertex(Vector3(x + width, y, 0), Vector2(1, 0));
    vertex(Vector3(x, y, 0), Vector2.zero());
  }
}
