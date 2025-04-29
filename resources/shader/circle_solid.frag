#version 330 core

uniform vec4 uColor;
uniform float uRadius;

in vec2 vPos;
out vec4 fragColor;

void main() {
    vec2 center = vec2(uRadius);
    float distance = length(vPos - center);
    float alpha = 1 - smoothstep(uRadius - 1.5, uRadius, distance);

    if(alpha < .001) discard;
    fragColor = vec4(uColor.rgb, alpha * uColor.a);
}