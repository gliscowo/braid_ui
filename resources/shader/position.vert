#version 330 core

in vec3 aPos;
in vec4 aColor;

uniform mat4 uProjection;
uniform mat4 uTransform;

out vec4 vColor;

void main() {
    gl_Position = uProjection * uTransform * vec4(aPos.xyz, 1.0);
    vColor = aColor;
}