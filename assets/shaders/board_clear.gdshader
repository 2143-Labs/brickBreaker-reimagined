shader_type canvas_item;
render_mode blend_mix;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 1.0;

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract(p.x * p.y);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec2 uv = UV;
    vec2 d = uv - center;
    d.x *= aspect;
    float r = length(d);
    float a = atan(d.y, d.x);

    float t = progress;
    float ring_radius = pow(t, 0.7) * 1.15;
    float ring_thickness = 0.06 + t * 0.22;
    float ring = 1.0 - smoothstep(0.0, ring_thickness, abs(r - ring_radius));

    // Inner pulse (hot core trailing the leading edge)
    float inner = 1.0 - smoothstep(ring_radius - 0.18, ring_radius, r);
    inner *= 1.0 - smoothstep(0.0, 0.5, t);

    // Rainbow tint: hue depends on angle and time so the band twists
    float hue = fract(a / 6.28318 + t * 0.65);
    vec3 ring_col = hsv2rgb(vec3(hue, 0.85, 1.0));

    // Sparkle pattern around the leading edge
    float sparkle = 0.0;
    vec2 spuv = uv * vec2(120.0 * aspect, 120.0);
    vec2 cell = floor(spuv);
    float h = hash(cell);
    if (h > 0.93) {
        float dist_from_ring = abs(r - ring_radius);
        float band = 1.0 - smoothstep(0.0, 0.18, dist_from_ring);
        float twinkle = 0.5 + 0.5 * sin(t * 28.0 + h * 19.0);
        sparkle = band * twinkle;
    }

    // Streaks radiating outward from the center
    float streaks = 0.5 + 0.5 * sin(a * 18.0 + t * 6.0);
    streaks = pow(streaks, 6.0) * (1.0 - smoothstep(0.0, ring_radius + 0.05, r)) * (1.0 - t);

    float fade = 1.0 - smoothstep(0.7, 1.0, t);
    float alpha = (ring * 0.95 + inner * 0.55 + sparkle * 0.9 + streaks * 0.35) * fade;
    vec3 col = ring_col * (ring + sparkle * 1.2 + streaks * 0.6)
             + vec3(1.0, 0.95, 0.85) * inner * 0.65;

    COLOR = vec4(col, clamp(alpha, 0.0, 0.95));
}
