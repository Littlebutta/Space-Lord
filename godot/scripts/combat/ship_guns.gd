class_name ShipGuns
extends RefCounted
## A ship's guns in a fight. Each weapon picks the nearest intact enemy
## module in range; turrets swing their Head round to it and fire once
## lined up. Fixed guns only fire when their nose is lined up on where
## the target will be when the shot gets there. Shots only hurt what
## they actually touch: lasers strike the first module along the beam,
## slugs fly at SLUG m/s (drawn where they really are) and can be
## dodged. Shots go through ShipState.shoot (pays power, drives ShipFx
## muzzle flashes; ShipState.aim tells it where the shot goes).

const RANGE := 70.0  # metres
const RELOAD := 1.5  # seconds between shots
const DAMAGE := 2.5  # shot damage = firepower * RELOAD * this
const TRAVERSE := 2.5  # radians per second a turret head turns
const LINED_UP := 0.08  # radians off target a turret may fire at
const SPREAD := 0.02  # radians a shot may stray
const SLUG := 160.0  # m/s

signal shot(gun: int, to: Vector3, hit: bool)

var me: ShipBody
var hold := false  # no new targets (the enemy is beaten, no attack order)
var _enemy: ShipBody  # who we shot at last tick
var _wait := {}  # gun module -> seconds until loaded
var _aim := {}  # gun module -> target module, -1 for none
var _slugs := []  # [gun, world pos, velocity, metres left, damage, node or null]


func _init(b: ShipBody) -> void:
	me = b


func tick(foe: ShipBody, delta: float) -> void:
	_enemy = foe
	_fly(foe, delta)
	var s := me.sim.state
	for i in s.size():
		if s.module(i).firepower <= 0.0 or s.hp[i] <= 0.0:
			continue
		var from := me.world(s.pieces.world(i))
		var t := -1 if hold else _target(i, from, foe)
		_aim[i] = t
		_wait[i] = _wait.get(i, randf() * RELOAD) - delta
		if t < 0:
			continue
		var to := _lead(i, from, foe, t)
		var ready := _turn(i, Vector3(to.x, 1.0, to.y), delta)
		if _wait[i] > 0.0 or not ready or not s.can_shoot(i):
			continue
		_wait[i] = RELOAD
		var dir := (to - from).normalized() if s.module(i).swivel else _nose(i)
		dir = dir.rotated(randf_range(-SPREAD, SPREAD))
		var dmg := s.module(i).firepower * RELOAD * DAMAGE
		var beam := s.module(i).shot_power > 0.0
		var far := reach(i)
		var hit := _first(foe, from, dir * far) if beam else Vector2(-1, 1)
		var end := from + dir * far * hit.y
		s.aim[i] = Vector3(end.x, 1.0, end.y)
		var ok := s.shoot(i)
		s.aim.erase(i)
		if not ok:
			continue
		if beam:  # lands at once
			_strike(i, foe, from, dir * far, dmg)
		else:
			_slugs.append([i, from, dir * SLUG, far, dmg, _slug_fx(i, from, dir)])


## Moves slugs along; each hits the first enemy module it passes through.
func _fly(foe: ShipBody, delta: float) -> void:
	for k in range(_slugs.size() - 1, -1, -1):
		var sl: Array = _slugs[k]
		var step: Vector2 = sl[2] * delta
		var done: bool = _strike(sl[0], foe, sl[1], step, sl[4], false) or sl[3] <= 0.0
		sl[1] += step
		sl[3] -= step.length()
		var n: Node3D = sl[5]
		if n and is_instance_valid(n):
			n.global_position = Vector3(sl[1].x, n.global_position.y, sl[1].y)
			if done:
				GunFx.land(n)
		if done:
			_slugs.remove_at(k)


## Draws a slug from gun i's muzzle; null when there's nothing to draw on.
func _slug_fx(i: int, from: Vector2, dir: Vector2) -> Node3D:
	if me.hulk == null or not me.is_inside_tree():
		return null
	var n := me.hulk.part(i)
	var mz: Node3D = n.find_child("Muzzle*", true, false) as Node3D if n else null
	var at := mz.global_position if mz else Vector3(from.x, 1.0, from.y)
	return GunFx.slug(me.get_parent(), at, Vector3(dir.x, 0.0, dir.y))


## First intact enemy module along from..from+seg: (module, t 0..1), or
## (-1, 1) when the segment touches nothing.
func _first(foe: ShipBody, from: Vector2, seg: Vector2) -> Vector2:
	var fs := foe.sim.state
	var best := Vector2(-1, 1)
	for k in fs.size():
		if fs.hp[k] <= 0.0:
			continue
		var c := foe.world(fs.pieces.world(k))
		var t := clampf((c - from).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
		if (from + seg * t).distance_to(c) < _radius(foe, k) and (best.x < 0 or t < best.y):
			best = Vector2(k, t)
	return best


## Damages the first enemy module the segment touches. True on a hit.
## A miss is only reported for beams (`final`).
func _strike(i: int, foe: ShipBody, from: Vector2, seg: Vector2, dmg: float,
		final := true) -> bool:
	var hit := _first(foe, from, seg)
	var at := from + seg * hit.y
	if hit.x >= 0:
		foe.sim.state.damage(int(hit.x), dmg)
	if hit.x >= 0 or final:
		shot.emit(i, Vector3(at.x, 1.0, at.y), hit.x >= 0)
	return hit.x >= 0


static func _radius(b: ShipBody, k: int) -> float:
	return Vector2(b.sim.state.design.rect(k).size).length() * ShipView.CELL * 0.35


## World direction gun i's nose points.
func _nose(i: int) -> Vector2:
	var turn: int = me.sim.state.design.turns[i]
	return me.at.basis_xform(Vector2(ShipRules.rotate(ShipRules.FORWARD, turn))).normalized()


## Where to aim gun i at enemy module k: slugs lead a moving target.
func _lead(i: int, from: Vector2, foe: ShipBody, k: int) -> Vector2:
	var c := foe.world(foe.sim.state.pieces.world(k))
	if me.sim.state.module(i).shot_power > 0.0:
		return c
	return c + foe.vel * from.distance_to(c) / SLUG


## Gun i's current target module, or -1.
func target(i: int) -> int:
	return _aim.get(i, -1)


## The name of the enemy module gun i is aimed at.
func target_name(i: int) -> String:
	return _enemy.sim.state.module(target(i)).display_name if _enemy and target(i) >= 0 else ""


## Any gun has a target.
func engaged() -> bool:
	return _aim.values().any(func(t): return t >= 0)


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
	if hold:
		return "holding fire"
	return "no target" if target(i) < 0 else ""


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


## How far gun i shoots: bigger tiers reach further.
func reach(i: int) -> float:
	var r := me.sim.state.module(i).reach
	return r if r > 0.0 else RANGE


## Nearest intact enemy module gun i can hit: anything in range for a
## turret, for a fixed gun only what its nose line passes through.
func _target(i: int, from: Vector2, foe: ShipBody) -> int:
	var fs := foe.sim.state
	var nose := _nose(i)
	var free := me.sim.state.module(i).swivel
	var best := -1
	var best_d := reach(i)
	for k in fs.size():
		if fs.hp[k] <= 0.0 or fs.pieces.drifting(k):
			continue
		var to := _lead(i, from, foe, k) - from
		var lined := to.dot(nose) > 0.0 and absf(nose.cross(to)) < _radius(foe, k) * 0.8
		if to.length() < best_d and (free or lined):
			best = k
			best_d = to.length()
	return best
