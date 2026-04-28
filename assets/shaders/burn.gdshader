shader_type canvas_item;
render_mode blend_add;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform float speed : hint_range(0.0, 8.0) = 3.5;
// UV.y at which the flame originates. Above this is open air (flames),
// below is brick surface (heat tint).
uniform float source_y : hint_range(0.0, 1.0) = 0.5;

float hash21(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
    return vec2(hash21(p), hash21(p + vec2(71.0, 113.0)));
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * vnoise(p);
        p = p * 2.13 + vec2(13.7, 19.3);
        a *= 0.55;
    }
    return v;
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * speed + seed;
    float x_c = (uv.x - 0.5) * 2.0;

    // 0 at source, 1 at top of rect (the open-air flame zone)
    float above = clamp((source_y - uv.y) / max(source_y, 0.001), 0.0, 1.0);
    // 0 at source, 1 at bottom of rect (the brick surface)
    float below = clamp((uv.y - source_y) / max(1.0 - source_y, 0.001), 0.0, 1.0);

    // ---- Flame body ----
    vec2 nuv = vec2(uv.x * 2.4, uv.y * 3.4 + t);
    nuv.x += sin(uv.y * 4.5 + t * 1.4) * 0.18;
    float n = mix(fbm(nuv), fbm(nuv * 1.7 + vec2(t * 0.45, 0.0)), 0.5);

    float taper = 1.0 - smoothstep(0.0, 1.0, above);
    float side = 1.0 - smoothstep(0.45, 1.0, abs(x_c) + above * 0.45);
    float flame = smoothstep(0.32, 0.78, n * 1.55 * taper * side) * intensity;

    // ---- Hot core glow at base ----
    float core = pow(taper, 6.0) * intensity;
    core *= 1.0 - smoothstep(0.0, 0.9, abs(x_c));

    // ---- Embers / sparks drifting upward ----
    vec2 e_uv = vec2(uv.x, uv.y + t * 0.20);
    vec2 ec = e_uv * vec2(7.5, 6.5);
    vec2 ei = floor(ec);
    vec2 ef = fract(ec);
    vec2 jitter = hash22(ei + seed);
    float spark = 0.0;
    if (jitter.x > 0.85) {
        spark = 1.0 - smoothstep(0.04, 0.18, length(ef - jitter));
        spark *= smoothstep(0.0, 0.05, source_y - uv.y);
        spark *= 0.55 + 0.45 * sin(t * 9.0 + jitter.y * 30.0);
    }
    spark *= intensity;

    // ---- Heat shimmer on brick (below source) ----
    float heat = (1.0 - smoothstep(0.0, 0.65, below)) * intensity;
    heat *= 1.0 - smoothstep(0.85, 1.0, abs(x_c));
    heat *= 0.55 + 0.45 * fbm(vec2(uv.x * 3.0, uv.y * 4.0 + t * 0.6));

    // ---- Color composition ----
    vec3 ember = vec3(0.55, 0.07, 0.02);
    vec3 orange = vec3(1.0, 0.5, 0.1);
    vec3 yellow = vec3(1.0, 0.9, 0.4);
    vec3 white = vec3(1.0, 1.0, 0.92);

    vec3 flame_col = mix(ember, orange, smoothstep(0.05, 0.45, flame));
    flame_col = mix(flame_col, yellow, smoothstep(0.45, 0.78, flame));
    flame_col = mix(flame_col, white, smoothstep(0.78, 1.0, flame) * (1.0 - above * 0.5));

    vec3 col = flame_col * flame;
    col += vec3(1.0, 0.6, 0.15) * core * 0.95;
    col += vec3(1.0, 0.85, 0.35) * spark * 1.4;
    col += vec3(0.95, 0.28, 0.05) * heat * 0.55;

    // ---- Edge fade so the rect bounds don't show ----
    float fade = smoothstep(0.0, 0.06, uv.y)
               * smoothstep(0.0, 0.05, uv.x)
               * smoothstep(0.0, 0.05, 1.0 - uv.x);
    col *= fade;

    COLOR = vec4(col, 1.0);
}
