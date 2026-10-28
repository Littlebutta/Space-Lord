shader_type spatial;
// Crystal hull: hard faceted crystal, each facet a little different in
// tone, glowing faintly from inside and brighter at grazing angles.

uniform vec4 base : source_color = vec4(0.42, 0.46, 0.82, 1.0);
uniform vec4 inner : source_color = vec4(0.55, 0.4, 1.0, 1.0);

void fragment() {
	ALBEDO = base.rgb * COLOR.rgb;
	METALLIC = 0.25;
	ROUGHNESS = 0.18;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = inner.rgb * (0.08 + rim * 0.6) * COLOR.r;
}
