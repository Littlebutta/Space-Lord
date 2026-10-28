shader_type spatial;
// Ship parts: see pbr.gdshaderinc. Preset 7 takes the faction accent.

#include "res://assets/materials/pbr.gdshaderinc"

void fragment() {
	PBR_OUT(accent.rgb)
}
