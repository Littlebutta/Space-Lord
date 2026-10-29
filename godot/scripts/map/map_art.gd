class_name MapArt
extends RefCounted
## Models for the system map: planets (surface shader, rings, moons), a
## star's halo, and each kind of site (station, asteroids, wreck, jump
## point). Nodes in group "map_spin" turn at their "spin" meta (rad/s).

const PLANET := preload("res://assets/materials/planet.gdshader")
const FX := preload("res://assets/materials/map_fx.gdshader")
const ROCKY := [  # sea, land, peaks, atmosphere
	[Color(0.06, 0.16, 0.32), Color(0.24, 0.34, 0.16), Color(0.55, 0.5, 0.42), Color(0.4, 0.6, 1.0)],
	[Color(0.35, 0.18, 0.1), Color(0.6, 0.35, 0.2), Color(0.85, 0.7, 0.5), Color(1.0, 0.6, 0.4)],
	[Color(0.3, 0.32, 0.36), Color(0.5, 0.5, 0.52), Color(0.75, 0.75, 0.78), Color(0.6, 0.7, 0.8)],
	[Color(0.1, 0.25, 0.25), Color(0.5, 0.55, 0.6), Color(0.9, 0.95, 1.0), Color(0.6, 0.9, 1.0)],
]
const GAS := [
	[Color(0.75, 0.6, 0.42), Color(0.55, 0.35, 0.22), Color(0.95, 0.88, 0.75), Color(1.0, 0.8, 0.6)],
	[Color(0.3, 0.45, 0.7), Color(0.2, 0.3, 0.55), Color(0.7, 0.85, 0.95), Color(0.5, 0.7, 1.0)],
	[Color(0.55, 0.65, 0.5), Color(0.35, 0.45, 0.35), Color(0.85, 0.9, 0.75), Color(0.7, 1.0, 0.7)],
]


static func planet(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var gas := rng.randf() < 0.35
	var r := rng.randf_range(3.0, 5.5) if gas else rng.randf_range(1.4, 3.2)
	var pal: Array = (GAS if gas else ROCKY)[rng.randi() % (GAS if gas else ROCKY).size()]
	n.add_child(ball(rng, r, pal, gas, 0.0 if gas else rng.randf_range(0.3, 1.0)))
	if gas and rng.randf() < 0.6:
		var ring := disc(r * 2.4, pal[2], 0, 0.6)
		ring.rotation = Vector3(rng.randf_range(0.2, 0.5), 0, rng.randf_range(-0.2, 0.2))
		n.add_child(ring)
	for k in rng.randi_range(0, 2 if gas else 1):
		var pivot := Node3D.new()
		pivot.add_to_group(&"map_spin")
		pivot.set_meta(&"spin", rng.randf_range(0.05, 0.2))
		var moon := ball(rng, rng.randf_range(0.3, 0.6), ROCKY[2], false, 0.0)
		moon.position.x = r + 1.5 + k * 1.4
		pivot.add_child(moon)
		n.add_child(pivot)
	return n


static func ball(rng: RandomNumberGenerator, r: float, pal: Array, gas: bool,
		ice: float) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 64
	m.rings = 32
	var mat := ShaderMaterial.new()
	mat.shader = PLANET
	for k in 4:
		mat.set_shader_parameter([&"col_low", &"col_mid", &"col_high", &"atmo"][k], pal[k])
	mat.set_shader_parameter(&"gas", 1.0 if gas else 0.0)
	mat.set_shader_parameter(&"ice", ice)
	mat.set_shader_parameter(&"sea", rng.randf_range(0.3, 0.55))
	mat.set_shader_parameter(&"seed", rng.randf() * 50.0)
	mat.set_shader_parameter(&"atmo_gain", rng.randf_range(0.2, 0.8))
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.rotation.z = rng.randf_range(-0.4, 0.4)
	return mi


## A flat glowing disc `size` across (map_fx.gdshader `mode`).
static func disc(size: float, col: Color, mode: int, gain := 1.0) -> MeshInstance3D:
	var m := PlaneMesh.new() if mode != 2 else QuadMesh.new()
	m.size = Vector2.ONE * size
	var mat := ShaderMaterial.new()
	mat.shader = FX
	mat.set_shader_parameter(&"col", col)
	mat.set_shader_parameter(&"mode", mode)
	mat.set_shader_parameter(&"gain", gain)
	mat.set_shader_parameter(&"billboard", mode == 2)
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func metal(c := Color(0.5, 0.52, 0.55)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.6
	m.roughness = 0.55
	m.normal_enabled = true
	m.normal_texture = ModelSkin.noise(true)
	return m


## The model shown at a map site.
static func site(s: Dictionary, col: Color) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = s.seed
	match s.kind:
		&"station": return MapStation.make(col)
		&"jump": return _gate(col)
		&"wreck":
			var w := MapShip.new()
			w.show_design(ShipGenerator.sandbox(s.seed, 12))
			w.rotation = Vector3(0.3, rng.randf() * TAU, 0.5)
			return w
	var n := Node3D.new()
	for k in 7:
		var kind := StringName(Materials.ALL[rng.randi() % Materials.ALL.size()])
		var rock := MeshInstance3D.new()
		rock.mesh = AsteroidArt.mesh(rng, 1.0, kind)
		rock.scale = Vector3.ONE * rng.randf_range(0.4, 1.2)
		rock.position = Vector3(rng.randf_range(-2.5, 2.5), rng.randf_range(-0.6, 0.6),
				rng.randf_range(-2.5, 2.5))
		rock.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU
		n.add_child(rock)
	return n


## A jump gate: a heavy ring frame round a swirling vortex.
static func _gate(col: Color) -> Node3D:
	var n := Node3D.new()
	n.rotation.x = PI / 2.0  # stand it up
	var frame := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 3.2
	t.outer_radius = 4.0
	t.rings = 48
	t.material = metal(Color(0.35, 0.33, 0.4))
	frame.mesh = t
	n.add_child(frame)
	for k in 4:
		var pylon := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.8, 1.4, 0.9)
		b.material = metal()
		pylon.mesh = b
		pylon.position = Vector3(cos(k * PI / 2.0), 0, sin(k * PI / 2.0)) * 3.6
		pylon.rotation.y = -k * PI / 2.0
		n.add_child(pylon)
	var swirl := disc(6.6, col, 1, 1.4)
	swirl.add_to_group(&"map_spin")
	swirl.set_meta(&"spin", 0.4)
	n.add_child(swirl)
	return n
