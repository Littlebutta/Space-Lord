class_name Travel
extends RefCounted
## The player's place on the system map, kept across scene changes, and
## the map sites (wrecks, asteroid nodes) they can stop at. Ore left in
## each asteroid node is remembered here too.

const SPEED := 6.0  # map units per game hour
const REACH := 4.0  # this close to a site counts as arrived

static var pos := Vector3(30.0, 0.0, 30.0)
static var dest: Variant = null  # Vector3 to fly to, or null
static var heading := 0.0
static var aim := -1  # site we're flying to, or -1
static var here := -1  # site whose local scene is open, or -1
static var sites: Array[Dictionary] = []  # {kind, pos, name, ore, seed}


## Test sites: one wreck and a few asteroid nodes, made once per run.
static func make_sites(seed_: int) -> void:
	if not sites.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	sites.append({kind = &"wreck", pos = Vector3(-60, 0, 45), name = "Wreck",
			ore = 0.0, seed = rng.randi()})
	while sites.size() < 5:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(40.0, 120.0)
		if site_at(p, 30.0) >= 0:
			continue  # keep pings apart
		sites.append({kind = &"asteroids", pos = p, name = "Asteroids",
				ore = rng.randf_range(150.0, 400.0), seed = rng.randi()})


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
