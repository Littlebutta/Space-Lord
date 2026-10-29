class_name Travel
extends RefCounted
## The player's place on the system map, kept across scene changes, and
## the map sites (wrecks, asteroid nodes, the system's neutral station,
## jump points to the next systems) they can stop at. Each system's sites
## are kept, so ore left in an asteroid node is remembered after a jump.

const SPEED := 6.0  # map units per game hour
const REACH := 4.0  # this close to a site counts as arrived
const DOCK_RANGE := 25.0  # within this of a station you can refit

static var pos := Vector3(30.0, 0.0, 30.0)
static var dest: Variant = null  # Vector3 to fly to, or null
static var heading := 0.0
static var aim := -1  # site we're flying to, or -1
static var here := -1  # site whose local scene is open, or -1
static var sites: Array[Dictionary] = []  # {kind, pos, name, ore, seed, faction, to}
static var system := 0  # which star system we're in; jumps go to +-1
static var _visited := {}  # system -> its sites
const NAMES := ["Kestrel", "Vanta", "Orrin's Reach", "Hollow Gate", "Cinder",
		"Lumen Drift", "Tarsis", "Ebon Wake", "Sable", "Halcyon"]
const EDGE := 165.0  # jump points sit this far out
const PLANET_REACH := 10.0  # widest planet + rings + moons
const BELT_REACH := 5.0


## Test sites: one wreck and a few asteroid nodes, made once per run.
static func make_sites(seed_: int) -> void:
	if not sites.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	sites.append({kind = &"wreck", pos = _free(rng, 50.0, 110.0), name = "Wreck",
			ore = 0.0, seed = rng.randi()})
	for k in 4:
		sites.append({kind = &"asteroids", pos = _free(rng, 40.0, 130.0), name = "Asteroids",
				ore = rng.randf_range(150.0, 400.0), seed = rng.randi()})
	_station(rng)
	for to in [system - 1, system + 1]:
		sites.append({kind = &"jump", pos = _free(rng, EDGE, EDGE + 40.0),
				name = "Jump to %s" % system_name(to), ore = 0.0, seed = rng.randi(), to = to})


## The system's orbits {radius, reach, belt, phase, seed}, the same
## every time for a seed. Neighbours' reaches never overlap.
static func lanes() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = system_seed() + 71
	var out: Array[Dictionary] = []
	var r := 14.0  # past the sun and its halo
	var prev := 0.0
	for i in rng.randi_range(4, 8):
		var belt := rng.randf() < 0.25
		var reach := BELT_REACH if belt else PLANET_REACH
		r += prev + reach + rng.randf_range(4.0, 34.0)
		prev = reach
		out.append({radius = r, reach = reach, belt = belt,
				phase = rng.randf() * TAU, seed = rng.randi()})
	return out


## True when a still object `room` wide at distance d from the sun stays
## clear of every orbiting body.
static func clear_of_orbits(d: float, room: float) -> bool:
	for l in lanes():
		if absf(d - l.radius) < l.reach + room:
			return false
	return true


## A spot lo..hi from the sun that no planet or belt sweeps through and
## that keeps clear of the other sites; further out if none is free.
static func _free(rng: RandomNumberGenerator, lo: float, hi: float) -> Vector3:
	for tries in 200:
		var span := hi - lo + tries * 2.0  # widen the band when it's crowded
		var d := lo + rng.randf() * span
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0.0, sin(a)) * d
		if clear_of_orbits(d, 7.0) and site_at(p, 30.0) < 0:
			return p
	return Vector3(hi + 300.0, 0.0, 0.0)


static func system_seed(k := system) -> int:
	return 1337 + k * 7919


static func system_name(k := system) -> String:
	var n: String = NAMES[posmod(k, NAMES.size())]
	return n if absi(k) < NAMES.size() else "%s %d" % [n, absi(k) / NAMES.size() + 1]


## Moves to system `to`, arriving beside its jump point back here.
static func jump(to: int) -> void:
	var from := system
	_visited[system] = sites.duplicate()
	system = to
	sites.assign(_visited.get(to, []))
	make_sites(system_seed())
	for s in sites:
		if s.kind == &"jump" and s.to == from:
			pos = s.pos * (1.0 - REACH * 3.0 / EDGE)
	dest = null
	aim = -1
	here = -1


## Moves along by game time; returns the site just reached, or -1.
static func advance(hours: float) -> int:
	if dest == null:
		return -1
	var to: Vector3 = dest - pos
	var step := SPEED * hours
	if to.length() > 0.01:
		heading = atan2(-to.x, -to.z)
	var near := aim >= 0 and to.length() < REACH
	if near or to.length() <= step:
		pos = pos if near else dest
		dest = null
		var s := aim
		aim = -1
		return s
	pos += to / to.length() * step
	return -1


## Site under a map point, or -1.
static func site_at(p: Vector3, within: float) -> int:
	for i in sites.size():
		if sites[i].pos.distance_to(p) < within:
			return i
	return -1


static func site() -> Dictionary:
	return sites[here] if here >= 0 and here < sites.size() else {}


## One neutral station per system, run by a non-human faction whose
## blueprints it sells.
static func _station(rng: RandomNumberGenerator) -> void:
	var fs := ShipTheme.all().filter(func(t): return t.id != &"human")
	var f: ShipTheme = fs[rng.randi() % fs.size()] if fs else ShipTheme.all()[0]
	sites.append({kind = &"station", pos = _free(rng, 60.0, 100.0),
			name = "%s Station" % f.display_name, ore = 0.0, seed = rng.randi(),
			faction = f.id})


## The station in refit range of the player, or {}.
static func near_station() -> Dictionary:
	for s in sites:
		if s.kind == &"station" and s.pos.distance_to(pos) < DOCK_RANGE:
			return s
	return {}
