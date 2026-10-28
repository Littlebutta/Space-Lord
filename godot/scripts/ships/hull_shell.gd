class_name HullShell
extends RefCounted
## The outside view's hull: every part's footprint merged into one
## outline and raised into a single shell with a chamfered top edge
## painted in the faction accent, so neighbouring parts read as one
## continuous hull. Part models add their exterior detail on top.

const HEIGHT := 2.4  # shell top above the deck (art/tools ROOF)
const BEVEL := 0.6  # chamfer width and drop along the top edge
const PAINT := Vector2(0.5 / 8.0, 0.0)  # UV: painted metal preset
const STRIPE := Vector2(7.5 / 8.0, 1.0)  # UV: accent preset, worn edge


## Shell over modules `mods` of `d` (all when empty), deck top at y0.
static func build(d: ShipDesign, y0: float, mods: Array = []) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for p in outlines(d, mods):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_shell(st, p, y0)
		st.commit(mesh)
	return mesh


## Merged outer outlines of the ship in metres (x, z).
static func outlines(d: ShipDesign, mods: Array = []) -> Array[PackedVector2Array]:
	var polys: Array[PackedVector2Array] = []
	for i in (mods if not mods.is_empty() else range(d.modules.size())):
		var p := Prism.footprint(d.modules[i], d.turns[i])
		var at := Vector2(d.rect(i).position)
		for k in p.size():
			p[k] = (p[k] + at) * ShipView.CELL
		polys.append(Geometry2D.offset_polygon(p, 0.02, Geometry2D.JOIN_MITER)[0])
	var merged := true
	while merged:
		merged = false
		for a in polys.size():
			for b in range(a + 1, polys.size()):
				var outer := Geometry2D.merge_polygons(polys[a], polys[b]).filter(
						func(q): return not Geometry2D.is_polygon_clockwise(q))
				if outer.size() == 1:  # touching: one outline (holes dropped)
					polys[a] = outer[0]
					polys.remove_at(b)
					merged = true
					break
			if merged:
				break
	for k in polys.size():
		polys[k] = _simplify(polys[k])
	return polys


static func _shell(st: SurfaceTool, p: PackedVector2Array, y0: float) -> void:
	var top := y0 + HEIGHT
	var q := _inset(p, BEVEL)
	var bevel := not Geometry2D.triangulate_polygon(q).is_empty()
	if not bevel:
		q = p
	var wall := top - BEVEL if bevel else top
	for i in p.size():
		var j := (i + 1) % p.size()
		var out := _outward(p, i, j)
		_quad(st, _v(p[i], y0), _v(p[j], y0), _v(p[j], wall), _v(p[i], wall), out, PAINT)
		if bevel:
			var n := (out + Vector3.UP).normalized()
			_quad(st, _v(p[i], wall), _v(p[j], wall), _v(q[j], top), _v(q[i], top), n, STRIPE)
	var tri := Geometry2D.triangulate_polygon(q)
	for k in range(0, tri.size(), 3):
		_tri(st, _v(q[tri[k]], top), _v(q[tri[k + 1]], top), _v(q[tri[k + 2]], top),
				Vector3.UP, PAINT)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		n: Vector3, uv: Vector2) -> void:
	_tri(st, a, b, c, n, uv)
	_tri(st, a, c, d, n, uv)


## Flat triangle facing `n`. Godot front faces wind clockwise.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		n: Vector3, uv: Vector2) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	st.set_normal(n)
	st.set_uv(uv)
	for v in [a, b, c]:
		st.add_vertex(v)


## Each corner of `p` moved `d` inward along its mitre (capped at 2d
## so sharp noses don't spike), keeping one point per corner.
static func _inset(p: PackedVector2Array, d: float) -> PackedVector2Array:
	var q := PackedVector2Array()
	for i in p.size():
		var a := _outward(p, i - 1 if i > 0 else p.size() - 1, i)
		var b := _outward(p, i, (i + 1) % p.size())
		var m := Vector2(a.x + b.x, a.z + b.z)
		var s := d / maxf(m.length() * 0.5, 0.5) / maxf(m.length(), 0.001)
		q.append(p[i] - m * s)
	return q


## Horizontal normal of edge i-j pointing out of polygon p.
static func _outward(p: PackedVector2Array, i: int, j: int) -> Vector3:
	var e := (p[j] - p[i]).normalized()
	var o := Vector2(e.y, -e.x)
	if Geometry2D.is_point_in_polygon((p[i] + p[j]) * 0.5 + o * 0.01, p):
		o = -o
	return Vector3(o.x, 0.0, o.y)


static func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## Drops points that sit on a straight line between their neighbours.
static func _simplify(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in p.size():
		var a := p[i - 1]
		var b := p[i]
		var c := p[(i + 1) % p.size()]
		if absf((b - a).cross(c - b)) > 1e-4 * (b - a).length() * (c - b).length() + 1e-6:
			out.append(b)
	return out
