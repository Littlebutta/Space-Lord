class_name ShipNav
extends RefCounted
## Walkable floor of a ship. Crew move in continuous space; this grid
## (finer than the build grid) only finds a route, which is smoothed
## into straight runs so nobody walks in grid steps.

const RES := 2  # nav cells per build cell

var astar := AStarGrid2D.new()
var step := ShipView.CELL / RES
var floor_y := {}  # nav cell -> height of the deck there
var zone := {}  # nav cell -> id of the connected area it belongs to
var solid := {}  # nav cell -> cell of the module whose equipment blocks it


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


## True when a crew member at `a` can walk to `b` at all.
func connected(a: Vector2, b: Vector2) -> bool:
	return zone.get(cell(a), -1) == zone.get(cell(b), -2)


## Smoothed route from `a` to `b` in ship-local metres (x, z).
## Empty when `b` can't be reached.
func route(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not connected(a, b):
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


## Straight line from `a` to `b` stays on the deck.
func clear(a: Vector2, b: Vector2) -> bool:
	var n := ceili(a.distance_to(b) / (step * 0.25))
	for k in range(1, n + 1):
		if not walkable(a.lerp(b, float(k) / n)):
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
	var nav := ShipNav.new(d)
	for i in d.modules.size():
		if not nav.connected(d.spot(0), d.spot(i)):
			return false
	return true
