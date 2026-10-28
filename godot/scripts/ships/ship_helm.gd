class_name ShipHelm
extends RefCounted
## Picks which thrusters fire. Each thruster pushes away from its exhaust
## at its own spot, so it also twists the ship around its centre of mass.
## To turn or go backwards the ship needs thrusters facing that way (or
## set off to one side). Engines fire while crewed, or unmanned for a
## while (ShipModule.auto_time) before crew must take over.

const FORCE := 1.5  # scales module thrust into ship push
const FIRE := 0.25  # how useful a thruster must be to fire
const ALIGN := 0.7  # a thruster helps a burn only this well lined up (cos)

var state: ShipState
var firing := PackedInt32Array()  # thrusters lit this tick, for effects
var mass := 1.0
var inertia := 1.0
var com := Vector2.ZERO  # centre of mass, ship-local


func _init(s: ShipState) -> void:
	state = s


## Mass, centre and spin inertia of the ship's own piece.
func weigh() -> void:
	var p := state.pieces
	if p.main < 0:
		return
	mass = 0.0
	com = Vector2.ZERO
	for i in p.pieces[p.main]:
		mass += state.module(i).mass
		com += state.center(i) * state.module(i).mass
	com /= maxf(mass, 0.001)
	inertia = 1.0
	for i in p.pieces[p.main]:
		inertia += state.module(i).mass * com.distance_squared_to(state.center(i))


## Push of module i if it fires, ship-local (zero if not a thruster).
func push(i: int) -> Vector2:
	var m := state.module(i)
	if m.thrust <= 0.0:
		return Vector2.ZERO
	var out := Vector2(ShipRules.rotate(m.exhaust, state.design.turns[i]))
	return -out.normalized() * m.thrust * FORCE


## Some working thruster pushes along `dir` (ship-local).
func can_push(dir: Vector2) -> bool:
	var p := state.pieces
	if p.main < 0:
		return false
	for i in p.pieces[p.main]:
		var f := push(i)
		if f != Vector2.ZERO and f.normalized().dot(dir.normalized()) > ALIGN and state.can_fire(i):
			return true
	return false


## Twist a push at module i gives.
func twist(i: int, f: Vector2) -> float:
	return (state.center(i) - com).cross(f)


## Fires toward velocity change `dv` (ship-local m/s) and a turn `turn`
## (-1..1, + is the way +angle rotates). Returns [force, torque].
func steer(dv: Vector2, turn: float, delta: float) -> Array:
	firing.clear()
	var force := Vector2.ZERO
	var torque := 0.0
	var p := state.pieces
	if p.main < 0 or not _commanded():
		return [force, torque]
	for i in p.pieces[p.main]:
		var f := push(i)
		if f == Vector2.ZERO:
			continue
		var t := twist(i, f)
		var lin := maxf(f.normalized().dot(dv.normalized()) - ALIGN, 0.0) / (1.0 - ALIGN)
		lin *= minf(dv.length(), 1.0) * (1.0 - absf(turn) * 0.7)  # turning comes first
		var rot := signf(t) * turn * minf(absf(t) / f.length(), 1.0)
		if lin + rot > FIRE and state.can_fire(i):
			state.fire(i, delta)
			firing.append(i)
			force += f
			torque += t
		else:
			state.rest(i, delta)
	return [force, torque]


## The bridge is manned and powered, so someone can give orders.
func _commanded() -> bool:
	var p := state.pieces
	for i in p.pieces[p.main]:
		if state.module(i).category == "command" and state.is_running(i):
			return true
	return false
