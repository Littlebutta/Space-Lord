class_name Storage
extends RefCounted
## Cargo space per resource type. Nothing (fuel, ammo, food, ore, parts)
## can be held unless some module provides capacity for it.

signal changed

var capacity := {}  # resource id -> max units
var amount := {}  # resource id -> units held


func add_capacity(caps: Dictionary) -> void:
	for id in caps:
		capacity[id] = capacity.get(id, 0.0) + caps[id]


func get_amount(id: String) -> float:
	return amount.get(id, 0.0)


func free_space(id: String) -> float:
	return capacity.get(id, 0.0) - get_amount(id)


## Stores up to `qty`; returns how much actually fit.
func put(id: String, qty: float) -> float:
	var n := minf(qty, free_space(id))
	if n <= 0.0:
		return 0.0
	amount[id] = get_amount(id) + n
	changed.emit()
	return n


## Removes up to `qty`; returns how much was available.
func take(id: String, qty: float) -> float:
	var n := minf(qty, get_amount(id))
	if n <= 0.0:
		return 0.0
	amount[id] = get_amount(id) - n
	changed.emit()
	return n
