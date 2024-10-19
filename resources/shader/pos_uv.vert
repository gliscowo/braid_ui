#version 330 core

uniform mat4 uProjection;
uniform mat4 uTransform;

in vec3 aPos;
in vec2 aUv;

out vec2 vPos;
out vec2 vUv;

void main() {
    gl_Position = uProjection * uTransform * vec4(aPos.xyz, 1.0);
    vPos = aPos.xy;
    vUv = aUv;
}