shader_type canvas_item;

// Nine Rivers (九河) — Living River Water & Caustics Shader
// Creates deep translucent river currents, subtle water caustics, and floating gold dust.

uniform vec4 deep_water_color : source_color = vec4(0.02, 0.09, 0.08, 1.0);
uniform vec4 shallow_water_color : source_color = vec4(0.06, 0.22, 0.17, 1.0);
uniform vec4 caustic_color : source_color = vec4(0.18, 0.65, 0.52, 0.45);
uniform vec4 gold_mote_color : source_color = vec4(0.96, 0.76, 0.28, 0.7);
uniform float flow_speed : hint_range(0.05, 1.0) = 0.18;

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * flow_speed;
    
    // Multi-octave wave distortion
    vec2 wave_uv = uv * 3.5 + vec2(0.0, t);
    float n1 = noise(wave_uv);
    float n2 = noise(wave_uv * 2.0 - vec2(t * 0.7, 0.0));
    vec2 distorted_uv = uv + vec2(n1, n2) * 0.04;
    
    // Deep-to-shallow gradient with vertical river flow
    float depth_grad = smoothstep(0.0, 1.0, uv.y + n1 * 0.15);
    vec4 base = mix(deep_water_color, shallow_water_color, depth_grad);
    
    // Caustics lines
    float c1 = abs(noise(distorted_uv * 8.0 + vec2(t * 0.5, t * 0.3)));
    float c2 = abs(noise(distorted_uv * 12.0 - vec2(t * 0.4, t * 0.6)));
    float caustic = smoothstep(0.45, 0.05, min(c1, c2));
    base = mix(base, caustic_color, caustic * 0.35);
    
    // Floating gold motes / river spirits
    vec2 mote_uv = uv * 14.0 + vec2(sin(t * 1.2 + uv.y * 5.0) * 0.2, t * 0.8);
    float mote = step(0.975, fract(sin(dot(floor(mote_uv), vec2(12.9898, 78.233))) * 43758.5453));
    base += gold_mote_color * mote * (0.5 + 0.5 * sin(TIME * 3.0 + uv.x * 20.0));
    
    // Vignette
    float vignette = length((UV - vec2(0.5)) * vec2(1.0, 0.85));
    base.rgb *= smoothstep(0.95, 0.35, vignette);
    
    COLOR = base;
}
