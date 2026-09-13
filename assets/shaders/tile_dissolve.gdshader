shader_type canvas_item;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_thickness : hint_range(0.0, 0.40) = 0.14;
uniform vec4 edge_color : source_color = vec4(0.96, 0.75, 0.22, 1.0);   // Molten 24k Gold
uniform vec4 ember_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);  // Blazing White-Gold Core
uniform vec4 burn_color : source_color = vec4(0.85, 0.22, 0.08, 1.0);   // Cinnabar/Charred Ember
uniform float ash_drift : hint_range(0.0, 100.0) = 36.0;
uniform vec2 tile_size = vec2(64.0, 84.0);

varying vec2 local_pos;

// High-speed 2D pseudo-random hash
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// 2D Value Noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Voronoi cellular fracture distance for micro-shards
float voronoi(vec2 p) {
    vec2 n = floor(p);
    vec2 f = fract(p);
    float md = 8.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = vec2(hash21(n + g), hash21(n + g + vec2(13.5, 47.1)));
            vec2 r = g + o - f;
            float d = dot(r, r);
            md = min(md, d);
        }
    }
    return sqrt(md);
}

void vertex() {
    local_pos = VERTEX;
    if (dissolve_amount > 0.01) {
        // Vertical upward incense drift of ceramic filaments
        float up_factor = clamp(1.0 - (VERTEX.y / max(tile_size.y, 1.0)) * 0.5, 0.2, 1.2);
        VERTEX.y -= dissolve_amount * ash_drift * up_factor;
    }
}

void fragment() {
    vec4 col = COLOR;
    
    // Discard transparent pixels
    if (col.a <= 0.02) {
        discard;
    }
    
    if (dissolve_amount >= 0.999) {
        discard;
    } else if (dissolve_amount > 0.001) {
        // Compute normalized coordinate (0.0 -> 1.0) using actual tile dimensions
        vec2 norm_uv = clamp(local_pos / max(tile_size, vec2(1.0)), vec2(0.0), vec2(1.0));
        
        // Centered radial distance for outward energetic wave expansion
        vec2 center_delta = (norm_uv - vec2(0.5, 0.5)) * vec2(1.0, tile_size.y / max(tile_size.x, 1.0));
        float dist = length(center_delta);
        
        // Multi-frequency fracture noise: cellular micro-cracks + rising smoke turbulence
        vec2 uv = norm_uv * vec2(14.0, 18.0);
        uv.y -= dissolve_amount * 5.0; // rising heat curl
        
        float n_val = noise(uv * 1.4);
        float v_val = voronoi(uv * 2.0);
        float crack = mix(n_val, v_val, 0.45);
        
        // Energetic wave: center ignites first, pushing outward into fine ceramic filaments
        float wave_progression = dissolve_amount * 1.45;
        float burn_metric = dist * 0.72 + crack * 0.44;
        
        // Dissolve erosion threshold
        if (burn_metric < wave_progression) {
            discard;
        } else if (burn_metric < wave_progression + edge_thickness) {
            // Radiant multi-band molten ember border: White Core -> Molten Gold -> Cinnabar
            float t = (burn_metric - wave_progression) / edge_thickness; // 0.0 (burning edge) -> 1.0 (interior)
            vec4 fire;
            if (t < 0.25) {
                fire = mix(ember_color, edge_color, t / 0.25);
            } else {
                fire = mix(edge_color, burn_color, (t - 0.25) / 0.75);
            }
            // Boost emission brightness for HDR bloom effect
            COLOR = vec4(fire.rgb * 2.5, col.a * (1.0 - t * 0.25));
        } else {
            // Subtle pre-heat fringe warming the ceramic right before it combusts
            float heat_band = burn_metric - (wave_progression + edge_thickness);
            if (heat_band < 0.06) {
                float h = 1.0 - (heat_band / 0.06);
                COLOR = mix(col, edge_color * 1.3, h * 0.3);
            } else {
                COLOR = col;
            }
        }
    } else {
        COLOR = col;
    }
}
