class_name ShipState
extends RefCounted
## Live condition of a built ship: damage, the fuel/ammo/food each
## module keeps on hand, and who is at its station. Crew change this;
## flight and combat read is_running() to know what actually works.

## Weapon module i fired a shot (effects and battle hook onto this).
signal fired(i: int)

const BUFFER_HOURS := 3.0  # hours of upkeep a module can keep on hand
const REBUILT := 0.25  # share of hp a module is rebuilt with
const WELD := {"parts": 2.0}  # extra cost to weld a drifting piece back
const PARTS_PER_HP := 0.05  # repair bay work: a part per 20 hp
const AUTO_REST := 0.25  # unmanned firing time won back per second idle

var design: ShipDesign
var storage: Storage
var hp := PackedFloat32Array()
var stock: Array[Dictionary] = []  # per module: resource -> units on hand
var operators := PackedInt32Array()  # crew at each station right now
var auto := PackedFloat32Array()  # seconds of unmanned firing left
var burning := {}  # engines firing this tick (they burn fuel)
var pieces: ShipPieces  # how the ship has broken apart
var power: ShipPower  # generators and capacitors
var aim := {}  # gun -> world point (Vector3) its next shot heads for; ShipGuns sets it


func _init(d: ShipDesign, fill := 0.5) -> void:
	design = d
	storage = d.build_storage()
	for res in storage.capacity:
		storage.put(res, storage.capacity[res] * fill)
	for m in d.modules:
		hp.append(m.hp)
		auto.append(m.auto_time)
		var s := {}
		for res in m.upkeep:
			s[res] = m.upkeep[res] * BUFFER_HOURS * fill
		stock.append(s)
	operators.resize(d.modules.size())
	pieces = ShipPieces.new(d)
	power = ShipPower.new(self, fill)


func size() -> int:
	return hp.size()


func module(i: int) -> ShipModule:
	return design.modules[i]


## Middle of module i in ship-local metres (x, z).
func center(i: int) -> Vector2:
	var r := design.rect(i)
	return (Vector2(r.position) + Vector2(r.size) * 0.5) * ShipView.CELL


## Where crew stand to work on module i: its access spot k (wrapping
## round), or the middle when it has none. Ship-local metres (x, z).
func spot(i: int, k := 0) -> Vector2:
	return design.spot(i, k)


func damage(i: int, amount: float) -> void:
	if hp[i] <= 0.0:
		return
	hp[i] = maxf(hp[i] - amount, 0.0)
	if hp[i] <= 0.0:
		stock[i].clear()
		pieces.alive[i] = 0
		pieces.update()


## Repairs pay materials (Materials.repair_cost) from storage. Ships
## with no room for a material at all aren't charged it.
func repair(i: int, amount: float) -> void:
	if hp[i] <= 0.0:
		return
	var cost := Materials.repair_cost(module(i), amount)
	for k in cost:
		if storage.capacity.get(k, 0.0) > 0.0 and storage.get_amount(k) < cost[k]:
			return  # out of materials
	for k in cost:
		storage.take(k, cost[k])
	hp[i] = minf(hp[i] + amount, module(i).hp)


## A repair bay is up: crew repairs go faster, cost parts, and can be major.
func workshop() -> bool:
	for i in size():
		if module(i).workshop and hp[i] > 0.0 and pieces.powered(i):
			return true
	return false


## Crew repair work on module i for `delta` seconds at `rate` hp/s. With a
## repair bay and parts it goes twice as fast and can fix major damage;
## without, it stops once the damage is past what crew can patch.
## False when there's nothing more this crew member can do.
func crew_repair(i: int, rate: float, delta: float) -> bool:
	var m := module(i)
	if workshop():
		var amount := minf(rate * 2.0 * delta, m.hp - hp[i])
		if storage.take("parts", amount * PARTS_PER_HP) > 0.0:
			repair(i, amount)
			return damaged(i)
	if not Shipyard.can_repair(hp[i], m.hp, design):
		return false
	repair(i, rate * delta)
	return damaged(i)


## Can crew work on module i's damage right now?
func repairable(i: int) -> bool:
	return damaged(i) and (Shipyard.can_repair(hp[i], module(i).hp, design) \
			or workshop() and storage.get_amount("parts") > 0.0)


## Hurt but still standing; wrecked modules need rebuilding instead.
func damaged(i: int) -> bool:
	return hp[i] > 0.0 and hp[i] < module(i).hp


## Resources to rebuild module i from wreckage (data, else its mass in parts).
static func rebuild_cost(m: ShipModule) -> Dictionary:
	return m.rebuild if not m.rebuild.is_empty() else {"parts": ceilf(m.mass)}


