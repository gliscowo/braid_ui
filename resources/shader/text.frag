#version 330 core

in vec2 texCoords;
in vec4 textColor;

layout(location = 0, index = 0) out vec4 fragColor;
layout(location = 0, index = 1) out vec4 fragColorMask;

uniform sampler2D sText;

void main() {
    fragColor = textColor;
    fragColorMask = vec4(texture(sText, texCoords));
}