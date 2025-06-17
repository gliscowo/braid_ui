#version 450 core

uniform sampler2D uInput;
uniform ivec2 uInputSize;

uniform int uKernelSize;
uniform ivec2 uBlurDirection;
layout(binding = 0) readonly buffer ssbo {
    float[] uKernel;
};

// in vec4 vColor;
out vec4 fragColor;

void main() {
    fragColor = vec4(0);

    for (int offset = -uKernelSize; offset <= uKernelSize; offset++) {
        float x = clamp(gl_FragCoord.x + uBlurDirection.x * offset, 0, uInputSize.x);
        float y = clamp(gl_FragCoord.y + uBlurDirection.y * offset, 0, uInputSize.y);

        fragColor += uKernel[abs(offset)] * texelFetch(uInput, ivec2(x, y), 0);
    }
}
