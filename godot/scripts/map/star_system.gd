class_name StarSystem
extends Node3D
## Procedurally places planets and asteroid belts around the star of the
## system we're in (Travel.system) and moves them along their orbits
## using GameClock time. Each system gets its own star colour and sky.

@export var body_count := Vector2i(4, 8)
@export var orbit_scale := 0.6  # bigger = slower orbits

const STARS := [Color(1, 0.65, 0.3), Color(1, 0.85, 0.6), Color(0.65, 0.8, 1),
		Color(1, 0.45, 0.25), Color(0.95, 0.95, 1)]

var _orbits: Array[Dictionary] = []  # {node, radius, period, phase, belt}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Travel.system_seed()
	_star(rng)
	var r := 18.0
	for i in rng.randi_range(body_count.x, body_count.y):
		r += rng.randf_range(12.0, 24.0)
		var belt := rng.randf() < 0.25
		var body: Node3D = _belt(rng, r) if belt else MapArt.planet(rng)
		add_child(body)
		var period := orbit_scale * pow(r, 1.5)  # Kepler-ish, in hours
		_orbits.append({node = body, radius = r, period = period,
				phase = rng.randf() * TAU, belt = belt})


func _process(delta: float) -> void:
	for o in _orbits:
		var a: float = o.phase + TAU * GameClock.hours / o.period
		var n: Node3D = o.node
		if o.belt:
			n.rotation.y = -a  # belts spin in place
		else:
			n.position = Vector3(cos(a), 0.0, sin(a)) * o.radius
	for n in get_tree().get_nodes_in_group(&"map_spin"):
		n.rotate_object_local(Vector3.UP, n.get_meta(&"spin") * delta)


## Tints the scene's sun, its light and the sky for this system.
func _star(rng: RandomNumberGenerator) -> void:
	var c: Color = STARS[rng.randi() % STARS.size()]
	var sun := get_node_or_null(^"Sun") as MeshInstance3D
	if sun:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 4.0
		sun.material_override = m
		sun.add_child(MapArt.disc(40.0, c, 2, 1.2))
	var light := get_node_or_null(^"SunLight") as Light3D
	if light:
		light.light_color = c.lerp(Color.WHITE, 0.5)
	var env := get_parent().get_node_or_null(^"Env") as WorldEnvironment
	if env and env.environment.sky:
		var sky := env.environment.sky.sky_material as ShaderMaterial
		sky.set_shader_parameter(&"nebula_col", Color.from_hsv(rng.randf(), 0.6, 0.12))
		sky.set_shader_parameter(&"band_col", Color.from_hsv(rng.randf(), 0.25, 0.09))


## A ring of tumbling rocks: a few rock shapes, many copies each.
func _belt(rng: RandomNumberGenerator, radius: float) -> Node3D:
	var n := Node3D.new()
	for shape in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = AsteroidArt.mesh(rng, 1.0, &"iron")
		mm.instance_count = 90
		for i in mm.instance_count:
			var a := rng.randf() * TAU
			var d := radius + rng.randf_range(-3.5, 3.5)
			var pos := Vector3(cos(a) * d, rng.randf_range(-0.9, 0.9), sin(a) * d)
			var s := Vector3(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.6),
					rng.randf_range(0.2, 0.8))
			var b := Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU)
			mm.set_instance_transform(i, Transform3D(b.scaled(s), pos))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		n.add_child(mmi)
	return n
