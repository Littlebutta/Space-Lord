shader_type spatial;
// Procedural planet surface: rocky worlds get continents, seas and ice
// caps from layered noise; gas giants get swirling bands. A thin
// atmosphere glows at the rim. All in object space, so it turns with it.

uniform vec3 col_low : source_color = vec3(0.1, 0.2, 0.4);
uniform vec3 col_mid : source_color = vec3(0.3, 0.4, 0.2);
uniform vec3 col_high : source_color = vec3(0.6, 0.55, 0.45);
uniform vec3 atmo : source_color = vec3(0.4, 0.6, 1.0);
uniform float gas = 0.0;
uniform float ice = 0.0;
uniform float sea = 0.45;
uniform float seed = 0.0;
uniform float atmo_gain = 0.5;

varying vec3 obj;

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

float fbm(vec3 p) {
	float n = 0.0;
	float a = 0.5;
	for (int k = 0; k < 6; k++) {
		n += noise(p) * a;
		p = p * 2.03 + 1.7;
		a *= 0.5;
	}
	return n;
}

void vertex() {
	obj = VERTEX;
}

void fragment() {
	vec3 p = normalize(obj) + seed;
	vec3 c;
	float rough = 0.9;
	if (gas > 0.5) {
		float warp = fbm(p * 3.0) * 3.0;
		float b = sin((p.y - seed) * 22.0 + warp) * 0.5 + 0.5;
		c = mix(mix(col_low, col_mid, b), col_high, smoothstep(0.6, 0.9, fbm(p * 6.0 + warp)));
	} else {
		float n = fbm(p * 2.2);
		float lat = abs(normalize(obj).y);
		if (n < sea) {
			c = mix(col_low * 0.5, col_low, n / sea);
			rough = 0.35;
		} else {
			c = mix(col_mid, col_high, smoothstep(sea + 0.05, sea + 0.3, n));
			c *= 0.8 + 0.4 * noise(p * 40.0);
		}
		c = mix(c, vec3(0.92, 0.95, 1.0), smoothstep(0.78, 0.86, lat + n * 0.15) * ice);
		float cloud = smoothstep(0.55, 0.75, fbm(p * 4.0 + vec3(TIME * 0.004, 0.0, 0.0)));
		c = mix(c, vec3(0.95), cloud * 0.6 * atmo_gain);
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = atmo * rim * atmo_gain;
}
