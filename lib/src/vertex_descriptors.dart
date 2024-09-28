import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

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

typedef PosColorVertexFunction = void Function(Vector3 pos, Color color);
final VertexDescriptor<PosColorVertexFunction> posColorVertexDescriptor = VertexDescriptor(
  (attribute) {
    attribute('aPos', VertexElement.float, 3);
    attribute('aColor', VertexElement.float, 4);
  },
  (buffer) => (pos, color) {
    buffer.float3(pos.x, pos.y, pos.z);
    buffer.float4(color.r, color.g, color.b, color.a);
  },
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
