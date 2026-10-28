extends Node3D
## The player's ship on the system map, and the sites around it. Right
## click to fly somewhere (or to a site); it moves with game time, so it
## stops when paused and hurries when sped up. Reaching a site opens its
## local scene.

const SCENE := "res://scenes/crew/crew_test.tscn"
const COLORS := {&"wreck": Color(1.0, 0.3, 0.2), &"asteroids": Color(0.9, 0.75, 0.45)}

var _icon := MeshInstance3D.new()
var _flag := MeshInstance3D.new()  # where we're headed
var _pings: Array[Node3D] = []
var _labels: Array[Label3D] = []


func _ready() -> void:
	Travel.here = -1
	Travel.make_sites(1337)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 2.0
	cone.height = 5.0
	cone.material = MapGlow.make(Color(0.4, 0.85, 1.0))
	_icon.mesh = cone
	add_child(_icon)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.6
	ring.outer_radius = 2.0
	ring.material = MapGlow.make(Color(0.4, 0.85, 1.0, 0.6))
	_flag.mesh = ring
	add_child(_flag)
	for s in Travel.sites:
		_site(s)
	var cam := get_parent().get_node_or_null(^"Camera")
	if cam:
		cam.focus = Travel.pos


func _site(s: Dictionary) -> void:
	var n := Node3D.new()
	n.position = s.pos
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 4.2
	t.outer_radius = 4.8
	t.material = MapGlow.make(COLORS[s.kind])
	ring.mesh = t
	n.add_child(ring)
	if s.kind == &"asteroids":
		for k in 5:
			var rock := MeshInstance3D.new()
			var m := SphereMesh.new()
			m.radius = randf_range(0.4, 1.0)
			m.height = m.radius * 1.6
			m.radial_segments = 6
			m.rings = 3
			rock.mesh = m
			rock.position = Vector3(randf_range(-1.8, 1.8), 0, randf_range(-1.8, 1.8))
			n.add_child(rock)
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0007
	l.position = Vector3(0, 2, -6)
	l.modulate = COLORS[s.kind]
	n.add_child(l)
	add_child(n)
	_pings.append(ring)
	_labels.append(l)


func _process(delta: float) -> void:
	var reached := Travel.advance(GameClock.SPEEDS[GameClock.speed] * delta)
	_icon.position = Travel.pos + Vector3.UP
	_icon.rotation = Vector3(-PI / 2.0, Travel.heading, 0.0)
	_flag.visible = Travel.dest != null
	if _flag.visible:
		_flag.position = Travel.dest
	var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.004)
	for i in _pings.size():
		var s: Dictionary = Travel.sites[i]
		_pings[i].scale = Vector3.ONE * (pulse if s.kind == &"wreck" else 1.0)
		_labels[i].text = s.name + ("  ore %d" % s.ore if s.kind == &"asteroids" else "")
	if reached >= 0:
		Travel.here = reached
		get_tree().change_scene_to_file(SCENE)


func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b == null or not b.pressed or b.button_index != MOUSE_BUTTON_RIGHT:
		return
	var cam := get_viewport().get_camera_3d()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(
			cam.project_ray_origin(b.position), cam.project_ray_normal(b.position))
	if hit == null:
		return
	Travel.aim = Travel.site_at(hit, 6.0)
	Travel.dest = Travel.sites[Travel.aim].pos if Travel.aim >= 0 else hit
	get_viewport().set_input_as_handled()

