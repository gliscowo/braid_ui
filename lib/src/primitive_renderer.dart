import 'dart:collection';
import 'dart:math';

import 'package:clawclip/clawclip.dart';
import 'package:clawclip/opengl.dart';
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

  MeshBuffer<Vertex> getBuffer<Vertex>(Symbol symbol, VertexDescriptor<Vertex> descriptor, String program) {
    return (_buffers[symbol] ??= MeshBuffer<Vertex>(descriptor, _context.findProgram(program))) as MeshBuffer<Vertex>;
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
    final buffer = outlineThickness == null
        ? getBuffer(#roundedSolid, posVertexDescriptor, 'rounded_rect_solid')
        : getBuffer(#roundedOutline, posVertexDescriptor, 'rounded_rect_outline');

    buffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniform4vf('uColor', color.asVector())
      ..uniform4f('uRadius', radius.bottomRight, radius.topRight, radius.bottomLeft, radius.topLeft)
      ..uniform2f('uSize', width, height)
      ..use();

    if (outlineThickness != null) buffer.program.uniform1f('uThickness', outlineThickness);

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    buffer
      ..clear()
      ..writeVertices(rectVertices(width, height))
      ..upload(usage: .dynamicDraw)
      ..draw();
  }

  void rect(double width, double height, Color color, Matrix4 transform, Matrix4 projection) {
    final buffer = getBuffer(#solid, posVertexDescriptor, 'solid_fill');

    buffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniform4vf('uColor', color.asVector())
      ..use();

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    buffer
      ..clear()
      ..writeVertices(rectVertices(width, height))
      ..upload(usage: .dynamicDraw)
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
    final buffer = getBuffer(#gradient, posUvVertexDescriptor, 'gradient_fill');

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

    buffer
      ..clear()
      ..writeVertices(uvRectVertices(width, height))
      ..upload(usage: .dynamicDraw)
      ..draw();
  }

  GlFramebuffer? _blurFramebuffer;
  BufferWriter? _kernelBuffer;
  GlBufferObject? _kernelSsbo;

  static double _gaussKernel(double x, double sigma) {
    return (1 / sqrt(2 * pi * sigma * sigma)) * pow(e, -((x * x) / (2 * sigma * sigma)));
  }

  void blur(double width, double height, double radius, Matrix4 transform, Matrix4 projection) {
    {
      final ssboWriter = _kernelBuffer ??= BufferWriter(NativeByteArray(size: 128));
      ssboWriter.rewind();

      for (var x = 0; x <= radius.ceil(); x++) {
        ssboWriter.f32(_gaussKernel(x.toDouble(), radius / 3));
      }

      final ssbo = _kernelSsbo ??= GlBufferObject.shaderStorage();
      ssbo.upload(ssboWriter, BufferUsage.streamDraw);
    }

    final framebuffer = _blurFramebuffer ??= GlFramebuffer.trackingWindow(_context.window);
    final buffer = getBuffer(#blur, posVertexDescriptor, 'blur');

    gl.blitNamedFramebuffer(
      0,
      framebuffer.fbo,
      0,
      0,
      _context.window.width,
      _context.window.height,
      0,
      0,
      framebuffer.width,
      framebuffer.height,
      glColorBufferBit,
      glLinear,
    );

    buffer.program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..uniformSampler('uInput', framebuffer.colorAttachment, 0)
      ..uniform2i('uInputSize', framebuffer.width - 1, framebuffer.height - 1)
      ..uniform1i('uKernelSize', radius.ceil())
      ..uniform2i('uBlurDirection', 0, 1)
      ..ssbo(0, _kernelSsbo!.id)
      ..use();

    gl.disable(glBlend);

    buffer
      ..clear()
      ..writeVertices(rectVertices(width, height))
      ..upload(usage: .dynamicDraw)
      ..draw();

    gl.blitNamedFramebuffer(
      0,
      framebuffer.fbo,
      0,
      0,
      _context.window.width,
      _context.window.height,
      0,
      0,
      framebuffer.width,
      framebuffer.height,
      glColorBufferBit,
      glLinear,
    );

    buffer.program.uniform2i('uBlurDirection', 1, 0);
    buffer.draw();

    gl.enable(glBlend);
  }

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

    final buffer = solid
        ? getBuffer(#circleSolid, posVertexDescriptor, 'circle_solid')
        : getBuffer(#circleSector, posVertexDescriptor, 'circle_sector');

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

    buffer
      ..clear()
      ..writeVertices(rectVertices(radius * 2, radius * 2))
      ..upload(usage: .dynamicDraw)
      ..draw();
  }

  void blitFramebuffer(GlFramebuffer framebuffer) {
    final mesh = _buffers[#blit] ??= (() {
      return MeshBuffer(blitVertexDescriptor, _context.findProgram('blit'))
        ..writeVertices([
          (pos: Vector2.zero()),
          (pos: Vector2(1, 0)),
          (pos: Vector2(1, 1)),
          (pos: Vector2.zero()),
          (pos: Vector2(1, 1)),
          (pos: Vector2(0, 1)),
        ])
        ..upload();
    })();

    gl.disable(glBlend);

    mesh.program
      ..uniformSampler('sFramebuffer', framebuffer.colorAttachment, 0)
      ..use();

    gl.enable(glBlend);

    mesh.draw();
  }

  List<PosVertex> rectVertices(double width, double height) => [
    (pos: Vector3(0, 0, 0)),
    (pos: Vector3(0, height, 0)),
    (pos: Vector3(width, height, 0)),
    (pos: Vector3(width, height, 0)),
    (pos: Vector3(width, 0, 0)),
    (pos: Vector3(0, 0, 0)),
  ];

  List<PosUvVertex> uvRectVertices(double width, double height, {double? uMax, double? vMax}) {
    uMax ??= 1;
    vMax ??= 1;

    return [
      (pos: Vector3(0, 0, 0), uv: Vector2.zero()),
      (pos: Vector3(0, height, 0), uv: Vector2(0, vMax)),
      (pos: Vector3(width, height, 0), uv: Vector2(uMax, vMax)),
      (pos: Vector3(width, height, 0), uv: Vector2(uMax, vMax)),
      (pos: Vector3(width, 0, 0), uv: Vector2(uMax, 0)),
      (pos: Vector3(0, 0, 0), uv: Vector2.zero()),
    ];
  }
}
