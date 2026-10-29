shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Engine plume on the system map: a white-hot core fading through the
// faction colour to nothing, with flicker, shock diamonds and noise.

uniform vec3 hot : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 tint : source_color = vec3(1.0, 0.45, 0.15);
uniform float level = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
			mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float v = UV.y;  // 0 at the nozzle, 1 at the tip
	float rim = abs(dot(NORMAL, VIEW));  // bright through the middle
	float n = noise(vec2(UV.x * 8.0, v * 6.0 - TIME * 9.0));
	float flick = 0.85 + 0.15 * sin(TIME * 37.0) * sin(TIME * 23.0);
	float diamonds = 0.75 + 0.25 * sin(v * 28.0 - TIME * 18.0);
	float a = pow(1.0 - v, 1.6) * pow(rim, 1.5) * (0.55 + 0.45 * n) * flick * level;
	vec3 c = mix(hot, tint, smoothstep(0.05, 0.5, v)) * diamonds;
	ALBEDO = c * a * 3.0;
	ALPHA = clamp(a, 0.0, 1.0);
}
