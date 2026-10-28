shader_type spatial;
// Builder hologram: see-through tint, bright rim and drifting scanlines.
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4 tint : source_color = vec4(0.3, 1.0, 0.6, 1.0);

void fragment() {
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	float scan = 0.75 + 0.25 * sin(FRAGCOORD.y * 0.6 - TIME * 6.0);
	ALBEDO = tint.rgb * (0.25 + rim * 0.9) * scan;
}
