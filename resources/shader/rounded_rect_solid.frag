// shader adapted from https://www.shadertoy.com/view/WtdSDs

#version 330 core

uniform vec4 uColor;
uniform vec2 uSize;
uniform vec4 uRadius;

in vec2 vPos;

out vec4 fragColor;

float sdRoundBox(in vec2 pos, in vec2 size, in vec4 radii) {
    radii.xy = (pos.x > 0.0) ? radii.xy : radii.zw;
    radii.x = (pos.y > 0.0) ? radii.x : radii.y;

    vec2 q = abs(pos) - size + radii.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radii.x;
}

void main() {
    float distance = sdRoundBox(vPos - (uSize / 2.0), uSize / 2.0, uRadius);
    float smoothedAlpha = uRadius != vec4(0)
        ? 1.0 - smoothstep(-0.5, 1.0, distance)
        : 1.0 - distance;

    if (smoothedAlpha < .001) discard;
    fragColor = vec4(uColor.rgb, uColor.a * smoothedAlpha);
}