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
		if d.modules[i].exterior:
			continue
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
	var wall := top - BEVEL
	for i in p.size():
		var j := (i + 1) % p.size()
		_quad(st, _v(p[i], y0), _v(p[j], y0), _v(p[j], wall), _v(p[i], wall),
				_outward(p, i, j), PAINT)
	_fill(st, p, wall)  # only shows where a chamfer can't reach a corner
	for q in Geometry2D.offset_polygon(p, -BEVEL, Geometry2D.JOIN_MITER):
		if not Geometry2D.is_polygon_clockwise(q):
			_fill(st, q, top)
			_chamfer(st, q, top, wall)


## Slanted accent strip from each edge of the top `q` down and out to
## the wall top, with a corner facet at every convex corner.
static func _chamfer(st: SurfaceTool, q: PackedVector2Array, top: float, wall: float) -> void:
	var area := 0.0
	for i in q.size():
		area += q[i].cross(q[(i + 1) % q.size()])
	for i in q.size():
		var j := (i + 1) % q.size()
		var k := (j + 1) % q.size()
		var o := _outward(q, i, j)
		var d := Vector2(o.x, o.z) * BEVEL
		var n := (o + Vector3.UP).normalized()
		_quad(st, _v(q[i], top), _v(q[j], top), _v(q[j] + d, wall), _v(q[i] + d, wall), n, STRIPE)
		var o2 := _outward(q, j, k)
		if (q[j] - q[i]).cross(q[k] - q[j]) * area > 0.0:  # convex corner
			var d2 := Vector2(o2.x, o2.z) * BEVEL
			var m := (o + o2 + Vector3.UP).normalized()
			_tri(st, _v(q[j], top), _v(q[j] + d, wall), _v(q[j] + d2, wall), m, STRIPE)


## Flat upward face over polygon `p` at height y.
static func _fill(st: SurfaceTool, p: PackedVector2Array, y: float) -> void:
	var tri := Geometry2D.triangulate_polygon(p)
	for k in range(0, tri.size(), 3):
		_tri(st, _v(p[tri[k]], y), _v(p[tri[k + 1]], y), _v(p[tri[k + 2]], y),
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


## Footprints (ship metres) of glass parts among `mods` (all when empty):
## the shell leaves these open; see ShipTheme.glass_parts.
static func holes(d: ShipDesign, mods: Array = []) -> Array:
	var out := []
	for i in (mods if not mods.is_empty() else range(d.modules.size())):
		var t := d.theme(i)
		if t.glass_parts.has(d.modules[i].id) and t.model(d.modules[i]):
			var r := d.rect(i)
			out.append(Rect2(Vector2(r.position) * ShipView.CELL, Vector2(r.size) * ShipView.CELL))
	return out


## Running lights on the hull's outer corners: red to port, green to
## starboard, white fore and aft, blinking (see beacon.gdshader).
static func beacons(d: ShipDesign, y0: float, mods: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = &"Beacons"
	var y := y0 + HEIGHT - BEVEL + 0.06
	for p in outlines(d, mods):
		var box := Rect2(p[0], Vector2.ZERO)
		for v in p:
			box = box.expand(v)
		var step := maxi(p.size() / 10, 1)  # about ten lights per hull
		for k in range(0, p.size(), step):
			var v := p[k]
			var col := Color(1, 0.92, 0.8)
			if v.x < box.get_center().x - box.size.x * 0.25:
				col = Color(1, 0.15, 0.1)
			elif v.x > box.get_center().x + box.size.x * 0.25:
				col = Color(0.15, 1, 0.3)
			root.add_child(_beacon(Vector3(v.x, y, v.y), col))
	return root


static func _beacon(at: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.16
	s.radial_segments = 8
	s.rings = 4
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/materials/beacon.gdshader")
	m.set_shader_parameter(&"colour", col)
	s.material = m
	mi.mesh = s
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	return mi


## The whole outside hull for modules `mods` (all when empty): one shell
## per faction, each over its own parts. Human and Scrap use the
## chamfered shell built over the whole ship and cut away where other
## factions' parts are, so it keeps its edges; Bio and Crystal grow their
## own surfaces, which meet it at the same height. Plus running lights.
static func make(d: ShipDesign, y0: float, mods: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = &"Shell"
	var all := (mods if not mods.is_empty() else range(d.modules.size())).filter(
			func(i): return not d.modules[i].exterior)
	if all.is_empty():
		return root
	var groups := {}
	for i in all:
		var tid: StringName = d.theme(i).id
		if not groups.has(tid):
			groups[tid] = []
		groups[tid].append(i)
	var ship := outlines(d, all)
	for tid in groups:
		var t := ShipTheme.by_id(tid)
		var mine: Array = groups[tid]
		if t.shell in [&"chamfer", &"plates"]:
			var cuts := all.filter(func(i): return not mine.has(i)).map(func(i): return _rect(d, i))
			root.add_child(_mesh(build(d, y0, all), ModelSkin.cut_shell(t, holes(d, mine), cuts)))
			if t.shell == &"plates":
				for p in outlines(d, mine):
					root.add_child(_mesh(FactionShell.plates(p, ship, y0 + HEIGHT, hash(p[0])),
							ModelSkin.shell_material(t)))
		else:
			for p in outlines(d, mine):
				var m := FactionShell.build(t.shell, p, ship, y0, hash(p[0]))
				root.add_child(_mesh(m, ModelSkin.faction_material(t.shell)))
	root.add_child(beacons(d, y0, all))
	return root


static func _mesh(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	return mi


static func _rect(d: ShipDesign, i: int) -> Rect2:
	var r := d.rect(i)
	return Rect2(Vector2(r.position) * ShipView.CELL, Vector2(r.size) * ShipView.CELL)
