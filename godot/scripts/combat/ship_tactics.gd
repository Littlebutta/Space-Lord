class_name ShipTactics
extends RefCounted
## AI attack patterns that suit the ship's own guns. Looks at which way
## its working guns point and picks a plan each think:
##  run   - fixed forward guns: nose on the target, close in, overshoot,
##          swing round and come again (needs only main engines)
##  side  - fixed guns on a flank or the stern: circle the target with
##          that side turned toward it
##  orbit - turrets: circle at a range that suits them (beams further
##          out than slugs), backing off further when badly hurt
##  flee  - no guns left: run for it

const R := ShipGuns.RANGE
const NEAR := 18.0  # an attack run breaks off this close
const SWING := 0.35  # radians the circling goal leads round the target

var me: ShipBody
var plan := &""
var _away := false  # an attack run is overshooting before turning back
var _exit := Vector2.ZERO  # where the overshoot heads, past the target


func _init(b: ShipBody) -> void:
	me = b


## Re-picks the plan and sets me.goal and me.look for the next second.
func think(foe: ShipBody) -> void:
	var guns := firepower()
	var fixed := 0.0
	var best := Vector2i.ZERO
	for dir in guns:
		if dir != Vector2i.ZERO:
			fixed += guns[dir]
			best = dir if best == Vector2i.ZERO or guns[dir] > guns[best] else best
	var turrets: float = guns.get(Vector2i.ZERO, 0.0)
	if fixed + turrets <= 0.0:
		plan = &"flee"
	elif turrets >= fixed:
		plan = &"orbit"
	else:
		plan = &"run" if best == ShipRules.FORWARD else &"side"
	var pos := me.world(me.pivot())
	var them := foe.world(foe.pivot())
	me.look = null
	match plan:
		&"flee":
			me.goal = pos + (pos - them).normalized() * R * 1.5
		&"orbit":
			var hurt := _health() < 0.35
			var keep := (0.8 if hurt else (0.65 if _beams() else 0.45)) * R
			me.goal = _circle(pos, them, keep)
		&"side":
			me.goal = _circle(pos, them, 0.5 * R)
			var g := Vector2(best)  # turn so that flank faces them
			me.look = pos + (them - pos).rotated(g.angle_to(Vector2(ShipRules.FORWARD)))
		&"run":
			_run(pos, them, foe)


## Closes nose-first, then overshoots and loops back once too close.
func _run(pos: Vector2, them: Vector2, foe: ShipBody) -> void:
	var d := pos.distance_to(them)
	if d < NEAR and not _away:
		_away = true  # streak past, a little off to one side to miss them
		_exit = them + (them - pos).normalized().rotated(0.4) * R * 0.6
	elif _away and (d > R * 0.6 or pos.distance_to(_exit) < 8.0):
		_away = false
	if _away:
		me.goal = _exit
	else:
		var lead := them + foe.vel * d / ShipGuns.SLUG
		me.look = lead
		me.goal = lead + (pos - lead).normalized() * (NEAR - 4.0)


## A point at range `keep` from them, a little further round the circle
## in whichever direction is ahead of the nose (so it rarely turns back).
func _circle(pos: Vector2, them: Vector2, keep: float) -> Vector2:
	var off := (pos - them).normalized()
	var nose := -me.at.y.normalized()
	var a := them + off.rotated(SWING) * keep
	var b := them + off.rotated(-SWING) * keep
	return a if (a - pos).dot(nose) >= (b - pos).dot(nose) else b


## Working firepower by facing: ship-local gun direction (FORWARD etc.)
## for fixed guns, Vector2i.ZERO for turrets.
func firepower() -> Dictionary:
	var s := me.sim.state
	var out := {}
	if s.pieces.main < 0:
		return out
	for i in s.pieces.pieces[s.pieces.main]:
		var m := s.module(i)
		if m.firepower <= 0.0 or s.hp[i] <= 0.0:
			continue
		var k := Vector2i.ZERO if m.swivel else ShipRules.rotate(ShipRules.FORWARD, s.design.turns[i])
		out[k] = out.get(k, 0.0) + m.firepower
	return out


## Most guns aboard are power beams rather than slug throwers.
func _beams() -> bool:
	var s := me.sim.state
	var n := 0
	for i in s.size():
		if s.module(i).firepower > 0.0:
			n += 1 if s.module(i).shot_power > 0.0 else -1
	return n > 0


## Share of the hull's hit points left, 0..1.
func _health() -> float:
	var s := me.sim.state
	var has := 0.0
	var full := 0.0
	for i in s.size():
		has += maxf(s.hp[i], 0.0)
		full += s.module(i).hp
	return has / maxf(full, 1.0)
