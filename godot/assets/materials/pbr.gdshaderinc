// Gritty PBR for Blender parts, shared by every model so they batch.
// Vertex colour is the base colour, UV.x picks a material preset (see
// PRESET) and UV.y flags bevel faces, where paint chips to bare metal.
// Grime, scratches, plate seams and fine bumps come from two small
// tiling noise textures projected in object space: no UV unwrap and no
// per-part textures, so big fleets stay cheap.

uniform sampler2D grime_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D bump_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);  // whole-material multiplier
uniform vec4 accent : source_color = vec4(0.25, 0.45, 0.8, 1.0);  // faction
uniform float grime : hint_range(0.0, 1.0) = 0.7;
uniform float wear : hint_range(0.0, 1.0) = 0.55;
uniform float bump : hint_range(0.0, 2.0) = 0.35;
uniform float seams = 0.0;  // plate seams every metre, 0 = off

varying vec3 obj_pos;
varying vec3 obj_nrm;

// roughness, metallic, bump, grime per preset: 0 paint, 1 bare metal,
// 2 rubber, 3 crate plastic, 4 fabric, 5 glass, 6 skin, 7 accent paint
const vec4 PRESET[8] = vec4[8](
	vec4(0.55, 0.25, 1.0, 1.0), vec4(0.32, 1.0, 0.6, 0.6),
	vec4(0.85, 0.0, 0.4, 0.8), vec4(0.6, 0.0, 0.8, 1.0),
	vec4(0.95, 0.0, 1.4, 0.5), vec4(0.06, 0.1, 0.0, 0.2),
	vec4(0.6, 0.0, 0.2, 0.0), vec4(0.5, 0.25, 1.0, 1.0));

void vertex() {
	obj_pos = VERTEX;
	obj_nrm = NORMAL;
}

vec4 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy) * w.x + texture(t, p.xz) * w.y + texture(t, p.xy) * w.z;
}

// Triplanar normal-map bump as an object-space offset to the normal.
vec3 tri_bump(vec3 p, vec3 w) {
	vec2 a = texture(bump_tex, p.zy).xy * 2.0 - 1.0;
	vec2 b = texture(bump_tex, p.xz).xy * 2.0 - 1.0;
	vec2 c = texture(bump_tex, p.xy).xy * 2.0 - 1.0;
	return vec3(0.0, a.y, a.x) * w.x + vec3(b.x, 0.0, b.y) * w.y + vec3(c, 0.0) * w.z;
}

// Surface for preset id: fills albedo, metal, roughness, ao and an
// object-space normal n; see PBR_OUT for writing them.
void pbr(int id, vec3 base, vec2 uv, out vec3 alb, out float metal,
		out float rough, out float ao, out vec3 n) {
	vec4 pr = PRESET[id];
	vec3 w = pow(abs(obj_nrm), vec3(4.0));
	w /= dot(w, vec3(1.0));
	vec3 p = obj_pos * 0.35;
	float blot = tri(grime_tex, p, w).r;
	float fine = tri(grime_tex, p * 6.1 + 0.37, w).r;
	bool painted = id == 0 || id == 7;
	float chip = painted ? uv.y * smoothstep(0.55, 0.75, fine + wear * 0.3) : 0.0;
	base = mix(base, vec3(0.42, 0.42, 0.44), chip);
	float low = clamp(0.5 - obj_pos.y, 0.0, 1.0) * 0.35;
	float dirt = (smoothstep(0.4, 0.9, blot) * 0.7 + low) * grime * pr.w;
	float seam = 0.0;
	if (seams > 0.0) {
		vec3 f = abs(fract(obj_pos * seams + 0.5) - 0.5);
		vec3 lines = step(f, vec3(0.012 * seams));
		seam = max(max(lines.x * (1.0 - w.x), lines.y * (1.0 - w.y)), lines.z * (1.0 - w.z));
	}
	alb = mix(base, base * vec3(0.45, 0.41, 0.36), max(dirt, seam * 0.8)) * tint.rgb;
	metal = mix(pr.y, 1.0, chip);
	rough = clamp(pr.x + dirt * 0.35 + (fine - 0.5) * 0.3 - chip * 0.25, 0.04, 1.0);
	n = normalize(obj_nrm + tri_bump(p * 3.0, w) * bump * pr.z);
	ao = 1.0 - seam * 0.6;
}

// Writes pbr()'s result in fragment(); id from UV.x, base colour given.
#define PBR_OUT(base) { \
	int id = clamp(int(UV.x * 8.0), 0, 7); \
	vec3 n; \
	pbr(id, id == 7 ? (base) : COLOR.rgb, UV, ALBEDO, METALLIC, ROUGHNESS, AO, n); \
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(n, 0.0))).xyz); \
}
