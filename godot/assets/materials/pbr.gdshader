shader_type spatial;
// Ship parts: see pbr.gdshaderinc. Preset 7 takes the faction accent.
// The hull shell can have holes: over glass parts (`holes`, kept just
// inside so edge walls stay) and over other factions' parts (`cuts`,
// whose own hulls fill them). Rects in x/z; see ModelSkin.cut_shell.

#include "res://assets/materials/pbr.gdshaderinc"

uniform vec4 holes[48];
uniform int hole_count = 0;
uniform vec4 cuts[48];
uniform int cut_count = 0;

bool inside(vec4 r, float m) {
	return obj_pos.x > r.x + m && obj_pos.x < r.z - m && obj_pos.z > r.y + m && obj_pos.z < r.w - m;
}

void fragment() {
	for (int k = 0; k < hole_count; k++) {
		if (inside(holes[k], 0.03) && obj_pos.y > 0.3) {
			discard;
		}
	}
	for (int k = 0; k < cut_count; k++) {
		if (inside(cuts[k], -0.05)) {  // takes its edge walls too
			discard;
		}
	}
	PBR_OUT(accent.rgb)
}
