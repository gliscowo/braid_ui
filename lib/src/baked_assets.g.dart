import 'dart:convert';
import 'package:image/image.dart';
import 'dart:typed_data';
import 'package:braid_ui/src/resources.dart';

const _braidIconBase64 = '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';
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

