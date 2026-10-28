shader_type spatial;
// Ship parts: see pbr.gdshaderinc. Preset 7 takes the faction accent.
// The hull shell can have holes over glass parts (rects in x/z, set by
// ModelSkin.cut_shell) so the crew inside show through.

#include "res://assets/materials/pbr.gdshaderinc"

uniform vec4 holes[8];
uniform int hole_count = 0;

void fragment() {
	for (int k = 0; k < hole_count; k++) {
		vec4 h = holes[k];
		if (obj_pos.x > h.x + 0.03 && obj_pos.x < h.z - 0.03 && obj_pos.z > h.y + 0.03
				&& obj_pos.z < h.w - 0.03 && obj_pos.y > 0.3) {
			discard;
		}
	}
	PBR_OUT(accent.rgb)
}
