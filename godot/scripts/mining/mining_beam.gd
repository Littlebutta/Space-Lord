class_name MiningBeam
extends Node3D
## The mining laser's beam: a steady orange beam with a white-hot core,
## a glow and spray of sparks and dust where it bites the rock, and a
## light at each end. MiningField calls span() every tick.

const COL := Color(1.0, 0.55, 0.15)

var _beam := MeshInstance3D.new()
var _core := MeshInstance3D.new()
var _hit := Node3D.new()
var _spray: GPUParticles3D
var _t := 0.0


func _init() -> void:
	for k in 2:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.16 if k == 0 else 0.05
		cm.bottom_radius = cm.top_radius
		cm.height = 1.0
		cm.radial_segments = 10
		cm.material = FxKit.glow_mat(COL if k == 0 else Color(1, 0.9, 0.75), false)
		var mi := _beam if k == 0 else _core
		mi.mesh = cm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_spray = FxKit.particles(40, 0.6, Vector3.UP, 70.0, Vector2(2.0, 6.0), 0.22)
	_spray.local_coords = false
	_hit.add_child(_spray)
	_hit.add_child(FxKit.light(COL, 4.0, 9.0))
	add_child(_hit)
	visible = false


## Runs the beam from `from` to `to` (scene space), or hides it.
func span(from: Vector3, to: Vector3, on: bool) -> void:
	visible = on and from.distance_to(to) > 0.1
	_spray.emitting = visible
	if not visible:
		return
	var up := (to - from).normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := 1.0 + sin(_t * 9.0) * 0.03  # a steady beam, faint shimmer
	var bs := Basis(side, up, side.cross(up))
	var mid := (from + to) * 0.5
	_beam.transform = Transform3D(bs.scaled(Vector3(w, from.distance_to(to), w)), mid)
	_core.transform = Transform3D(bs.scaled(Vector3(1, from.distance_to(to), 1)), mid)
	_hit.position = to
	(_spray.process_material as ParticleProcessMaterial).direction = -up


func _process(delta: float) -> void:
	_t += delta
