#version 330 core

uniform sampler2D sText;

in vec2 vUv;
in vec4 vColor;

layout(location = 0, index = 0) out vec4 fragColor;
layout(location = 0, index = 1) out vec4 fragColorMask;

void main() {
    fragColor = vColor;
    fragColorMask = vec4(texture(sText, vUv));
}