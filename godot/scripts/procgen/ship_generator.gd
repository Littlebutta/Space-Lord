class_name ShipGenerator
extends RefCounted
## Grows random ship designs from a core module so every encounter, and
## every wreck to salvage, is different.


static func generate(core: ShipModule, pool: Array[ShipModule],
		rng: RandomNumberGenerator, parts := 12) -> ShipDesign:
	var d := ShipDesign.new()
	d.add(core, Vector2i.ZERO)
	var tries := parts * 10
	while d.modules.size() < parts and tries > 0:
		tries -= 1
		var m := pool[rng.randi() % pool.size()]
		var i := rng.randi() % d.modules.size()
		var turn := rng.randi() % 4
		var r := d.rect(i)
		var at := _neighbor(r.position, r.size, ShipDesign.turned(m, turn), rng)
		d.add(m, at, turn)
	return d


## A cell where a module of size `s` touches the side of an existing one.
static func _neighbor(at: Vector2i, own: Vector2i, s: Vector2i,
		rng: RandomNumberGenerator) -> Vector2i:
	var ox := at.x + rng.randi_range(1 - s.x, own.x - 1)
	var oy := at.y + rng.randi_range(1 - s.y, own.y - 1)
	match rng.randi() % 4:
		0: return Vector2i(at.x + own.x, oy)
		1: return Vector2i(at.x - s.x, oy)
		2: return Vector2i(ox, at.y + own.y)
		_: return Vector2i(ox, at.y - s.y)
