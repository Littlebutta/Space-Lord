shader_type spatial;
// Asteroid rock: colour from AsteroidArt's vertex colours; alpha marks
// metal veins, which get a dull metallic sheen. Kept rough on purpose.

uniform sampler2D bump_tex : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	METALLIC = COLOR.a * 0.6;
	ROUGHNESS = mix(0.95, 0.45, COLOR.a);
	vec3 b = texture(bump_tex, obj_pos.xz * 0.15).rgb * 0.5 + texture(bump_tex, obj_pos.xy * 0.15).rgb * 0.5;
	NORMAL_MAP = b;
	NORMAL_MAP_DEPTH = 0.6;
}
