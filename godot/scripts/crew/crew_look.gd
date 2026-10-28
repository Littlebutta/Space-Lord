class_name CrewLook
extends RefCounted
## Draws a whole crew as one toon-shaded MultiMesh, coloured by job.


static func multimesh() -> MultiMesh:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.9
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	return mm


static func draw(mm: MultiMesh, crew: Array[CrewMember], nav: ShipNav,
		delta: float) -> void:
	if mm.instance_count != crew.size():
		mm.instance_count = crew.size()
	for k in crew.size():
		var c := crew[k]
		c.y = lerpf(c.y, nav.height(c.pos), minf(delta * 10.0, 1.0))
		var t := Transform3D(Basis(), Vector3(c.pos.x, c.y + 0.45, c.pos.y))
		mm.set_instance_transform(k, t)
		var col: Color = CrewJob.COLORS[c.job.type if c.job else &""]
		mm.set_instance_color(k, col.lightened(0.4) if c.cargo > 0.0 else col)
