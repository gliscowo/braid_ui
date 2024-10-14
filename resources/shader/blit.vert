#version 330 core

in vec2 aPos;

out vec2 vUv;

void main() {
    vec2 clipSpacePos = aPos * 2.0 - 1.0;
    gl_Position = vec4(clipSpacePos.xy, 1.0, 1.0);
    vUv = aPos.xy;
}