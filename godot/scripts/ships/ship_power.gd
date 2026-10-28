class_name ShipPower
extends RefCounted
## The ship's power grid. Generators make power while running, which
## means crew have hauled fuel into them. Capacitors store it, so the
## ship can run without them but a big draw (a laser volley) drains the
## generator's own small buffer fast. Only parts tied to the bridge
## count; see ShipPieces.powered.

var state: ShipState
var charge := 0.0  # power stored right now


func _init(s: ShipState, fill := 0.5) -> void:
	state = s
	charge = capacity() * fill


## Power the grid can hold: generator buffers plus capacitors.
func capacity() -> float:
	var cap := 0.0
	for i in state.size():
		if _on_grid(i):
			cap += state.module(i).power_cap
	return cap


## Power made per second by running generators.
func output() -> float:
	var out := 0.0
	for i in state.size():
		if state.module(i).power_out > 0.0 and state.is_running(i):
			out += state.module(i).power_out
	return out


## Share of capacity charged, 0..1, for bars.
func share() -> float:
	var cap := capacity()
	return charge / cap if cap > 0.0 else 0.0


func tick(delta: float) -> void:
	charge = clampf(charge + output() * delta, 0.0, capacity())


## Takes `amount` from the grid; false (and takes nothing) if short.
func draw(amount: float) -> bool:
	if charge < amount:
		return false
	charge -= amount
	return true


func _on_grid(i: int) -> bool:
	return state.hp[i] > 0.0 and state.pieces.powered(i)
