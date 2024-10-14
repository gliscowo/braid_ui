#version 330 core

uniform mat4 uProjection;
uniform mat4 uTransform;

in vec2 aPos;
in vec2 aUv;
in vec4 aColor;

out vec2 vUv;
out vec4 vColor;

void main() {
    gl_Position = uProjection * uTransform * vec4(aPos, 0.0, 1.0);

    vUv = aUv;
    vColor = aColor;
}