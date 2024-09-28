#version 330 core

in vec2 aPos; // <vec2 pos, vec2 tex>
in vec2 aUv; // <vec2 pos, vec2 tex>
in vec4 aColor; // <vec2 pos, vec2 tex>

out vec2 texCoords;
out vec4 textColor;

uniform mat4 uProjection;

void main() {
    gl_Position = uProjection * vec4(aPos, 0.0, 1.0);

    texCoords = aUv;
    textColor = aColor;
}