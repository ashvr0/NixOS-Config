#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0..1
    float mode;         // 1 = sweep (wipe and swipe), 2 = circle
    float halfExtent;   // sweep: half the projected size of the screen along dir
    float maxRadius;    // circle: radius that covers the whole screen
    float feather;      // edge softness in pixels
    vec2 size;          // output size in pixels
    vec2 dir;           // sweep: front edge moves along this unit vector
    vec2 origin;        // circle: center as 0..1 fractions
} ubuf;

layout(binding = 1) uniform sampler2D oldTex;
layout(binding = 2) uniform sampler2D newTex;

void main() {
    vec4 oldC = texture(oldTex, qt_TexCoord0);
    vec4 newC = texture(newTex, qt_TexCoord0);
    vec2 p = qt_TexCoord0 * ubuf.size;
    float reveal = 0.0;
    float f = max(ubuf.feather * 0.5, 0.5);

    if (ubuf.mode < 1.5) {
        float t = -ubuf.halfExtent + ubuf.progress * 2.0 * ubuf.halfExtent;
        float d = dot(p - ubuf.size * 0.5, ubuf.dir);
        reveal = 1.0 - smoothstep(t - f, t + f, d);
    } else {
        float r = ubuf.maxRadius * ubuf.progress;
        float d = distance(p, ubuf.origin * ubuf.size);
        reveal = 1.0 - smoothstep(r - f, r + f, d);
    }

    fragColor = mix(oldC, newC, reveal) * ubuf.qt_Opacity;
}
