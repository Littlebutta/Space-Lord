shader_type spatial;
// Bio thruster tentacles: writhe slowly at rest and lash hard while the
// engine pushes (`thrust`, set per engine by ShipFx). Movement grows
// along the tentacle (object z past the root), so the base stays put.

instance uniform float thrust = 0.0;

void vertex() {
	float along = max(VERTEX.z - 1.6, 0.0) / 3.2;
	float speed = mix(1.2, 7.0, thrust);
	float amp = mix(0.12, 0.45, thrust) * along * along;
	float ph = TIME * speed - VERTEX.z * 1.7 + VERTEX.x * 3.0;
	VERTEX.x += sin(ph) * amp;
	VERTEX.y += cos(ph * 0.8) * amp * 0.7;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.4;
	SSS_STRENGTH = 0.35;
}
