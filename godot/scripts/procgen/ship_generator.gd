class_name ShipGenerator
extends RefCounted
## Grows random ship designs from a core module so every encounter, and
## every wreck to salvage, is different. Ships keep to one theme with
## the odd part from another, like a patched-up hull.


static func generate(core: ShipModule, pool: Array[ShipModule],
		rng: RandomNumberGenerator, parts := 12, tid := &"human",
		mix := 0.15) -> ShipDesign:
	var themes := ShipTheme.all()
	var d := ShipDesign.new()
	d.add(core, Vector2i.ZERO, 0, tid)
	var tries := parts * 10
	while d.modules.size() < parts and tries > 0:
		tries -= 1
		var m := pool[rng.randi() % pool.size()]
		var i := rng.randi() % d.modules.size()
		var turn := rng.randi() % 4
		var r := d.rect(i)
		var at := _neighbor(r.position, r.size, ShipDesign.turned(m, turn), rng)
		var t: StringName = themes[rng.randi() % themes.size()].id if rng.randf() < mix else tid
		if d.add(m, at, turn, t) and not ShipNav.reaches_all(d):
			d.remove_at(at)  # would wall crew off from part of the ship
	return d


## A random flyable test ship: a bridge with an airlock, a thruster,
## fuel, ammo and power always aboard.
static func sandbox(seed_: int, parts := 16) -> ShipDesign:
	var pool: Array[ShipModule] = ModuleLibrary.buildable().filter(
			func(m): return m.category != "command")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var g := generate(ModuleLibrary.by_id(&"bridge"), pool, rng, parts)
	for id in [&"airlock", &"engine", &"fuel_tank", &"ammo_rack", &"generator", &"capacitor"]:
		ensure(g, ModuleLibrary.by_id(id), rng)
	return g


## Bolts `m` on somewhere if the design has none (e.g. an airlock),
## where crew can walk to it from the bridge if any such spot is found.
static func ensure(d: ShipDesign, m: ShipModule, rng: RandomNumberGenerator) -> void:
	for tries in 200:
		if d.modules.has(m):
			return
		var r := d.rect(rng.randi() % d.modules.size())
		var at := _neighbor(r.position, r.size, m.size, rng)
		if d.add(m, at) and tries < 150 \
				and not ShipNav.new(d).connected(d.spot(0), d.spot(d.modules.size() - 1)):
			d.remove_at(at)  # walled off from the crew: try elsewhere


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
