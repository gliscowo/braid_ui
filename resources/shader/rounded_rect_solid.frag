// shader adapted from https://www.shadertoy.com/view/WtdSDs

#version 330 core

uniform vec4 uColor;
uniform vec2 uSize;
uniform float uRadius;

in vec2 vPos;

out vec4 fragColor;

float roundedBoxSDF(vec2 center, vec2 size, float radius) {
    return length(max(abs(center) - size + radius, 0.0)) - radius;
}

void main() {
    float distance = roundedBoxSDF(vPos - (uSize / 2.0), uSize / 2.0, uRadius);
    float smoothedAlpha = uRadius != 0
        ? 1.0 - smoothstep(-1.0, 1.0, distance)
        : 1.0 - distance;
     
    if (smoothedAlpha < .001) discard;
    fragColor = vec4(uColor.rgb, uColor.a * smoothedAlpha);
}