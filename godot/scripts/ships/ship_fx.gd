class_name ShipFx
extends Node3D
## Effects and sounds for a live ship drawn by HulkView: exhaust and
## engine roar while a thruster burns, gunfire (GunFx) and recoil,
## debris and a blast when a module is destroyed, flickering lights and
## sparks on pieces cut off from the ship, the airlock hiss and the
## ship's background hum up close. Hangs effects on the "Muzzle*" and
## "Nozzle*" markers in part models (see art/tools/build_human.py).

const SPARK_RATE := 0.7  # sparks per second on each broken module
const SPARK_GAP := 0.4  # seconds between spark sounds

## Every working thruster fires, e.g. while the ship is under way. When
## off, a thruster only fires while it is crewed and fuelled.
var thrust_all := false
## When set, each thruster's exhaust follows its ramped throttle instead.

var hulk: HulkView
var helm: ShipHelm  # when set, thrusters burn as the helm fires them
var state: ShipState
var sim: CrewSim  # when set, spacewalks hiss the airlock
var _outside := {}  # crew member -> was outside last frame
var _spark_cd := 0.0
var _stock_cd := 0.0
var _alive := PackedByteArray()
var _last := {}  # module -> last global transform, for debris


func bind(h: HulkView, s: ShipState) -> void:
	hulk = h
	state = s
	s.fired.connect(fire)
	_alive.resize(s.size())
	for i in s.size():
		_alive[i] = int(s.hp[i] > 0.0)
	var hum := Sfx.player(&"ship_hum", -4.0, 45.0, true)
	if hum:
		hum.autoplay = true
		add_child(hum)


## Fires module i's guns from every muzzle: red beams for lasers,
## slugs for everything else, each with its sound.
func fire(i: int) -> void:
	var n := hulk.part(i) if hulk and is_inside_tree() else null
	if n == null:
		return  # headless sims (tests) have nothing to draw on
	var laser := is_laser(state.module(i))
	for m: Node3D in n.find_children("Muzzle*", "", true, false):
		if laser:
			GunFx.laser(_world(), m)
		else:
			GunFx.cannon(_world(), m)
	Sfx.play(_world(), &"laser_fire" if laser else &"cannon_fire", n.global_position)
	var head := n.find_child("Head*", true, false) as Node3D
	if head:
		var tw := head.create_tween()
		tw.tween_property(head, "position:z", 0.25, 0.05)
		tw.tween_property(head, "position:z", 0.0, 0.35)


func _process(delta: float) -> void:
	if state == null:
		return
	_spark_cd -= delta
	_stock_cd -= delta
	if _stock_cd <= 0.0:
		_stock_cd = 0.5
		_stock()
	_spacewalks()
	for i in state.size():
		var alive := state.hp[i] > 0.0
		if _alive[i] and not alive and _last.has(i):
			var r := state.design.rect(i)
			FxKit.debris(_world(), _last[i], Vector2(r.size) * ShipView.CELL * 0.5)
			Sfx.play(_world(), &"explosion", _last[i].origin, 2.0, 90.0)
		_alive[i] = int(alive)
		var n := hulk.part(i)
		if n == null:
			continue
		_last[i] = n.global_transform
		if state.module(i).thrust > 0.0:
			var on := 1.0 if thrust_all or state.is_running(i) else 0.0
			_exhaust(n, (helm.throttle.get(i, 0.0) if helm else on) if alive else 0.0)
		var p := state.pieces
		_flicker(n, alive and (p.drifting(i) or not p.powered(i)), delta)


## Exhaust at `level` 0..1: the flame grows, brightens and thickens
## with the throttle, so engines spool up and down rather than snap.
func _exhaust(n: Node3D, level: float) -> void:
	var on := level > 0.02
	for z: Node3D in n.find_children("Nozzle*", "", true, false):
		var fx := z.get_node_or_null(^"FxExhaust") as Node3D
		if fx == null and on:
			fx = FxKit.exhaust()
			var roar := Sfx.player(&"engine_loop", -6.0, 50.0, true)
			if roar:
				fx.add_child(roar)
			z.add_child(fx)
		if fx:
			fx.visible = on
			fx.scale = Vector3(0.6 + 0.4 * level, 0.6 + 0.4 * level, 0.3 + 0.7 * level)
			for p: GPUParticles3D in fx.find_children("*", "GPUParticles3D", false, false):
				p.emitting = on
				p.amount_ratio = maxf(level, 0.05)
			for l: OmniLight3D in fx.find_children("*", "OmniLight3D", false, false):
				l.light_energy = 2.5 * level
			for a: AudioStreamPlayer3D in fx.find_children("*", "AudioStreamPlayer3D", false, false):
				a.volume_db = lerpf(-30.0, -6.0, level)  # roar swells as it spools
				a.pitch_scale = lerpf(0.8, 1.15, level)
				if on != a.playing:
					a.playing = on


## Broken pieces: lamps stutter and drop out, sparks spit now and then.
## Lamps settle back to normal once the piece is reattached.
func _flicker(n: Node3D, broken: bool, delta: float) -> void:
	for l: OmniLight3D in n.find_children("*", "OmniLight3D", true, false):
		if l.get_parent().name == &"FxExhaust":
			continue
		if not l.has_meta(&"energy"):
			l.set_meta(&"energy", l.light_energy)
		var e: float = l.get_meta(&"energy")
		if not broken:
			l.light_energy = e
		elif randf() < delta * 12.0:
			l.light_energy = e * (0.0 if randf() < 0.35 else randf_range(0.15, 0.9))
	if broken and randf() < delta * SPARK_RATE:
		var off := Vector3(randf_range(-1, 1), randf_range(0.3, 2.0), randf_range(-1, 1))
		FxKit.sparks(_world(), n.global_transform * off)
		if _spark_cd <= 0.0:
			_spark_cd = SPARK_GAP
			Sfx.play(_world(), &"sparks", n.global_transform * off, -4.0, 35.0)


## Where loose effects go so they stay put in space as the ship moves.
func _world() -> Node:
	if not is_inside_tree():
		return self
	var s := get_tree().current_scene
	return s if s and s != self else self


## Lasers get a red beam and their own sound; everything else is a gun.
static func is_laser(m: ShipModule) -> bool:
	return m.id == &"turret" or "laser" in String(m.id) or "Laser" in m.display_name


## The airlock hisses whenever someone steps outside or comes back in.
func _spacewalks() -> void:
	if sim == null:
		return
	for c in sim.crew:
		var out: bool = c.eva
		if _outside.get(c, out) != out:
			var a := state.airlock(c.pos)
			var at := state.spot(a) if a >= 0 else c.pos
			Sfx.play(_world(), &"airlock_hiss", global_transform * Vector3(at.x, 1.0, at.y), -2.0, 40.0)
		_outside[c] = out


## Storage parts show their crates and shells ("Fill1".."Fill4" in the
## model) in step with how full the ship's stores of what they hold are.
func _stock() -> void:
	var st := state.storage
	for i in state.size():
		var m := state.module(i)
		if m.storage.is_empty():
			continue
		var n := hulk.part(i)
		if n == null:
			continue
		var have := 0.0
		var room := 0.0
		for res in m.storage:
			have += st.get_amount(res)
			room += st.capacity.get(res, 0.0)
		var frac := have / room if room > 0.0 else 0.0
		for k in range(1, 5):
			var f := n.find_child("Fill%d*" % k, true, false) as Node3D
			if f:
				f.visible = frac >= (k - 0.5) / 4.0
