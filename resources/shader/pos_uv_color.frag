#version 330 core

uniform sampler2D uTexture;

in vec4 vColor;
in vec2 vUv;

out vec4 fragColor;

void main() {
    fragColor = texture(uTexture, vUv) * vColor;
} 