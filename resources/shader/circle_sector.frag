#version 330 core

uniform vec4 uColor;
uniform float uRadius;
uniform float uInnerRadius;
uniform float uAngleOffset;
uniform float uAngleTo;

in vec2 vPos;
out vec4 fragColor;

#define PI 3.1415926535

void main() {
    vec2 center = vec2(uRadius);
    float distance = length(vPos - center);
    float alpha = smoothstep(uRadius, uRadius - 1.5, distance) * smoothstep(uInnerRadius - 1.5, uInnerRadius, distance);

    float angle = atan((vPos - center).y, (vPos - center).x) + PI - uAngleOffset;
    angle += angle < 0.0 ? PI + PI : 0.0;

    if (angle > uAngleTo) discard;

    if(alpha < .001) discard;
    fragColor = vec4(uColor.rgb, alpha * uColor.a);
}