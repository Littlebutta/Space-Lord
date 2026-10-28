shader_type sky;
// Placeholder deep-space backdrop: faint stars in three sizes, a dim
// milky band and a hint of nebula. Kept dark so ships stay readable.

uniform vec3 base_col : source_color = vec3(0.008, 0.01, 0.022);
uniform vec3 band_col : source_color = vec3(0.07, 0.07, 0.11);
uniform vec3 nebula_col : source_color = vec3(0.09, 0.04, 0.10);
uniform float star_gain = 1.4;

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = 0.0;
	for (int k = 0; k < 8; k++) {
		vec3 o = vec3(float(k & 1), float((k >> 1) & 1), float((k >> 2) & 1));
		vec3 w = mix(1.0 - f, f, o);
		n += hash(i + o) * w.x * w.y * w.z;
	}
	return n;
}

float stars(vec3 dir, float cells, float keep) {
	vec3 p = dir * cells;
	vec3 c = floor(p);
	float h = hash(c);
	if (h < keep) return 0.0;
	vec3 at = c + 0.5 + (vec3(hash(c + 1.3), hash(c + 2.7), hash(c + 4.1)) - 0.5) * 0.6;
	float d = length(p - at);
	return smoothstep(0.35, 0.0, d) * (h - keep) / (1.0 - keep);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float band = exp(-pow(dot(d, normalize(vec3(0.3, 0.25, 1.0))) * 3.2, 2.0));
	float cloud = noise(d * 3.0) * 0.6 + noise(d * 7.0) * 0.4;
	vec3 col = base_col + band_col * band * (0.5 + cloud);
	col += nebula_col * smoothstep(0.55, 0.9, noise(d * 2.0 + 7.0)) * 0.8;
	float s = stars(d, 180.0, 0.985) + stars(d, 90.0, 0.993) * 1.5 + stars(d, 40.0, 0.997) * 2.5;
	vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.75), hash(floor(d * 180.0)));
	COLOR = col + tint * s * star_gain;
}
