class_name Prism
extends RefCounted
## Placeholder part meshes: 2D footprints extruded into flat-shaded
## prisms, so slopes and themed shapes work before real art.


## Footprint polygon in cells (0..turned size) after `turn` quarter turns.
static func footprint(m: ShipModule, turn: int) -> PackedVector2Array:
	var s := Vector2(m.size)
	var p := m.outline.duplicate()
	if p.size() < 3:
		p = PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)])
	p = turned(p, s, turn)
	if turn >= 4:  # mirrored: keep the outline's winding
		p.reverse()
	return p


## Points in cell units of an unturned `s` footprint after `turn`
## quarter turns, the same rotation as ShipRules.rotate. Turns 4-7 are
## mirrored (x flipped) first; see ShipDesign.mirror.
static func turned(p: PackedVector2Array, s: Vector2, turn: int) -> PackedVector2Array:
	p = p.duplicate()
	if turn >= 4:
		for k in p.size():
			p[k].x = s.x - p[k].x
	for t in turn % 4:
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


## Rounds the corners of footprint `p` (placed at `r`) that stick out
## of the ship: grid points no other part's cell touches. Inner joins
## stay square so neighbouring parts sit flush. `steps` 1 = chamfer.
static func round_corners(p: PackedVector2Array, r: Rect2i, filled: Dictionary,
		radius: float, steps: int) -> PackedVector2Array:
	if radius <= 0.0:
		return p
	var out := PackedVector2Array()
	for i in p.size():
		var v := p[i]
		if not _exposed(v + Vector2(r.position), r, filled):
			out.append(v)
			continue
		var a := v.move_toward(p[i - 1], radius)
		var b := v.move_toward(p[(i + 1) % p.size()], radius)
		for k in steps + 1:
			var s := float(k) / maxi(steps, 1)
			out.append(a.lerp(v, s).lerp(v.lerp(b, s), s))
	return out


static func _exposed(g: Vector2, r: Rect2i, filled: Dictionary) -> bool:
	if not g.is_equal_approx(g.round()):
		return false
	var c := Vector2i(g.round())
	for o in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
		if filled.has(c + o) and not r.has_point(c + o):
			return false
	return true


## Moves every point `f` of the way toward the centre.
static func shrink(p: PackedVector2Array, f: float) -> PackedVector2Array:
	var mid := _mid(p)
	var out := PackedVector2Array()
	for v in p:
		out.append(v.lerp(mid, f))
	return out


static func _mid(p: PackedVector2Array) -> Vector2:
	var mid := Vector2.ZERO
	for v in p:
		mid += v
	return mid / p.size()


## Extrudes polygon `p` (x, z) from y0 to y1, top shrunk by `taper`.
static func add(st: SurfaceTool, p: PackedVector2Array, y0: float, y1: float,
		taper := 0.0) -> void:
	var top := shrink(p, taper)
	var mid := _mid(p)
	var o := Vector3(mid.x, (y0 + y1) * 0.5, mid.y)
	var tri := Geometry2D.triangulate_polygon(p)
	for k in range(0, tri.size(), 3):
		var a := tri[k]
		var b := tri[k + 1]
		var c := tri[k + 2]
		_face(st, o, _v(top[a], y1), _v(top[b], y1), _v(top[c], y1))
		_face(st, o, _v(p[a], y0), _v(p[b], y0), _v(p[c], y0))
	for i in p.size():
		var j := (i + 1) % p.size()
		var b0 := _v(p[i], y0)
		var t1 := _v(top[j], y1)
		_face(st, o, b0, _v(p[j], y0), t1)
		_face(st, o, b0, t1, _v(top[i], y1))


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
