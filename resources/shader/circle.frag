#version 330 core

uniform vec2 uLocation;
uniform float uRadius;

in vec4 vColor;
out vec4 fragColor;

void main() {
    vec2 center = uLocation + vec2(uRadius);
    float distance = length(gl_FragCoord.xy - center);
    float alpha = 1 - smoothstep(uRadius - 2, uRadius, distance);

    fragColor = vec4(vColor.rgb, alpha * vColor.a);
} 