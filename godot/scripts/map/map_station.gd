class_name MapStation
extends RefCounted
## A station on the system map: a long docking spine, a spoked habitat
## wheel that turns, solar wings, blinking beacons, and a faint ring
## marking the refit range.


static func make(col: Color) -> Node3D:
	var n := Node3D.new()
	var hull := MapArt.metal()
	var dark := MapArt.metal(Color(0.28, 0.3, 0.33))
	_part(n, _cyl(0.55, 0.55, 6.0), hull, Vector3.ZERO)
	_part(n, _cyl(0.9, 1.1, 1.4), dark, Vector3(0, 2.2, 0))
	_part(n, _cyl(1.1, 0.9, 1.4), dark, Vector3(0, -2.2, 0))
	var wheel := Node3D.new()
	wheel.add_to_group(&"map_spin")
	wheel.set_meta(&"spin", 0.25)
	var rim := TorusMesh.new()
	rim.inner_radius = 2.5
	rim.outer_radius = 3.0
	rim.rings = 48
	_part(wheel, rim, hull, Vector3.ZERO)
	for k in 6:
		var a := k * TAU / 6.0
		var spoke := _part(wheel, _box(Vector3(2.4, 0.15, 0.15)), dark,
				Vector3(cos(a), 0, sin(a)) * 1.5)
		spoke.rotation.y = -a
		_part(wheel, _box(Vector3(0.5, 0.35, 0.4)), _lit(col, 1.5),
				Vector3(cos(a + 0.5), 0.0, sin(a + 0.5)) * 2.75)
	n.add_child(wheel)
	var panel := StandardMaterial3D.new()
	panel.albedo_color = Color(0.08, 0.12, 0.25)
	panel.metallic = 0.8
	panel.roughness = 0.3
	for side in [-1.0, 1.0]:
		_part(n, _box(Vector3(0.1, 0.1, 3.0)), dark, Vector3(0, -1.0, side * 4.0))
		_part(n, _box(Vector3(1.6, 0.04, 2.6)), panel, Vector3(0, -1.0, side * 4.3))
	for y in [3.1, -3.1]:
		_part(n, _ball(0.18), _lit(Color(1, 0.3, 0.2), 6.0), Vector3(0, y, 0))
	n.rotation.x = 0.35
	var range_ := MeshInstance3D.new()
	var r := TorusMesh.new()
	r.inner_radius = Travel.DOCK_RANGE - 0.3
	r.outer_radius = Travel.DOCK_RANGE
	r.material = MapGlow.make(Color(col, 0.25))
	range_.mesh = r
	var out := Node3D.new()
	out.add_child(n)
	out.add_child(range_)
	return out


static func _part(parent: Node3D, m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	return c


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


static func _lit(c: Color, energy: float) -> StandardMaterial3D:
	return MapGlow.make(c, energy, false)
