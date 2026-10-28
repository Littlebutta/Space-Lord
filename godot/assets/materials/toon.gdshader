shader_type spatial;
// Wind Waker style cel shading: one hard light/shadow step, cool tinted
// shadows and a thin rim light. Cheap enough for big fleets.

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shade : source_color = vec4(0.5, 0.55, 0.85, 1.0);
uniform float cut : hint_range(0.0, 1.0) = 0.3;
uniform float rim : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = smoothstep(cut - 0.02, cut + 0.02, ndl);
	vec3 band = mix(shade.rgb * 0.45, vec3(1.0), lit);
	float edge = smoothstep(0.6, 0.64, 1.0 - dot(NORMAL, VIEW)) * lit;
	DIFFUSE_LIGHT += (band + edge * rim) * LIGHT_COLOR / PI;
}
