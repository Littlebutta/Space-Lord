class_name ShipGuns
extends RefCounted
## A ship's guns in a fight. Each weapon picks the nearest intact enemy
## module in range; turrets swing their Head round to it and fire once
## lined up, fixed guns fire along their nose when it sits within ARC.
## Shots only hurt what they actually touch: lasers strike the first
## module along the beam, slugs fly at SLUG m/s and can be dodged.
## Shots go through ShipState.shoot (pays power, drives ShipFx muzzle
## flashes). `why` says why a gun is idle.

const RANGE := 70.0  # metres
const RELOAD := 1.5  # seconds between shots
const DAMAGE := 2.5  # shot damage = firepower * RELOAD * this
const ARC := 0.5  # radians either side a fixed gun can hit
const TRAVERSE := 2.5  # radians per second a turret head turns
const LINED_UP := 0.08  # radians off target a turret may fire at
const SPREAD := 0.03  # radians a shot may stray
const SLUG := 160.0  # m/s, matches GunFx's slug

signal shot(gun: int, to: Vector3, hit: bool)

var me: ShipBody
var _wait := {}  # gun module -> seconds until loaded
var _aim := {}  # gun module -> target module, -1 for none
var _slugs := []  # [gun, world pos, velocity, metres left, damage]


func _init(b: ShipBody) -> void:
	me = b


func tick(foe: ShipBody, delta: float) -> void:
	_fly(foe, delta)
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
		var dir := (to - from).normalized() if s.module(i).swivel else _nose(i)
		dir = dir.rotated(randf_range(-SPREAD, SPREAD))
		var dmg := s.module(i).firepower * RELOAD * DAMAGE
		if s.module(i).shot_power > 0.0:  # a beam: lands at once
			_strike(i, foe, from, dir * RANGE, dmg)
		else:
			_slugs.append([i, from, dir * SLUG, RANGE, dmg])


## Moves slugs along; each hits the first enemy module it passes through.
func _fly(foe: ShipBody, delta: float) -> void:
	for k in range(_slugs.size() - 1, -1, -1):
		var sl: Array = _slugs[k]
		var step: Vector2 = sl[2] * delta
		if _strike(sl[0], foe, sl[1], step, sl[4], false) or sl[3] <= 0.0:
			_slugs.remove_at(k)
		else:
			sl[1] += step
			sl[3] -= step.length()


## Damages the first intact enemy module the segment from..from+seg
## touches. True on a hit. A miss is only reported for beams (`final`).
func _strike(i: int, foe: ShipBody, from: Vector2, seg: Vector2, dmg: float,
		final := true) -> bool:
	var fs := foe.sim.state
	var best := -1
	var best_t := 2.0
	for k in fs.size():
		if fs.hp[k] <= 0.0:
			continue
		var c := foe.world(fs.pieces.world(k))
		var r := Vector2(fs.design.rect(k).size).length() * ShipView.CELL * 0.35
		var t := clampf((c - from).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
		if (from + seg * t).distance_to(c) < r and t < best_t:
			best = k
			best_t = t
	if best >= 0:
		fs.damage(best, dmg)
		var at := from + seg * best_t
		shot.emit(i, Vector3(at.x, 1.0, at.y), true)
	elif final:
		var end := from + seg
		shot.emit(i, Vector3(end.x, 1.0, end.y), false)
	return best >= 0


## World direction gun i's nose points.
func _nose(i: int) -> Vector2:
	var turn: int = me.sim.state.design.turns[i]
	return me.at.basis_xform(Vector2(ShipRules.rotate(ShipRules.FORWARD, turn))).normalized()


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
	return not me.sim.state.module(i).swivel or aim_head(n, to, delta)


## Turns the Head* node of part `n` toward world point `to`. True once
## lined up, or when there's no head to turn.
static func aim_head(n: Node3D, to: Vector3, delta: float) -> bool:
	var head: Node3D = n.find_child("Head*", true, false) as Node3D if n else null
	if head == null or not head.is_inside_tree():
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
	var aim := _nose(i)
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
