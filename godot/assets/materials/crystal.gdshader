shader_type spatial;
// Crystal hull and spires: hard faceted crystal, each facet its own
// tone, lit from inside with a slow pulse that runs up through it and
// a bright rim at grazing angles. `glow_boost` makes spires blaze.

uniform sampler2D detail : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 base : source_color = vec4(0.36, 0.38, 0.85, 1.0);
uniform vec4 inner : source_color = vec4(0.62, 0.35, 1.0, 1.0);
uniform vec4 hot : source_color = vec4(0.4, 0.9, 1.0, 1.0);
uniform float glow_boost = 0.6;

varying vec3 obj;

void vertex() {
	obj = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float band = 0.5 + 0.5 * sin(obj.y * 2.5 - TIME * 1.6 + obj.x * 0.3);
	vec3 glow = mix(inner.rgb, hot.rgb, band);
	ALBEDO = base.rgb * COLOR.rgb;
	METALLIC = 0.2;
	ROUGHNESS = 0.12;
	NORMAL_MAP = texture(detail, obj.xz * 0.2 + obj.y * 0.1).rgb;
	NORMAL_MAP_DEPTH = 0.4;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow * (0.12 + band * 0.25 + rim * 0.8) * glow_boost * COLOR.r;
}
