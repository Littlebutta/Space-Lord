shader_type spatial;
render_mode unshaded;
// Screens, lamps and exhaust on Blender models: vertex colour, unlit,
// pushed past 1.0 so the scene's glow picks it up.

uniform float boost = 1.8;

void fragment() {
	ALBEDO = COLOR.rgb * boost;
}
