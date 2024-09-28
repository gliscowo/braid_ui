#version 330 core

uniform vec4 uStartColor;
uniform vec4 uEndColor;
uniform float uPosition;
uniform float uSize;
uniform float uAngle;

in vec2 vUv;
out vec4 fragColor;

// adapted from https://godotshaders.com/shader/linear-gradient/

void main() {
    float pivot = uPosition + 0.5;
    float size = uSize + .5;

    vec2 uv = vUv - pivot;
    float rotated = uv.x * cos(radians(uAngle)) - uv.y * sin(radians(uAngle));
    float pos = smoothstep((1.0 - size) + uPosition, size + 0.0001 + uPosition, rotated + pivot);
    fragColor = mix(uStartColor, uEndColor, pos);
}