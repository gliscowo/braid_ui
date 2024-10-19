import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

typedef BlitVertexFunction = void Function(Vector2 pos);
final VertexDescriptor<BlitVertexFunction> blitVertexDescriptor = VertexDescriptor(
  (attribute) {
    attribute('aPos', VertexElement.float, 2);
  },
  (buffer) => (pos) {
    buffer.float2(pos.x, pos.y);
  },
);

typedef PosUvVertexFunction = void Function(Vector3 pos, Vector2 uv);
final VertexDescriptor<PosUvVertexFunction> posUvVertexDescriptor = VertexDescriptor(
  (attribute) {
    attribute('aPos', VertexElement.float, 3);
    attribute('aUv', VertexElement.float, 2);
  },
  (buffer) => (pos, uv) {
    buffer.float3(pos.x, pos.y, pos.z);
    buffer.float2(uv.x, uv.y);
  },
);

typedef PosVertexFunction = void Function(Vector3 pos);
final VertexDescriptor<PosVertexFunction> posVertexDescriptor = VertexDescriptor(
  (attribute) => attribute('aPos', VertexElement.float, 3),
  (buffer) => (pos) => buffer.float3(pos.x, pos.y, pos.z),
);

typedef TextVertexFunction = void Function(double x, double y, double u, double v, Color color);
final VertexDescriptor<TextVertexFunction> textVertexDescriptor = VertexDescriptor(
  (attribute) {
    attribute('aPos', VertexElement.float, 2);
    attribute('aUv', VertexElement.float, 2);
    attribute('aColor', VertexElement.float, 4);
  },
  (buffer) => (x, y, u, v, color) {
    buffer.float2(x, y);
    buffer.float2(u, v);
    buffer.float4(color.r, color.g, color.b, color.a);
  },
);
