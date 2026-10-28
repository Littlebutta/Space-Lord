shader_type spatial;
// Bio hull: wet living flesh with dark veins that pulse faintly. The
// vein pattern is the shared grime noise, read in object space.

uniform sampler2D veins : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 skin : source_color = vec4(0.55, 0.22, 0.24, 1.0);
uniform vec4 vein : source_color = vec4(0.25, 0.05, 0.2, 1.0);
uniform vec4 glow : source_color = vec4(0.9, 0.25, 0.3, 1.0);

varying vec3 obj;

void vertex() {
	obj = VERTEX;
	VERTEX += NORMAL * sin(TIME * 1.3 + VERTEX.x * 0.7 + VERTEX.z * 0.5) * 0.05 * COLOR.a;  // breathing, still at seams
}

void fragment() {
	float v = texture(veins, obj.xz * 0.18).r;
	float line = 1.0 - smoothstep(0.02, 0.07, abs(v - 0.5));
	ALBEDO = mix(skin.rgb * COLOR.rgb, vein.rgb, line * 0.8);
	ROUGHNESS = 0.42;
	METALLIC = 0.0;
	SSS_STRENGTH = 0.4;
	EMISSION = glow.rgb * line * (0.25 + 0.2 * sin(TIME * 2.0 + obj.x));
}
