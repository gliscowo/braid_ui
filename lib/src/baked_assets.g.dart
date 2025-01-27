import 'dart:convert';
import 'package:image/image.dart';
import 'dart:typed_data';
import 'package:braid_ui/src/resources.dart';

const _braidIconBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAMAAADVRocKAAABg1BMVEUAAAD///8A//+Z//+A/79m/8yq/9X//+McxsZd6NEX0dGx6+ti68T//+627e1m7syv798Qz89k6cj/9Oqt9etm68z/9eux9eIU2M4T0ND/9u0S09P/9/D/+Or/+OsU0NAT0sz6+usT1M+w8uVl6cr7++pn6soQ0s6y8+iw9OVl6cuw9Ob8+O5o68n8+OsU1c4T0s/8+e1o6soS09Cv9OUT1M78+u38+u0S1M9m68qw8+ew8+Zm6sqw9Oav9OZo68tm6sr9+e0S089n6sqx9Odm6smw9eWw8+b8+O0S0878+ez8+exn6ckS0s8S086w9eZn6sln6sr8+eyw8+f8+e0S088S1M/8+uxn68oS0s6w9OZo6soS08+w8+Zo6sqw8+dn6sqv9Ob7+ewS09D7+ewS1M/8+e0T088S08/8+exn6sqw9Oaw9OZn6spn6sr8+eyw9OZn6sr8+ez8+eyw9OZn6coT088S088S08/8+eyw9OZn6soS08/8+eyw9OZn6soS08+LFn/eAAAAfXRSTlMAAQEFBAUGCQkLCw0NDw4PEBAXGBkZGhoaGx0dISQnJigzNTo6Pj4+QkRER0lMTk5QVVZWWV5hY2Vma25ucXBxeH2AhomTlJeanaKjpqaoq6uusbG1tba7vL2/wMHFxcbHytfX2Nnd3N3g4+bw8PT39vb4+fn5+Pn6/fz9/bFdWH0AAAHUSURBVHja7dBVbixRDEVRP2Zm5rwwMzMzMzNzh9rtoSfKz01V+fNYSqTrAZylbfIHuQfvjfeHVr7a7sfjTrDZd4LNvhNs9p1gt+8E/L6p8G8vfvUWP8OF9N14sMELXvDCzRU+dD0xFe7P8ISpUMrMU88z9wLC7DNC3Z01Zr5oCAn9t1BAMjNfNoS+lIMC6plZa5hHJXQx6w2/QMAos95QAwL6mPWGVhDQxKw3DIGAfGa9oRcEvNxnvaGZQNfIekMhCni7zlrD8RtCXdqJ1tBGuCvjaMPWN0JdajlVcqShiFCXtJmojgrfkfsJTUDu6wJuHyvo+3jB7VsKf3cSV68KLjwaSwSu2gvXRKgIANt/yLRhO4XIQND38YLbxwtu30qA7tNPRUDuF8Syo0IZbv/HocSynk4GhXLCXaeIHIUbTjMIdZ/ORCTasPEaBRSLiNbQgAJaRERrOHgBAgZE9IZcEDAiojQAf9Qhojf0gIBaEb1hGAT8FtEb2kHA7QXRG+oIdHmiNyQRKmFQtIbVu4S6V3Mh4bKhhHD3ZSn0pYuG6XtkKnS/IzIViMgLXvDCDRaWA0Lsv3HD+GMyE9w+XtD38YLbxwtu30pw+1aC7T7Rx4fkD3Hn1gYhUrANZpgAAAAASUVORK5CYII=';
final braidIcon = decodePng(base64Decode(_braidIconBase64))!;

