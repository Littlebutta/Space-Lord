class_name Fleet
extends RefCounted
## The player's ships flying together on the system map, the fuel they
## carry for travel and jumps, and an SOS call once they're stranded.
## Static like Travel, so it lasts the whole run.

const BURN := 0.5  # fuel an hour per unit of engine fuel upkeep, cruising
const JUMP_FUEL := 25.0
const SOS_KINDS := [&"merchant", &"pirate", &"samaritan"]
const SOS_ODDS := [0.45, 0.3, 0.25]
const SOS_FROM := 90.0  # how far out help starts from

static var fuel := -1.0  # carried fuel; below 0 means tanks full (new game)
static var sos := {}  # {kind, from, start, eta, seed} while help is coming
static var _ships: Array[ShipDesign] = []


## Reloads the fleet from the saved player ship (a test ship if none).
static func refresh() -> void:
	var d := Wallet.ship()
	if d == null or d.modules.is_empty():
		d = ShipGenerator.sandbox(1337)
	_ships = [d]
	fuel = minf(fuel, cap())


static func ships() -> Array[ShipDesign]:
	if _ships.is_empty():
		refresh()
	return _ships


## The biggest ship, shown for the whole fleet on the map.
static func flagship() -> ShipDesign:
	var best: ShipDesign = ships()[0]
	for d in ships():
		if d.occupied().size() > best.occupied().size():
			best = d
	return best


static func cap() -> float:
	var n := 0.0
	for d in ships():
		n += d.build_storage().capacity.get("fuel", 0.0)
	return n


static func tank() -> float:
	if fuel < 0.0:
		fuel = cap()
	return fuel


static func room() -> float:
	return maxf(cap() - tank(), 0.0)


## Adds fuel (n < 0 fills the tanks); returns how much fit.
static func add_fuel(n: float) -> float:
	var got := room() if n < 0.0 else minf(n, room())
	fuel = tank() + got
	return got


## Fuel burned per game hour while flying: every engine's upkeep.
static func burn() -> float:
	var n := 0.0
	for d in ships():
		for m in d.modules:
			if m.thrust > 0.0:
				n += m.upkeep.get("fuel", 0.0)
	return maxf(n * BURN, 0.25)


## Travel.advance, paid for in fuel; the fleet stops when it runs dry.
static func travel(hours: float) -> int:
	if Travel.dest == null:
		return -1
	var h := minf(hours, tank() / burn())
	fuel = maxf(tank() - h * burn(), 0.0)
	var reached := Travel.advance(h)
	if h < hours and Travel.dest != null:
		Travel.dest = null
		Travel.aim = -1
	return reached


## Out of fuel: not even an hour of flying left.
static func stranded() -> bool:
	return tank() < burn()


## Sends a distress call; who answers is only seen when they arrive.
static func call_sos(now: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var a := rng.randf() * TAU
	sos = {kind = SOS_KINDS[rng.rand_weighted(PackedFloat32Array(SOS_ODDS))],
			from = Travel.pos + Vector3(cos(a), 0, sin(a)) * SOS_FROM,
			start = now, eta = rng.randf_range(4.0, 9.0), seed = rng.randi()}


## 0 when the call went out, 1 once help is alongside (`now`: game hours).
static func sos_progress(now: float) -> float:
	return clampf((now - sos.start) / sos.eta, 0.0, 1.0)
