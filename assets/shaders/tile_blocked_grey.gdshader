shader_type canvas_item;
render_mode unshaded;

// A tile that cannot be taken, drawn grey and dull.
//
// The dark themes had no working "blocked" look: the light themes darken a
// blocked tile, and darkening a black tile leaves a black tile. Desaturating
// and pulling toward a mid grey lifts it instead, so an unavailable black tile
// reads as switched off rather than as a slightly different black tile.
//
// Unshaded on purpose: a blocked tile catching the key light is the opposite
// of dull.

uniform float desaturate : hint_range(0.0, 1.0) = 0.9;
uniform float dull : hint_range(0.0, 1.0) = 0.5;
uniform vec3 grey : source_color = vec3(0.30, 0.31, 0.33);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(c.rgb, vec3(l), desaturate);
	COLOR = vec4(mix(g, grey, dull), c.a);
}