## What it takes to bring module i back into the ship, or {} if it can't.
func reattach_cost(i: int) -> Dictionary:
	var gap = pieces.gap(i)
	if gap == null:
		return {}
	var cost := WELD.duplicate() if pieces.piece_of[i] >= 0 else {}
	for g in gap:
		var c := rebuild_cost(module(g))
		for res in c:
			cost[res] = cost.get(res, 0.0) + c[res]
	return cost


func can_pay(cost: Dictionary) -> bool:
	if cost.is_empty():
		return false
	for res in cost:
		if storage.get_amount(res) < cost[res]:
			return false
	return true


## Pays and rebuilds the gap so module i's piece (towed home already)
## joins the ship again. False if storage can't cover it.
func reattach(i: int) -> bool:
	var cost := reattach_cost(i)
	if not can_pay(cost):
		return false
	for res in cost:
		storage.take(res, cost[res])
	for g in pieces.gap(i):
		hp[g] = module(g).hp * REBUILT
		pieces.alive[g] = 1
	pieces.update()
	return true


## An intact cargo hold aboard: crew can bring loose ore and salvage in.
func has_hold() -> bool:
	for i in size():
		if module(i).hold and hp[i] > 0.0:
			return true
	return false


## Nearest intact airlock on the ship itself to `from`, or -1.
func airlock(from: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in size():
		var d := from.distance_squared_to(center(i))
		if module(i).airlock and hp[i] > 0.0 and not pieces.drifting(i) and d < best_d:
			best = i
			best_d = d
	return best


func buffer(i: int, res: String) -> float:
	return module(i).upkeep.get(res, 0.0) * BUFFER_HOURS


## The design minus wrecked modules: what crew can still walk on.
func intact() -> ShipDesign:
	var d := ShipDesign.new()
	for i in size():
		if hp[i] > 0.0:
			d.modules.append(module(i))
			d.cells.append(design.cells[i])
			d.turns.append(design.turns[i])
	return d


## Units of `res` module i can still take on hand.
func room(i: int, res: String) -> float:
	return maxf(buffer(i, res) - stock[i].get(res, 0.0), 0.0)


## Puts up to `qty` on hand at module i; returns how much fit.
func deliver(i: int, res: String, qty: float) -> float:
	var n := minf(qty, room(i, res))
	stock[i][res] = stock[i].get(res, 0.0) + n
	return n


func manned(i: int) -> bool:
	return operators[i] >= module(i).crew


## Has some of every supply it burns on hand.
func supplied(i: int) -> bool:
	for res in module(i).upkeep:
		if stock[i].get(res, 0.0) <= 0.0:
			return false
	return true


## Intact, powered, staffed and supplied: the module does its job.
func is_running(i: int) -> bool:
	return hp[i] > 0.0 and pieces.powered(i) and manned(i) and supplied(i)


## Engine i can fire now: running, or able to run a while unmanned.
func can_fire(i: int) -> bool:
	if power.charge < module(i).drive_power * 0.1:
		return false  # ion drive with a flat grid
	return is_running(i) or hp[i] > 0.0 and pieces.powered(i) and supplied(i) and auto[i] > 0.0


## Engine i fired for `delta` seconds; unmanned it uses up auto time.
func fire(i: int, delta: float) -> void:
	burning[i] = true
	power.draw(minf(module(i).drive_power * delta, power.charge))
	if not manned(i):
		auto[i] = maxf(auto[i] - delta, 0.0)


## Engine i sat idle (or crewed): it winds back up to auto firing.
func rest(i: int, delta: float) -> void:
	burning.erase(i)
	auto[i] = minf(auto[i] + delta * AUTO_REST, module(i).auto_time)


## Weapon i can shoot now: running, and lasers need power for a shot.
func can_shoot(i: int) -> bool:
	var m := module(i)
	return m.firepower > 0.0 and is_running(i) and power.charge >= m.shot_power


## Fires weapon i once if it can, paying any power; emits `fired`.
func shoot(i: int) -> bool:
	if not can_shoot(i) or not power.draw(module(i).shot_power):
		return false
	fired.emit(i)
	return true


## Burns the on-hand supplies of running modules; engines only use fuel
## while they are actually firing, generators as hard as they work.
func tick(hours: float) -> void:
	for i in size():
		if is_running(i) and (module(i).thrust <= 0.0 or burning.has(i)):
			var up: Dictionary = module(i).upkeep
			var k := maxf(power.busy, ShipPower.IDLE) if module(i).power_out > 0.0 else 1.0
			for res in up:
				stock[i][res] = maxf(stock[i][res] - up[res] * hours * k, 0.0)
