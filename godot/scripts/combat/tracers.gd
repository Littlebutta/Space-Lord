class_name Tracers
extends Node3D
## Short glowing bolts for gun shots, faded out in a blink. A stand-in
## until ShipFx draws proper muzzle flashes; one shared mesh and material.

const LIFE := 0.18  # seconds a bolt stays on screen

static var _mesh: BoxMesh

var _bolts: Array[Array] = []  # [MeshInstance3D, age]


func add(from: Vector3, to: Vector3, hit: bool) -> void:
	if _mesh == null:
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(0.12, 0.12, 1.0)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.75, 0.35)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.6, 0.2)
		m.emission_energy_multiplier = 4.0
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mesh.material = m
	var b := MeshInstance3D.new()
	b.mesh = _mesh
	add_child(b)
	b.look_at_from_position((from + to) * 0.5, to)
	b.scale.z = from.distance_to(to)
	b.transparency = 0.0 if hit else 0.4
	_bolts.append([b, 0.0])


func _process(delta: float) -> void:
	for k in range(_bolts.size() - 1, -1, -1):
		var e := _bolts[k]
		e[1] += delta
		var b: MeshInstance3D = e[0]
		b.transparency = maxf(b.transparency, e[1] / LIFE)
		if e[1] >= LIFE:
			b.queue_free()
			_bolts.remove_at(k)
