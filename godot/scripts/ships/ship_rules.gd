class_name ShipRules
extends RefCounted
## Layout rules that keep designs sensible. Thrusters fire out the back
## or sides through a clear lane, and parts that need a supply (fuel,
## ammo) sit near it. Each ShipModule's data drives the rules.

const FORWARD := Vector2i(0, -1)  # ship nose points to -y on the grid
const LANE := 64  # exhaust lane length in cells: "out to space"


## `v` after `turn` clockwise quarter turns (mirrored first for 4-7).
static func rotate(v: Vector2i, turn: int) -> Vector2i:
	if turn >= 4:
		v.x = -v.x
	for k in turn % 4:
		v = Vector2i(-v.y, v.x)
	return v


## Cells behind a thruster's nozzle that must stay empty.
static func lane(m: ShipModule, r: Rect2i, turn: int, length := LANE) -> Rect2i:
	var d := rotate(m.exhaust, turn)
	if d.y > 0:
		return Rect2i(r.position.x, r.end.y, r.size.x, length)
	if d.y < 0:
		return Rect2i(r.position.x, r.position.y - length, r.size.x, length)
	if d.x > 0:
		return Rect2i(r.end.x, r.position.y, length, r.size.y)
	if d.x < 0:
		return Rect2i(r.position.x - length, r.position.y, length, r.size.y)
	return Rect2i()


## Why `m` can't go at `cell`, or "" if it can.
static func why_not(d: ShipDesign, m: ShipModule, cell: Vector2i, turn: int) -> String:
	var r := Rect2i(cell, ShipDesign.turned(m, turn))
	var l := lane(m, r, turn)
	for i in d.modules.size():
		var o := d.rect(i)
		if o.intersects(r):
			return "Space taken"
		if l.intersects(o):
			return "Exhaust would hit the %s" % d.modules[i].display_name
		if lane(d.modules[i], o, d.turns[i]).intersects(r):
			return "Can't build in a thruster's exhaust"
	return ""


## Soft problems for the builder's warning list.
static func problems(d: ShipDesign) -> Array[String]:
	var out: Array[String] = []
	var far := {}  # "Thruster|fuel_tank|4" -> count
	for i in d.modules.size():
		var m := d.modules[i]
		var l := lane(m, d.rect(i), d.turns[i])
		for j in d.modules.size():
			if l.intersects(d.rect(j)):
				out.append("%s exhaust is blocked" % m.display_name)
				break
		for need in m.needs_near:
			var most := int(m.needs_near[need])
			if nearest(d, i, String(need)) > most:
				var key := "%s|%s|%d" % [m.display_name, need, most]
				far[key] = far.get(key, 0) + 1
	for key in far:
		var p := String(key).split("|")
		var nm := ModuleLibrary.by_id(StringName(p[1]))
		var what: String = nm.display_name if nm else p[1].capitalize()
		out.append("%d %s over %s cells from a %s" % [far[key], p[0], p[2], what])
	return out


## Cell gap from module `i` to the closest `need` (id or category),
## or -1 when the ship has none (other warnings cover that).
static func nearest(d: ShipDesign, i: int, need: String) -> int:
	var best := -1
	var a := d.rect(i)
	for j in d.modules.size():
		var m := d.modules[j]
		if j == i or (String(m.id) != need and m.category != need):
			continue
		var b := d.rect(j)
		var gx := maxi(0, maxi(b.position.x - a.end.x, a.position.x - b.end.x))
		var gy := maxi(0, maxi(b.position.y - a.end.y, a.position.y - b.end.y))
		var g := maxi(gx, gy)
		best = g if best < 0 else mini(best, g)
	return best
