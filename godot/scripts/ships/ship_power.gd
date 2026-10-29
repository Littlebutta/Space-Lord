class_name ShipPower
extends RefCounted
## The ship's power grid. Generators make power while running, which
## means crew have hauled fuel into them. Capacitors store it, so the
## ship can run without them but a big draw (a laser volley) drains the
## generator's own small buffer fast. Only parts tied to the bridge
## count; see ShipPieces.powered.
## Draws come out of the capacitors first, the generator buffers last.
## Generators idle (burning only IDLE of their fuel) until the
## capacitors fall below RECHARGE, then run until the grid is full.

const IDLE := 0.1  # share of fuel a generator burns with nothing to do
const RECHARGE := 0.5  # capacitor share that wakes the generators

var state: ShipState
var charge := 0.0  # power stored right now
var busy := 0.0  # share of generator output used last tick, 0..1
var _charging := true


func _init(s: ShipState, fill := 0.5) -> void:
	state = s
	charge = capacity() * fill


## Power the grid can hold: generator buffers plus capacitors.
func capacity() -> float:
	return _cap(true) + _cap(false)


## Capacitor charge (x) and their total size (y). Generator buffers
## fill first and drain last, so capacitors hold whatever is above them.
func stored() -> Vector2:
	var cap := _cap(false)
	return Vector2(clampf(charge - _cap(true), 0.0, cap), cap)


## Power made per second by running generators, flat out.
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
	var cap := capacity()
	var st := stored()
	if st.y > 0.0 and st.x < st.y * RECHARGE or charge < cap - st.y:
		_charging = true  # capacitors low (or none and the buffer isn't full)
	var made := 0.0
	var out := output() * delta
	if _charging and out > 0.0:
		made = minf(out, cap - charge)
		charge += made
	charge = clampf(charge, 0.0, cap)
	busy = made / out if out > 0.0 else 0.0
	if charge >= cap:
		_charging = false


## Takes `amount` from the grid; false (and takes nothing) if short.
func draw(amount: float) -> bool:
	if charge < amount:
		return false
	charge -= amount
	return true


## Summed power_cap of on-grid generators (`gen`) or capacitors.
func _cap(gen: bool) -> float:
	var c := 0.0
	for i in state.size():
		var m := state.module(i)
		if _on_grid(i) and (m.power_out > 0.0) == gen:
			c += m.power_cap
	return c


func _on_grid(i: int) -> bool:
	return state.hp[i] > 0.0 and state.pieces.powered(i)
