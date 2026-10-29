class_name ShipDrives
extends RefCounted
## Bolts thrusters onto a random hull so it can actually fly: a mirrored
## set of main engines across the stern, plus side thrusters at bow and
## stern for turning and sliding sideways (see ShipHelm).

const LEFT := 1  # turn whose exhaust points to -x (pushes +x)
const RIGHT := 3  # exhaust to +x


static func fit(d: ShipDesign, rng: RandomNumberGenerator, tid := &"human") -> void:
	var mains: Array[ShipModule] = ModuleLibrary.buildable().filter(
			func(m): return m.category == "engine" and m.thrust > 0.0)
	mains.sort_custom(func(a, b): return a.thrust < b.thrust)
	var small := mains[0]
	var big := d.modules.size() > 18 and rng.randf() < 0.6
	var main := mains[mini(int(big) + int(rng.randf() < 0.25), mains.size() - 1)]
	var want := 2 + int(d.modules.size() > 22)
	var placed := 0
	var tries := 0
	while placed < want and tries < 6:  # engines come in mirrored pairs
		tries += 1
		var at = _place(d, main, 0, func(c): return c.y * 100 - absi(_mid(d, c, main, 0)), tid)
		if at == null:
			break
		placed += 1
		var sp := _span(d)  # mirror it across the hull's middle
		var twin := Vector2i(sp.x + sp.y - at.x - main.size.x, at.y)
		if placed < want and twin != at and _try(d, main, twin, 0, tid):
			placed += 1
	for turn in [LEFT, RIGHT]:  # bow and stern, both sides
		_place(d, small, turn, func(c): return -c.y, tid)
		_place(d, small, turn, func(c): return c.y, tid)


## Puts m (turned `turn`) at its best-scoring open outside spot.
static func _place(d: ShipDesign, m: ShipModule, turn: int, score: Callable,
		tid: StringName) -> Variant:
	var spots := _spots(d, m, turn)
	spots.sort_custom(func(a, b): return score.call(a) > score.call(b))
	for c in spots.slice(0, 12):
		if _try(d, m, c, turn, tid):
			return c
	return null


## Adds m at c unless that walls crew off from part of the ship.
static func _try(d: ShipDesign, m: ShipModule, c: Vector2i, turn: int, tid: StringName) -> bool:
	if not d.add(m, c, turn, tid):
		return false
	if ShipNav.reaches_all(d):
		return true
	d.remove_at(c)
	return false


## Cells where m touches the side of an existing module and fits.
static func _spots(d: ShipDesign, m: ShipModule, turn: int) -> Array:
	var s := ShipDesign.turned(m, turn)
	var seen := {}
	for i in d.modules.size():
		var r := d.rect(i)
		for x in range(r.position.x - s.x + 1, r.end.x):
			seen[Vector2i(x, r.position.y - s.y)] = true
			seen[Vector2i(x, r.end.y)] = true
		for y in range(r.position.y - s.y + 1, r.end.y):
			seen[Vector2i(r.position.x - s.x, y)] = true
			seen[Vector2i(r.end.x, y)] = true
	return seen.keys().filter(func(c): return d.fits(m, c, turn))


## Leftmost and right edge x of the hull.
static func _span(d: ShipDesign) -> Vector2i:
	var out := Vector2i(1 << 20, -(1 << 20))
	for i in d.modules.size():
		out = Vector2i(mini(out.x, d.rect(i).position.x), maxi(out.y, d.rect(i).end.x))
	return out


## How far (doubled) a part at c sits off the middle.
static func _mid(d: ShipDesign, c: Vector2i, m: ShipModule, turn: int) -> int:
	var sp := _span(d)
	return 2 * c.x + ShipDesign.turned(m, turn).x - sp.x - sp.y
