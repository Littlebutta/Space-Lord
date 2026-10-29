class_name CrewView
extends Node3D
## Builder overlay for planning crew movement (G). Green deck is
## walkable, red is equipment crew can't pass. Clicking a part draws the
## routes crew take for it: supplies hauled in from the store they'd use
## (amber), or out to the parts it feeds, and operators coming from
## quarters (blue). Teleporter hops show as cyan arcs.

const Y := ShipView.DECK * 0.5 + 0.04
const WIDE := 0.14  # route ribbon width, metres
const WALK := Color(0.3, 1.0, 0.45, 0.28)
const WALL := Color(1.0, 0.25, 0.2, 0.32)
const HOP := Color(0.3, 0.95, 1.0)

var _floor := MeshInstance3D.new()
var _routes := MeshInstance3D.new()


func _init() -> void:
	for n in [_floor, _routes]:
		n.material_override = _mat()
		add_child(n)


## Shows the walkable deck of `d`, or hides everything when null.
func show_floor(d: ShipDesign) -> void:
	visible = d != null
	_routes.mesh = null
	if d == null or d.modules.is_empty():
		_floor.mesh = null
		return
	var nav := ShipNav.new(d)
	var st := _begin()
	for c: Vector2i in _cells(nav):
		var walk: bool = nav.floor_y.has(c)
		_quad(st, (Vector2(c) + Vector2(0.06, 0.06)) * nav.step,
				(Vector2(c) + Vector2(0.94, 0.94)) * nav.step, WALK if walk else WALL)
	_floor.mesh = st.commit()


## Draws the crew routes for module i of `d`.
func show_routes(d: ShipDesign, i: int) -> void:
	_routes.mesh = null
	if i < 0:
		return
	var nav := ShipNav.new(d)
	var st := _begin()
	for r in routes(d, nav, i):
		_ribbon(st, r[0], r[1], r[2])
	_routes.mesh = st.commit()


## [start, path, colour] for each route crew walk for module i.
static func routes(d: ShipDesign, nav: ShipNav, i: int) -> Array:
	var out := []
	var m := d.modules[i]
	var haul: Color = CrewJob.COLORS[&"haul"]
	for res in m.upkeep:
		var s := store(d, nav, res, d.spot(i))
		if s >= 0 and s != i:
			out.append([d.spot(s), nav.route(d.spot(s), d.spot(i)), haul])
	for k in d.modules.size():
		for res in d.modules[k].upkeep:
			if k != i and m.storage.has(res) and store(d, nav, res, d.spot(k)) == i:
				out.append([d.spot(i), nav.route(d.spot(i), d.spot(k)), haul.darkened(0.25)])
	var home := range(d.modules.size()).filter(func(k): return d.modules[k].berths > 0)
	if m.crew > 0 and not home.is_empty() and home[0] != i:
		out.append([d.spot(home[0]), nav.route(d.spot(home[0]), d.spot(i)),
				CrewJob.COLORS[&"operate"]])
	return out.filter(func(r): return not r[1].is_empty())


## Store of `res` crew would fetch from for a part at `to`: the shortest
## walk. -1 if none.
static func store(d: ShipDesign, nav: ShipNav, res: String, to: Vector2) -> int:
	var best := -1
	var best_n := INF
	for k in d.modules.size():
		var m := d.modules[k]
		if not m.storage.has(res) or not nav.connected(d.spot(k), to):
			continue
		var n := ShipNav.length(d.spot(k), nav.route(d.spot(k), to))
		if n < best_n:
			best = k
			best_n = n
	return best


static func _cells(nav: ShipNav) -> Array:
	var out := nav.floor_y.keys()
	out.append_array(nav.solid.keys())
	return out


func _ribbon(st: SurfaceTool, from: Vector2, path: PackedVector2Array, col: Color) -> void:
	var a := from
	for k in path.size():
		var b := path[k]
		var hop := k > 1 and path[k - 1] == a and path[k - 2] == a
		if a != b:
			_seg(st, a, b, HOP if hop else col, 0.6 if hop else 0.0)
		a = b


## A flat strip from a to b; `arc` lifts its middle (teleport hops).
func _seg(st: SurfaceTool, a: Vector2, b: Vector2, col: Color, arc: float) -> void:
	var side := (b - a).orthogonal().normalized() * WIDE * 0.5
	var n := 8 if arc > 0.0 else 1
	for k in n:
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		var y0 := Y + arc * sin(t0 * PI)
		var y1 := Y + arc * sin(t1 * PI)
		st.set_color(col)
		for v in [[p0 - side, y0], [p0 + side, y0], [p1 + side, y1],
				[p0 - side, y0], [p1 + side, y1], [p1 - side, y1]]:
			st.add_vertex(Vector3(v[0].x, v[1], v[0].y))


func _quad(st: SurfaceTool, lo: Vector2, hi: Vector2, col: Color) -> void:
	st.set_color(col)
	for v in [lo, Vector2(hi.x, lo.y), hi, lo, hi, Vector2(lo.x, hi.y)]:
		st.add_vertex(Vector3(v.x, Y - 0.02, v.y))


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Unlit, see-through and drawn over the parts so it never hides.
static func _mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.render_priority = 2
	return m
