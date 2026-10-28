shader_type spatial;
// Crew: the same gritty PBR as ship parts, with the shirt (preset 7)
// painted per crew member by job through an instance uniform.

#include "res://assets/materials/pbr.gdshaderinc"

instance uniform vec4 shirt : source_color = vec4(0.8);

void fragment() {
	PBR_OUT(shirt.rgb)
}
