class_name ShipGuns
extends RefCounted
## A ship's guns in a fight. Each weapon picks the nearest intact enemy
## module in range; turrets swing their Head round to it and fire once
## lined up, fixed guns fire when it sits within ARC of their nose.
## Shots go through ShipState.shoot (pays power, drives ShipFx muzzle
## flashes); hits get likelier up close. `why` says why a gun is idle.

const RANGE := 70.0  # metres
const RELOAD := 1.5  # seconds between shots
const DAMAGE := 2.5  # shot damage = firepower * RELOAD * this
const ARC := 0.5  # radians either side a fixed gun can hit
const TRAVERSE := 2.5  # radians per second a turret head turns
const LINED_UP := 0.08  # radians off target a turret may fire at

signal shot(gun: int, to: Vector3, hit: bool)

var me: ShipBody
var _wait := {}  # gun module -> seconds until loaded
var _aim := {}  # gun module -> target module, -1 for none


func _init(b: ShipBody) -> void:
	me = b


func tick(foe: ShipBody, delta: float) -> void:
	var s := me.sim.state
	for i in s.size():
		if s.module(i).firepower <= 0.0 or s.hp[i] <= 0.0:
			continue
		var from := me.world(s.pieces.world(i))
		var t := _target(i, from, foe)
		_aim[i] = t
		if t < 0:
			continue
		var to := foe.world(foe.sim.state.pieces.world(t))
		var ready := _turn(i, Vector3(to.x, 1.0, to.y), delta)
		_wait[i] = _wait.get(i, randf() * RELOAD) - delta
		if _wait[i] > 0.0 or not ready or not s.shoot(i):
			continue
		_wait[i] = RELOAD
		var hit := randf() < clampf(1.2 - from.distance_to(to) / RANGE, 0.3, 0.95)
		if hit:
			foe.sim.state.damage(t, s.module(i).firepower * RELOAD * DAMAGE)
		shot.emit(i, Vector3(to.x, 1.0, to.y), hit)


## Why gun i isn't firing, or "" when it is (or is just reloading).
func why(i: int) -> String:
	var s := me.sim.state
	var m := s.module(i)
	if s.hp[i] <= 0.0:
		return "wrecked"
	if not s.pieces.powered(i):
		return "cut off from the bridge"
	if not s.manned(i):
		return "no crew"
	if not s.supplied(i):
		return "out of ammo"
	if s.power.charge < m.shot_power:
		return "no power (add a Reactor)" if s.power.output() <= 0.0 else "charging"
	return "no target" if _aim.get(i, -1) < 0 else ""


## Swings a turret's Head toward world point `to`; true once lined up.
## Guns without a Head (fixed mounts) are always "lined up".
func _turn(i: int, to: Vector3, delta: float) -> bool:
	var n: Node3D = me.hulk.part(i) if me.hulk else null
	var head: Node3D = n.find_child("Head*", true, false) as Node3D if n else null
	if head == null or not head.is_inside_tree() or not me.sim.state.module(i).swivel:
		return true
	var local: Vector3 = head.get_parent().global_transform.affine_inverse() * to
	var want := atan2(-local.x, -local.z)  # models face -z
	var off := angle_difference(head.rotation.y, want)
	head.rotation.y += clampf(off, -TRAVERSE * delta, TRAVERSE * delta)
	return absf(off) < LINED_UP


## Nearest intact enemy module gun i can bring to bear, or -1.
func _target(i: int, from: Vector2, foe: ShipBody) -> int:
	var fs := foe.sim.state
	var p := fs.pieces
	var turn: int = me.sim.state.design.turns[i]
	var aim := me.at.basis_xform(Vector2(ShipRules.rotate(ShipRules.FORWARD, turn)))
	var free := me.sim.state.module(i).swivel
	var best := -1
	var best_d := RANGE
	for k in fs.size():
		if fs.hp[k] <= 0.0 or p.drifting(k):
			continue
		var to := foe.world(p.world(k)) - from
		if to.length() < best_d and (free or absf(aim.angle_to(to)) < ARC):
			best = k
			best_d = to.length()
	return best
