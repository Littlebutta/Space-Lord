class_name ShipState
extends RefCounted
## Live condition of a built ship: damage, the fuel/ammo/food each
## module keeps on hand, and who is at its station. Crew change this;
## flight and combat read is_running() to know what actually works.

const BUFFER_HOURS := 3.0  # hours of upkeep a module can keep on hand

var design: ShipDesign
var storage: Storage
var hp := PackedFloat32Array()
var stock: Array[Dictionary] = []  # per module: resource -> units on hand
var operators := PackedInt32Array()  # crew at each station right now


func _init(d: ShipDesign, fill := 0.5) -> void:
	design = d
	storage = d.build_storage()
	for res in storage.capacity:
		storage.put(res, storage.capacity[res] * fill)
	for m in d.modules:
		hp.append(m.hp)
		var s := {}
		for res in m.upkeep:
			s[res] = m.upkeep[res] * BUFFER_HOURS * fill
		stock.append(s)
	operators.resize(d.modules.size())


func size() -> int:
	return hp.size()


func module(i: int) -> ShipModule:
	return design.modules[i]


## Middle of module i in ship-local metres (x, z).
func center(i: int) -> Vector2:
	var r := design.rect(i)
	return (Vector2(r.position) + Vector2(r.size) * 0.5) * ShipView.CELL


func damage(i: int, amount: float) -> void:
	hp[i] = maxf(hp[i] - amount, 0.0)


func repair(i: int, amount: float) -> void:
	hp[i] = minf(hp[i] + amount, module(i).hp)


func damaged(i: int) -> bool:
	return hp[i] < module(i).hp


func buffer(i: int, res: String) -> float:
	return module(i).upkeep.get(res, 0.0) * BUFFER_HOURS


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


## Intact, staffed and supplied: the module does its job.
func is_running(i: int) -> bool:
	return hp[i] > 0.0 and manned(i) and supplied(i)


## Burns the on-hand supplies of running modules.
func tick(hours: float) -> void:
	for i in size():
		if is_running(i):
			var up: Dictionary = module(i).upkeep
			for res in up:
				stock[i][res] = maxf(stock[i][res] - up[res] * hours, 0.0)
