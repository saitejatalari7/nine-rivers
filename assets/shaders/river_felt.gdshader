shader_type canvas_item;

// Nine Rivers (九河) — Imperial Baize & Flowing Riverbed Table Shader
// Blends high-grade woven dark emerald baize with subterranean water currents & golden flow veins.

uniform vec4 felt_color : source_color = vec4(0.0196, 0.149, 0.1137, 1.0);
uniform vec4 caustic_color : source_color = vec4(0.0627, 0.4196, 0.3216, 0.45);
uniform vec4 gold_color : source_color = vec4(0.96, 0.73, 0.19, 0.85);
uniform vec4 secondary_color : source_color = vec4(0.04, 0.25, 0.20, 0.5);

uniform float flow_level : hint_range(0.0, 9.0) = 0.0;
uniform float overdrive : hint_range(0.0, 1.0) = 0.0;
uniform float speed : hint_range(0.1, 4.0) = 0.8;
uniform vec2 parallax_offset = vec2(0.0, 0.0);

// Pseudo-random hash
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(dot(hash(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
    vec2 uv = (UV + parallax_offset) * 4.0;
    float time_val = TIME * speed * (1.0 + flow_level * 0.15);
    
    // 1. Subtle woven felt baize texture
    float weave = sin((UV.x + parallax_offset.x * 0.2) * 320.0) * cos((UV.y + parallax_offset.y * 0.2) * 320.0) * 0.025;
    
    // 2. Subterranean river water currents
    float n1 = noise(uv + vec2(time_val * 0.25, time_val * 0.18));
    float n2 = noise(uv * 2.2 - vec2(time_val * 0.35, -time_val * 0.22));
    float caustic = pow(abs(n1 + n2 * 0.5), 2.1);
    
    // 3. Radial vignette for table focus
    vec2 center = UV - 0.5;
    float vignette = 1.0 - dot(center, center) * 0.72;
    vec4 col = (felt_color + vec4(weave)) * vignette;
    
    // 4. Secondary water depth gradient
    float depth_flow = clamp(n1 * 0.5 + 0.5, 0.0, 1.0);
    col = mix(col, secondary_color * vignette, depth_flow * 0.35);
    
    // 5. Flowing water illumination
    float stream_strength = 0.18 + (flow_level / 9.0) * 0.38;
    col += caustic_color * caustic * stream_strength;
    
    // 6. Golden Flow Overdrive veins
    if (overdrive > 0.01 || flow_level >= 7.0) {
        float od = max(overdrive, (flow_level - 6.0) / 3.0);
        float gold_pulse = sin(TIME * 4.5) * 0.5 + 0.5;
        float gold_caustic = pow(abs(n2), 2.5);
        col += gold_color * gold_caustic * (od * (0.40 + gold_pulse * 0.25));
    }
    
    COLOR = col;
}
