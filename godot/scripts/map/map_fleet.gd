extends Node3D
## The player's fleet on the system map, and the sites around it. Left
## click the fleet (its biggest ship stands in for all of them) to select
## it and open its window; click empty space to let go. With it selected,
## right click flies it somewhere or to a site. It moves with game time
## and burns fuel; reaching a site opens its local scene, the trade
## window at a station, or jumps to the next system at a jump point.

const SCENE := "res://scenes/crew/crew_test.tscn"
const COLORS := {&"wreck": Color(1.0, 0.3, 0.2), &"asteroids": Color(0.9, 0.75, 0.45),
		&"station": Color(0.45, 1.0, 0.6), &"jump": Color(0.65, 0.5, 1.0)}

var _ship := MapShip.new()
var _flag := MeshInstance3D.new()  # where we're headed
var _warn := Label3D.new()
var _panel: FleetPanel
var _pings: Array[Node3D] = []
var _labels: Array[Label3D] = []


func _ready() -> void:
	Travel.here = -1
	Travel.make_sites(Travel.system_seed())
	Fleet.refresh()
	_ship.show_design(Fleet.flagship())
	add_child(_ship)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.6
	ring.outer_radius = 2.0
	ring.material = MapGlow.make(Color(0.4, 0.85, 1.0, 0.6))
	_flag.mesh = ring
	add_child(_flag)
	_warn.text = "OUT OF FUEL"
	_warn.modulate = Color(1, 0.35, 0.3)
	_warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_warn.fixed_size = true
	_warn.pixel_size = 0.0008
	add_child(_warn)
	add_child(SosCall.new())
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
	t.inner_radius = 5.2 if s.kind == &"jump" else 4.2
	t.outer_radius = t.inner_radius + 0.6
	t.material = MapGlow.make(COLORS[s.kind])
	ring.mesh = t
	n.add_child(ring)
	n.add_child(MapArt.site(s, COLORS[s.kind]))
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0007
	l.position = Vector3(0, 2, -6.5)
	l.modulate = COLORS[s.kind]
	n.add_child(l)
	add_child(n)
	_pings.append(ring)
	_labels.append(l)


func _process(delta: float) -> void:
	var reached := Fleet.travel(GameClock.SPEEDS[GameClock.speed] * delta)
	_ship.position = Travel.pos + Vector3.UP
	_ship.rotation.y = Travel.heading
	_ship.moving = Travel.dest != null and GameClock.speed > 0
	_warn.visible = Fleet.stranded() and Fleet.sos.is_empty() or _warn.text != "OUT OF FUEL"
	_warn.position = Travel.pos + Vector3(0, 3, -MapShip.SIZE * 0.7)
	_flag.visible = Travel.dest != null
	if _flag.visible:
		_flag.position = Travel.dest
	var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.004)
	for i in _pings.size():
		var s: Dictionary = Travel.sites[i]
		_pings[i].scale = Vector3.ONE * (pulse if s.kind in [&"wreck", &"jump"] else 1.0)
		_labels[i].text = s.name + ("  ore %d" % s.ore if s.kind == &"asteroids" else "")
	Shipyard.docked = not Travel.near_station().is_empty()
	if reached >= 0:
		_arrive(reached)


func _arrive(i: int) -> void:
	var s := Travel.sites[i]
	match s.kind:
		&"station":
			for old in find_children("", "StationPanel", false, false):
				old.queue_free()
			var p := StationPanel.new()
			p.site = s
			add_child(p)
		&"jump":
			if Fleet.tank() < Fleet.JUMP_FUEL:
				_warn.text = "JUMP NEEDS %d FUEL" % Fleet.JUMP_FUEL
				return
			Fleet.fuel -= Fleet.JUMP_FUEL
			Travel.jump(s.to)
			get_tree().reload_current_scene()
		_:
			Travel.here = i
			get_tree().change_scene_to_file(SCENE)


func _select(on: bool) -> void:
	_ship.selected = on
	if on and not is_instance_valid(_panel):
		_panel = FleetPanel.new()
		add_child(_panel)
	elif not on and is_instance_valid(_panel):
		_panel.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b == null or not b.pressed:
		return
	var cam := get_viewport().get_camera_3d()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(
			cam.project_ray_origin(b.position), cam.project_ray_normal(b.position))
	if hit == null:
		return
	if b.button_index == MOUSE_BUTTON_LEFT:
		_select(hit.distance_to(Travel.pos) < MapShip.SIZE * 0.7)
	elif b.button_index == MOUSE_BUTTON_RIGHT and _ship.selected:
		if Fleet.stranded():
			return
		_warn.text = "OUT OF FUEL"
		Travel.aim = Travel.site_at(hit, 6.0)
		Travel.dest = Travel.sites[Travel.aim].pos if Travel.aim >= 0 else hit
	else:
		return
	get_viewport().set_input_as_handled()
