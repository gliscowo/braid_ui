// shader adapted from https://www.shadertoy.com/view/WtdSDs

#version 330 core

uniform vec2 uLocation;
uniform vec2 uSize;
uniform float uRadius;
uniform float uThickness;

in vec4 vColor;
out vec4 fragColor;

float roundedBoxSDF(vec2 center, vec2 size, float radius) {
    return length(max(abs(center) - size + radius, 0.0)) - radius;
}

void main() {
    float distance = roundedBoxSDF(gl_FragCoord.xy - uLocation - (uSize / 2.0), (uSize - uThickness * 2) / 2.0, uRadius);
    float smoothedAlpha = 1.0 - smoothstep(-1.0, 1.0, abs(distance) - uThickness);

    fragColor = vec4(vColor.rgb, vColor.a * smoothedAlpha);
}