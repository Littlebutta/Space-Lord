class_name FactionDressing
extends RefCounted
## Dense surface dressing for the faction hulls, scattered over one
## faction's region with MultiMeshes so hundreds of pieces cost a few
## draw calls: Bio tumours, spines and feeler stalks; big glowing
## Crystal spires and shard beds; Scrap pipes, crates and junk. Placed
## at the hull's height (y0 + top), sunk in a little so they grow out.

const PER_M2 := {  # pieces per square metre of region, by kind
	&"blob": 0.35, &"spine": 0.25, &"stalk": 0.08,
	&"spire": 0.12, &"shard": 0.6,
	&"pipe": 0.15, &"junk": 0.25,
}


static func dress(style: StringName, region: PackedVector2Array,
		ship: Array[PackedVector2Array], y0: float, seed: int) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var kinds: Array = {&"flesh": [&"blob", &"spine", &"stalk"],
			&"facets": [&"spire", &"shard"], &"plates": [&"pipe", &"junk"]}.get(style, [])
	var area := absf(_area(region))
	for kind in kinds:
		var xfs: Array[Transform3D] = []
		for k in int(area * PER_M2[kind]):
			var p := _inside(region, rng)
			var e := FactionShell._edge(p, ship)
			if e < 0.6:  # keep off the very edge, where the hull rolls down
				continue
			xfs.append(_place(kind, Vector3(p.x, y0 + _top(style) * sqrt(clampf(e / 1.8, 0, 1)), p.y), rng))
		if not xfs.is_empty():
			root.add_child(_multi(_mesh(kind), _material(kind), xfs, rng))
	return root


static func _top(style: StringName) -> float:
	return {&"flesh": FactionShell.FLESH_H, &"facets": FactionShell.FACET_H}.get(style, HullShell.HEIGHT)


static func _place(kind: StringName, at: Vector3, rng: RandomNumberGenerator) -> Transform3D:
	var tilt: float = {&"spire": 0.45, &"shard": 0.7, &"spine": 0.6, &"stalk": 0.4}.get(kind, 0.15)
	var b := Basis.from_euler(Vector3(rng.randf_range(-tilt, tilt), rng.randf() * TAU,
			rng.randf_range(-tilt, tilt)))
	var s: Vector3
	match kind:
		&"blob": s = Vector3(1, rng.randf_range(0.4, 0.8), 1) * rng.randf_range(0.25, 0.8)
		&"spine": s = Vector3(1, rng.randf_range(0.8, 2.0), 1) * rng.randf_range(0.6, 1.2)
		&"stalk": s = Vector3(1, rng.randf_range(1.0, 2.2), 1) * rng.randf_range(0.7, 1.1)
		&"spire": s = Vector3(1, rng.randf_range(1.0, 2.4), 1) * rng.randf_range(0.8, 1.6)
		&"shard": s = Vector3(1, rng.randf_range(0.6, 1.5), 1) * rng.randf_range(0.4, 0.9)
		_: s = Vector3.ONE * rng.randf_range(0.6, 1.3)
	return Transform3D(b.scaled(s), at - Vector3.UP * 0.15)


## The base mesh for a kind, standing on its base at the origin.
static func _mesh(kind: StringName) -> Mesh:
	var m: PrimitiveMesh
	match kind:
		&"blob":
			m = SphereMesh.new()
			(m as SphereMesh).radial_segments = 24
			(m as SphereMesh).rings = 12
		&"spine", &"stalk", &"spire", &"shard":
			var c := CylinderMesh.new()
			c.top_radius = 0.0 if kind != &"stalk" else 0.04
			c.bottom_radius = {&"spine": 0.08, &"stalk": 0.06, &"spire": 0.35, &"shard": 0.15}[kind]
			c.height = {&"spine": 0.9, &"stalk": 1.2, &"spire": 2.4, &"shard": 0.9}[kind]
			c.radial_segments = 6 if kind in [&"spire", &"shard"] else 10
			c.rings = 1 if kind in [&"spire", &"shard"] else 4
			m = c
		&"pipe":
			var c := CylinderMesh.new()
			c.top_radius = 0.08
			c.bottom_radius = 0.08
			c.height = 1.8
			m = c
		_:
			m = BoxMesh.new()
			(m as BoxMesh).size = Vector3(0.6, 0.35, 0.45)
	var st := SurfaceTool.new()  # lift so the base sits on the origin
	st.append_from(m, 0, Transform3D(Basis(), Vector3.UP * (m.get_aabb().size.y * 0.5)))
	if kind in [&"spire", &"shard"]:
		st.deindex()
		st.generate_normals()  # flat facets
	return st.commit()


static func _material(kind: StringName) -> Material:
	match kind:
		&"spire", &"shard":
			var m := ModelSkin.faction_material(&"facets").duplicate() as ShaderMaterial
			m.set_shader_parameter(&"glow_boost", 2.2 if kind == &"spire" else 1.2)
			return m
		&"blob", &"stalk":
			return ModelSkin.faction_material(&"flesh")
		&"spine":
			var b := StandardMaterial3D.new()
			b.albedo_color = Color(0.85, 0.8, 0.68)
			b.roughness = 0.6
			return b
	return ModelSkin.shell_material(ShipTheme.by_id(&"scrap"))


static func _multi(mesh: Mesh, mat: Material, xfs: Array[Transform3D],
		rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
		mm.set_instance_color(k, Color(1, 1, 1).darkened(rng.randf() * 0.3))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	return mi


static func _inside(poly: PackedVector2Array, rng: RandomNumberGenerator) -> Vector2:
	var box := Rect2(poly[0], Vector2.ZERO)
	for v in poly:
		box = box.expand(v)
	for t in 30:
		var p := box.position + Vector2(rng.randf(), rng.randf()) * box.size
		if Geometry2D.is_point_in_polygon(p, poly):
			return p
	return box.get_center()


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5
