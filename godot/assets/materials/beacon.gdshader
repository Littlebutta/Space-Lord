shader_type spatial;
render_mode unshaded;
// Hull running light: a dim glow with a bright blink every couple of
// seconds, each light offset in time by where it sits on the ship.

uniform vec4 colour : source_color = vec4(1.0);

void fragment() {
	vec3 p = MODEL_MATRIX[3].xyz;
	float phase = fract(TIME * 0.5 + p.x * 0.11 + p.z * 0.07);
	ALBEDO = colour.rgb * (0.35 + 2.5 * step(0.88, phase));
}
