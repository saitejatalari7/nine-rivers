shader_type canvas_item;

// Nine Rivers (九河) — Ceramic Ivory & Jade Tile Surface Shader
// Adds subtle ceramic micro-grain, warm depth gradient, and specular rim sheen.

uniform float grain_intensity : hint_range(0.0, 0.08) = 0.025;
uniform float specular_strength : hint_range(0.0, 0.5) = 0.18;
uniform vec4 tint_warmth : source_color = vec4(1.0, 0.985, 0.945, 1.0);

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec4 col = COLOR;
    
    // Subtle top-down ceramic warmth gradient
    float v_grad = smoothstep(0.0, 1.0, UV.y);
    col.rgb *= mix(vec3(1.02, 1.01, 1.0), vec3(0.96, 0.94, 0.91), v_grad);
    
    // Subtle procedural micro-grain
    float grain = (hash21(UV * 250.0) - 0.5) * grain_intensity;
    col.rgb += grain;
    
    // Glossy top rim specular highlight
    float top_rim = smoothstep(0.06, 0.0, UV.y) * specular_strength;
    col.rgb += vec3(top_rim);
    
    COLOR = col;
}
