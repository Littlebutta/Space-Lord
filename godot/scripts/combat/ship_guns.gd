class_name ShipGuns
extends RefCounted
## A ship's guns in a fight. Every weapon that can shoot (crewed,
## powered, stocked, lasers charged) reloads, then fires through
## ShipState.shoot (which pays power and drives effects) at the nearest
## intact module of the enemy in range. Turrets swivel; fixed guns only fire within ARC of where
## they point. Hits get likelier up close. Each shot is reported so
## effects can draw it.

const RANGE := 70.0  # metres
const RELOAD := 1.5  # seconds between shots
const ARC := 0.5  # radians either side a fixed gun can hit
const SWIVEL := ["turret"]  # module ids that aim all round

signal shot(gun: int, from: Vector3, to: Vector3, hit: bool)

var me: ShipBody
var _wait := {}  # gun module -> seconds until loaded


func _init(b: ShipBody) -> void:
	me = b


func tick(foe: ShipBody, delta: float) -> void:
	var s := me.sim.state
	for i in s.size():
		if not s.can_shoot(i):
			continue
		_wait[i] = _wait.get(i, randf() * RELOAD) - delta
		if _wait[i] > 0.0:
			continue
		var from := me.world(s.pieces.world(i))
		var t := _target(i, from, foe)
		if t < 0 or not s.shoot(i):
			continue
		_wait[i] = RELOAD
		var to := foe.world(foe.sim.state.pieces.world(t))
		var hit := randf() < clampf(1.2 - from.distance_to(to) / RANGE, 0.3, 0.95)
		if hit:
			foe.sim.state.damage(t, s.module(i).firepower * RELOAD)
		var miss := Vector2.ZERO if hit else Vector2.from_angle(randf() * TAU) * 3.0
		shot.emit(i, Vector3(from.x, 1.0, from.y), Vector3(to.x + miss.x, 1.0, to.y + miss.y), hit)


## Nearest intact enemy module gun i can bring to bear, or -1.
func _target(i: int, from: Vector2, foe: ShipBody) -> int:
	var fs := foe.sim.state
	var p := fs.pieces
	var aim := me.at.basis_xform(Vector2(ShipRules.rotate(ShipRules.FORWARD, me.sim.state.design.turns[i])))
	var free: bool = me.sim.state.module(i).id in SWIVEL
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
