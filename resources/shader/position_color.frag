#version 330 core

uniform vec4 uColor;

in vec4 vColor;
out vec4 fragColor;

void main() {
    fragColor = vColor * uColor;
} 