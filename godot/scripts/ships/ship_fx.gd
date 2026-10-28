class_name ShipFx
extends Node3D
## Effects for a live ship drawn by HulkView: exhaust while a thruster
## runs, muzzle flashes, tracers and recoil when weapons fire, debris
## when a module is destroyed, and flickering lights and sparks on
## pieces cut off from the ship. Hangs effects on the "Muzzle*" and
## "Nozzle*" markers in part models (see art/tools/build_human.py).

const SPARK_RATE := 0.7  # sparks per second on each broken module
const TRACER := Color(1.0, 0.8, 0.5)

## Every working thruster fires, e.g. while the ship is under way. When
## off, a thruster only fires while it is crewed and fuelled.
var thrust_all := false

var hulk: HulkView
var helm: ShipHelm  # when set, thrusters burn as the helm fires them
var state: ShipState
var _alive := PackedByteArray()
var _last := {}  # module -> last global transform, for debris


func bind(h: HulkView, s: ShipState) -> void:
	hulk = h
	state = s
	_alive.resize(s.size())
	for i in s.size():
		_alive[i] = int(s.hp[i] > 0.0)


## Fires module i's guns: flash and a tracer from every muzzle.
func fire(i: int) -> void:
	var n := hulk.part(i) if hulk else null
	if n == null:
		return
	for m: Node3D in n.find_children("Muzzle*", "", true, false):
		FxKit.flash(m)
		FxKit.tracer(_world(), m.global_transform, TRACER)
	var head := n.find_child("Head*", true, false) as Node3D
	if head:
		var tw := head.create_tween()
		tw.tween_property(head, "position:z", 0.25, 0.05)
		tw.tween_property(head, "position:z", 0.0, 0.35)


func _process(delta: float) -> void:
	if state == null:
		return
	for i in state.size():
		var alive := state.hp[i] > 0.0
		if _alive[i] and not alive and _last.has(i):
			var r := state.design.rect(i)
			FxKit.debris(_world(), _last[i], Vector2(r.size) * ShipView.CELL * 0.5)
		_alive[i] = int(alive)
		var n := hulk.part(i)
		if n == null:
			continue
		_last[i] = n.global_transform
		if state.module(i).thrust > 0.0:
			var lit := helm.firing.has(i) if helm else state.is_running(i)
			_exhaust(n, alive and (thrust_all or lit))
		var p := state.pieces
		_flicker(n, alive and (p.drifting(i) or not p.powered(i)), delta)


func _exhaust(n: Node3D, on: bool) -> void:
	for z: Node3D in n.find_children("Nozzle*", "", true, false):
		var fx := z.get_node_or_null(^"FxExhaust") as Node3D
		if fx == null and on:
			fx = FxKit.exhaust()
			z.add_child(fx)
		if fx:
			fx.visible = on
			for p: GPUParticles3D in fx.find_children("*", "GPUParticles3D", false, false):
				p.emitting = on


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


## Where loose effects go so they stay put in space as the ship moves.
func _world() -> Node:
	var s := get_tree().current_scene
	return s if s and s != self else self
