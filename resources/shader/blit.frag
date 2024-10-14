#version 330 core

uniform sampler2D sFramebuffer;

in vec2 vUv;

out vec4 fragColor;

void main() {
    fragColor = texture(sFramebuffer, vUv);
}