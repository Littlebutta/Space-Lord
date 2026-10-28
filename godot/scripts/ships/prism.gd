class_name Prism
extends RefCounted
## Placeholder part meshes: a module's 2D footprint extruded into a
## flat-shaded prism, so slopes and themed shapes work before real art.


## Footprint polygon in cells (0..turned size) after `turn` quarter turns.
static func footprint(m: ShipModule, turn: int) -> PackedVector2Array:
	var s := Vector2(m.size)
	var p := m.outline.duplicate()
	if p.size() < 3:
		p = PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)])
	for t in turn % 4:  # same rotation as ShipRules.rotate
		for k in p.size():
			p[k] = Vector2(s.y - p[k].y, p[k].x)
		s = Vector2(s.y, s.x)
	return p


## Cuts every corner `f` of the way along its edges (0.25 = Chaikin).
static func cut(p: PackedVector2Array, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		out.append(a.lerp(b, f))
		out.append(a.lerp(b, 1.0 - f))
	return out


## Extrudes polygon `p` (x, z) to height `h`, top shrunk by `taper`.
static func build(p: PackedVector2Array, h: float, taper := 0.0) -> ArrayMesh:
	var mid := Vector2.ZERO
	for v in p:
		mid += v
	mid /= p.size()
	var top := PackedVector2Array()
	for v in p:
		top.append(v.lerp(mid, taper))
	var o := Vector3(mid.x, 0.0, mid.y)
	var y := h * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := Geometry2D.triangulate_polygon(p)
	for k in range(0, tri.size(), 3):
		var a := tri[k]
		var b := tri[k + 1]
		var c := tri[k + 2]
		_face(st, o, _v(top[a], y), _v(top[b], y), _v(top[c], y))
		_face(st, o, _v(p[a], -y), _v(p[b], -y), _v(p[c], -y))
	for i in p.size():
		var j := (i + 1) % p.size()
		var b0 := _v(p[i], -y)
		var t1 := _v(top[j], y)
		_face(st, o, b0, _v(p[j], -y), t1)
		_face(st, o, b0, t1, _v(top[i], y))
	return st.commit()


static func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## Adds a flat triangle facing away from `o`. Godot front faces wind
## clockwise, so the raw cross product must point inward.
static func _face(st: SurfaceTool, o: Vector3, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-8:
		return
	if n.dot((a + b + c) / 3.0 - o) > 0.0:
		var t := b
		b = c
		c = t
	else:
		n = -n
	st.set_normal(n.normalized())
	for v in [a, b, c]:
		st.add_vertex(v)
