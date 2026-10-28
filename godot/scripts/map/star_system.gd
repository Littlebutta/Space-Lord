class_name StarSystem
extends Node3D
## Procedurally places planets and asteroid belts around the star and
## moves them along their orbits using GameClock time.

@export var system_seed := 1
@export var body_count := Vector2i(4, 8)
@export var orbit_scale := 0.6  # bigger = slower orbits

var _orbits: Array[Dictionary] = []  # {node, radius, period, phase}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = system_seed
	var r := 16.0
	for i in rng.randi_range(body_count.x, body_count.y):
		r += rng.randf_range(10.0, 24.0)
		var body: Node3D = _belt(rng, r) if rng.randf() < 0.25 else _planet(rng)
		add_child(body)
		var period := orbit_scale * pow(r, 1.5)  # Kepler-ish, in hours
		_orbits.append({node = body, radius = r, period = period,
				phase = rng.randf() * TAU, belt = body is MultiMeshInstance3D})


func _process(_delta: float) -> void:
	for o in _orbits:
		var a: float = o.phase + TAU * GameClock.hours / o.period
		var n: Node3D = o.node
		if o.belt:
			n.rotation.y = -a  # belts spin in place
		else:
			n.position = Vector3(cos(a), 0.0, sin(a)) * o.radius


func _planet(rng: RandomNumberGenerator) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = rng.randf_range(1.2, 4.0)
	mesh.height = mesh.radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(rng.randf(), 0.45, 0.85)
	mat.roughness = 0.8
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


func _belt(rng: RandomNumberGenerator, radius: float) -> MultiMeshInstance3D:
	var rock := SphereMesh.new()
	rock.radial_segments = 6
	rock.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.4, 0.36)
	rock.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock
	mm.instance_count = 220
	for i in mm.instance_count:
		var a := rng.randf() * TAU
		var d := radius + rng.randf_range(-3.0, 3.0)
		var pos := Vector3(cos(a) * d, rng.randf_range(-0.8, 0.8), sin(a) * d)
		var s := Vector3(rng.randf_range(0.2, 0.9), rng.randf_range(0.2, 0.6),
				rng.randf_range(0.2, 0.9))
		var b := Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU)
		mm.set_instance_transform(i, Transform3D(b.scaled(s), pos))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi
