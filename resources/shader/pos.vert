#version 330 core

in vec3 aPos;

uniform mat4 uProjection;
uniform mat4 uTransform;

out vec2 vPos;

void main() {
    gl_Position = uProjection * uTransform * vec4(aPos.xyz, 1.0);
    vPos = aPos.xy;
}