shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Flat glowing discs for the map, drawn on a plane mesh: mode 0 is a
// planet's ring (dusty bands), mode 1 a jump point's swirling vortex,
// mode 2 a star's soft halo.

uniform vec3 col : source_color = vec3(0.7, 0.5, 1.0);
uniform int mode = 0;
uniform float inner = 0.55;  // ring: inner edge, as a share of the radius
uniform float gain = 1.0;

uniform bool billboard = false;  // a quad that always faces the camera

float hash(float x) { return fract(sin(x * 127.1) * 43758.5453); }

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
				INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	float a = 0.0;
	if (mode == 0) {
		float band = hash(floor(d * 40.0)) * 0.6 + 0.4;
		a = smoothstep(inner, inner + 0.03, d) * smoothstep(1.0, 0.96, d) * band * 0.55;
	} else if (mode == 1) {
		float ang = atan(q.y, q.x);
		float swirl = sin(ang * 3.0 + d * 12.0 - TIME * 2.0) * 0.5 + 0.5;
		a = (swirl * 0.7 + 0.3) * smoothstep(1.0, 0.6, d) * (0.4 + 0.6 * d);
	} else {
		a = pow(max(1.0 - d, 0.0), 2.5);
	}
	ALBEDO = col * a * gain;
}
