import 'package:clawclip/clawclip.dart';
import 'package:vector_math/vector_math.dart';

typedef BlitVertex = ({Vector2 pos});
final blitVertexDescriptor = VertexDescriptor<BlitVertex>([.f32x2(name: 'aPos', getter: (vertex) => vertex.pos)]);

typedef PosUvVertex = ({Vector3 pos, Vector2 uv});
final posUvVertexDescriptor = VertexDescriptor<PosUvVertex>([
  .f32x3(name: 'aPos', getter: (vertex) => vertex.pos),
  .f32x2(name: 'aUv', getter: (vertex) => vertex.uv),
]);

typedef PosVertex = ({Vector3 pos});
final posVertexDescriptor = VertexDescriptor<PosVertex>([.f32x3(name: 'aPos', getter: (vertex) => vertex.pos)]);

typedef PosColorVertex = ({Vector3 pos, Color color});
final posColorVertexDescriptor = VertexDescriptor<PosColorVertex>([
  .f32x3(name: 'aPos', getter: (vertex) => vertex.pos),
  .color(name: 'aColor', getter: (vertex) => vertex.color),
]);

typedef TextVertex = ({double x, double y, double u, double v, Color color});
final textVertexDescriptor = VertexDescriptor<TextVertex>([
  .direct(name: 'aPos', primitive: .f32, length: 2, serializer: (buffer, vertex) => buffer.f32x2(vertex.x, vertex.y)),
  .direct(name: 'aUv', primitive: .f32, length: 2, serializer: (buffer, vertex) => buffer.f32x2(vertex.u, vertex.v)),
  .color(name: 'aColor', getter: (vertex) => vertex.color),
]);
