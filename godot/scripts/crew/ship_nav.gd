class_name ShipNav
extends RefCounted
## Walkable floor of a ship. Crew move in continuous space; this grid
## (finer than the build grid) only finds a route, which is smoothed
## into straight runs so nobody walks in grid steps. Teleporter pads
## link areas, even pieces that broke off: a route that blinks between
## pads repeats the first pad's point (see CrewSim._walk).

const RES := 2  # nav cells per build cell
const BODY := 0.25  # metres either side of a straight run that must be deck too
const HOP := 3.0  # metres a teleport counts as when picking the shorter way

var astar := AStarGrid2D.new()
var step := ShipView.CELL / RES
var floor_y := {}  # nav cell -> height of the deck there
var zone := {}  # nav cell -> id of the connected area it belongs to
var solid := {}  # nav cell -> cell of the module whose equipment blocks it
var pads := PackedVector2Array()  # where crew stand on each teleporter


func _init(d: ShipDesign) -> void:
	var box := Rect2i()
	for i in d.modules.size():
		box = d.rect(i) if i == 0 else box.merge(d.rect(i))
	astar.region = Rect2i(box.position * RES, box.size * RES)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	astar.fill_solid_region(astar.region)
	for i in d.modules.size():
		var r := d.rect(i)
		var h := ShipView.DECK * 0.5  # one flush deck, any theme
		for x in range(r.position.x * RES, r.end.x * RES):
			for y in range(r.position.y * RES, r.end.y * RES):
				astar.set_point_solid(Vector2i(x, y), false)
				floor_y[Vector2i(x, y)] = h
	for i in d.modules.size():
		_block(d, i)
		if d.modules[i].teleporter:
			pads.append(d.spot(i))
	_find_zones()


## Takes module i's ShipModule.blocked areas off the walkable deck.
func _block(d: ShipDesign, i: int) -> void:
	var m := d.modules[i]
	var at := Vector2(d.rect(i).position)
	for b in m.blocked:
		var ends := PackedVector2Array([b.position, b.end])
		var p := Prism.turned(ends, Vector2(m.size), d.turns[i])
		var r := Rect2(at + p[0], Vector2.ZERO).expand(at + p[1])
		var lo := Vector2i((r.position * RES).round())
		var hi := Vector2i((r.end * RES).round())
		for x in range(lo.x, hi.x):
			for y in range(lo.y, hi.y):
				var c := Vector2i(x, y)
				astar.set_point_solid(c, true)
				floor_y.erase(c)
				solid[c] = d.cells[i]


func cell(p: Vector2) -> Vector2i:
	return Vector2i((p / step).floor())


func walkable(p: Vector2) -> bool:
	return floor_y.has(cell(p))


func height(p: Vector2) -> float:
	return floor_y.get(cell(p), 0.0)


## True when a crew member at `a` can get to `b` at all.
func connected(a: Vector2, b: Vector2) -> bool:
	return _area(a) == _area(b) or _pad(_area(a)) and _pad(_area(b))


func _area(p: Vector2) -> int:
	return zone.get(cell(p), -1)


## Area `z` has a teleporter pad.
func _pad(z: int) -> bool:
	return z >= 0 and Array(pads).any(func(p): return _area(p) == z)


## Smoothed route from `a` to `b` in ship-local metres (x, z), through a
## pair of teleporters when that's shorter. Empty when `b` can't be reached.
func route(a: Vector2, b: Vector2) -> PackedVector2Array:
	var best := walk(a, b)
	var best_len := length(a, best) if not best.is_empty() else INF
	for p in pads:
		for q in pads:
			if p == q or _area(p) != _area(a) or _area(q) != _area(b) \
					or a.distance_to(p) + q.distance_to(b) + HOP >= best_len:
				continue
			var there := walk(a, p)
			there.append_array(PackedVector2Array([p, q]))
			there.append_array(walk(q, b))
			var n := length(a, there)
			if n < best_len:
				best = there
				best_len = n
	return best


## Metres along `path` from `a`; a teleport hop counts as HOP.
static func length(a: Vector2, path: PackedVector2Array) -> float:
	var n := 0.0
	for k in path.size():
		var from := a if k == 0 else path[k - 1]
		var hop := k > 1 and path[k - 1] == path[k - 2]
		n += HOP if hop else from.distance_to(path[k])
	return n


## Walking route from `a` to `b` on one area of deck, no teleports.
func walk(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if _area(a) != _area(b) or _area(a) < 0:
		return out
	var pts := PackedVector2Array()
	for c in astar.get_id_path(cell(a), cell(b)):
		pts.append((Vector2(c) + Vector2(0.5, 0.5)) * step)
	if pts.is_empty():
		return out
	pts[-1] = b
	var from := a
	var i := 0
	while i < pts.size():
		var j := pts.size() - 1
		while j > i and not clear(from, pts[j]):
			j -= 1
		from = pts[j]
		out.append(from)
		i = j + 1
	return out


## Straight line from `a` to `b` stays on the deck, with room for a
## body either side away from the ends, so nobody clips equipment.
func clear(a: Vector2, b: Vector2) -> bool:
	var run := a.distance_to(b)
	var n := ceili(run / (step * 0.25))
	var side := (b - a).orthogonal().normalized() * BODY
	for k in range(1, n + 1):
		var p := a.lerp(b, float(k) / n)
		if not walkable(p):
			return false
		var t := run * k / n
		if t > BODY and run - t > BODY and not (walkable(p + side) and walkable(p - side)):
			return false
	return true


func _find_zones() -> void:
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var id := 0
	for start in floor_y:
		if zone.has(start):
			continue
		var todo: Array[Vector2i] = [start]
		zone[start] = id
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			for dir in dirs:
				var n: Vector2i = c + dir
				if floor_y.has(n) and not zone.has(n):
					zone[n] = id
					todo.append(n)
		id += 1


## True when crew could walk from the first module to every other one.
static func reaches_all(d: ShipDesign) -> bool:
	return walled_off(d).is_empty()


## Modules whose work spot crew can't walk to from the first module.
static func walled_off(d: ShipDesign) -> Array[int]:
	var out: Array[int] = []
	var nav := ShipNav.new(d)
	for i in d.modules.size():
		if not nav.connected(d.spot(0), d.spot(i)):
			out.append(i)
	return out
