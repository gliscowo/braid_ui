#version 330 core

uniform sampler2D uInput;

in vec4 vColor;
out vec4 fragColor;

const float kernel[49] = float[49] (
    0.0114,	0.0150,	0.0176,	0.0186,	0.0176,	0.0150,	0.0114,
    0.0150,	0.0197,	0.0232,	0.0246,	0.0232,	0.0197,	0.0150,
    0.0176,	0.0232,	0.0274,	0.0290,	0.0274,	0.0232,	0.0176,
    0.0186,	0.0246,	0.0290,	0.0306,	0.0290,	0.0246,	0.0186,
    0.0176,	0.0232,	0.0274,	0.0290,	0.0274,	0.0232,	0.0176,
    0.0150,	0.0197,	0.0232,	0.0246,	0.0232,	0.0197,	0.0150,
    0.0114,	0.0150,	0.0176,	0.0186,	0.0176,	0.0150,	0.0114
);

void main() {
    vec4 color = vec4(0);
    for (int x = -3; x <= 3; x++) {
        for (int y = -3; y <= 3; y++) {
            color += kernel[(x + 3) * 7 + (y + 3)] * texelFetch(uInput, ivec2(gl_FragCoord.x + x, gl_FragCoord.y + y), 0);
        }
    }

    fragColor = color * vColor;
}