const _shaderSources = {
  'rounded_rect_outline.frag': '#version 330 core\nuniform vec4 uColor;uniform vec2 uSize;uniform float uRadius;uniform float uThickness;in vec4 vColor;in vec2 vPos;out vec4 fragColor;float roundedBoxSDF(vec2 center, vec2 size, float radius) {return length(max(abs(center) - size + radius, 0.0)) - radius;}void main() {float distance = roundedBoxSDF(vPos - (uSize / 2.0), (uSize - uThickness * 2) / 2.0, uRadius);float smoothedAlpha = uRadius != 0? 1.0 - smoothstep(-1.0, 1.0, abs(distance) - uThickness): 1.0 - distance;if (smoothedAlpha < .001) discard;fragColor = vec4(uColor.rgb, uColor.a * smoothedAlpha);}',
  'pos_uv.vert': '#version 330 core\nuniform mat4 uProjection;uniform mat4 uTransform;in vec3 aPos;in vec2 aUv;out vec2 vPos;out vec2 vUv;void main() {gl_Position = uProjection * uTransform * vec4(aPos.xyz, 1.0);vPos = aPos.xy;vUv = aUv;}',
  'gradient_fill.frag': '#version 330 core\nuniform vec4 uStartColor;uniform vec4 uEndColor;uniform float uPosition;uniform float uSize;uniform float uAngle;in vec2 vUv;out vec4 fragColor;void main() {float pivot = uPosition + 0.5;float size = uSize;vec2 uv = vUv - pivot;float rotated = uv.x * cos(radians(uAngle)) - uv.y * sin(radians(uAngle));float pos = smoothstep((1.0 - size) + uPosition, size + 0.0001 + uPosition, rotated + pivot);fragColor = mix(uStartColor, uEndColor, pos);}',
  'blit.vert': '#version 330 core\nin vec2 aPos;out vec2 vUv;void main() {vec2 clipSpacePos = aPos * 2.0 - 1.0;gl_Position = vec4(clipSpacePos.xy, 1.0, 1.0);vUv = aPos.xy;}',
  'solid_fill.frag': '#version 330 core\nuniform vec4 uColor;out vec4 fragColor;void main() {fragColor = uColor;}',
  'text.vert': '#version 330 core\nuniform mat4 uProjection;uniform mat4 uTransform;in vec2 aPos;in vec2 aUv;in vec4 aColor;out vec2 vUv;out vec4 vColor;void main() {gl_Position = uProjection * uTransform * vec4(aPos, 0.0, 1.0);vUv = aUv;vColor = aColor;}',
  'texture_fill.frag': '#version 330 core\nuniform sampler2D uTexture;in vec2 vUv;out vec4 fragColor;void main() {fragColor = texture(uTexture, vUv);}',
  'circle_solid.frag': '#version 330 core\nuniform vec4 uColor;uniform float uRadius;in vec2 vPos;out vec4 fragColor;void main() {vec2 center = vec2(uRadius);float distance = length(vPos - center);float alpha = 1 - smoothstep(uRadius - 2, uRadius, distance);if(alpha < .001) discard;fragColor = vec4(uColor.rgb, alpha * uColor.a);}',
  'rounded_rect_solid.frag': '#version 330 core\nuniform vec4 uColor;uniform vec2 uSize;uniform float uRadius;in vec2 vPos;out vec4 fragColor;float roundedBoxSDF(vec2 center, vec2 size, float radius) {return length(max(abs(center) - size + radius, 0.0)) - radius;}void main() {float distance = roundedBoxSDF(vPos - (uSize / 2.0), uSize / 2.0, uRadius);float smoothedAlpha = uRadius != 0? 1.0 - smoothstep(-1.0, 1.0, distance): 1.0 - distance;if (smoothedAlpha < .001) discard;fragColor = vec4(uColor.rgb, uColor.a * smoothedAlpha);}',
  'blit.frag': '#version 330 core\nuniform sampler2D sFramebuffer;in vec2 vUv;out vec4 fragColor;void main() {fragColor = texture(sFramebuffer, vUv);}',
  'pos.vert': '#version 330 core\nin vec3 aPos;uniform mat4 uProjection;uniform mat4 uTransform;out vec2 vPos;void main() {gl_Position = uProjection * uTransform * vec4(aPos.xyz, 1.0);vPos = aPos.xy;}',
  'pos_color.vert': '#version 330 core\nin vec3 aPos;in vec4 aColor;uniform mat4 uProjection;uniform mat4 uTransform;out vec4 vColor;out vec2 vPos;void main() {gl_Position = uProjection * uTransform * vec4(aPos.xyz, 1.0);vColor = aColor;vPos = aPos.xy;}',
  'text.frag': '#version 330 core\nuniform sampler2D sText;in vec2 vUv;in vec4 vColor;layout(location = 0, index = 0) out vec4 fragColor;layout(location = 0, index = 1) out vec4 fragColorMask;void main() {fragColor = vColor;fragColorMask = vec4(texture(sText, vUv));}',
};

String getShaderSource(String shaderName) {
  if (!_shaderSources.containsKey(shaderName)) {
    throw _BakedAssetError('missing shader source for \'$shaderName\'');
  }

  return _shaderSources[shaderName]!;
}

class BakedAssetResources implements BraidResources {
  final BraidResources _fontDelegate;
  BakedAssetResources(this._fontDelegate);

  @override
  Future<String> loadShader(String path) => Future.value(getShaderSource(path));

  @override
  Stream<Uint8List> loadFontFamily(String familyName) => _fontDelegate.loadFontFamily(familyName);
}

// ---

class _BakedAssetError extends Error {
  final String message;
  _BakedAssetError(this.message);

  @override
  String toString() => 'baked asset error: $message';
}

