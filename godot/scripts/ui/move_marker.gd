class_name MoveMarker
extends Node3D
## RTS feedback for flying a ship: a soft ring round the ship while right
## click will move it (the ship is selected), a blip that flashes
## where you order it to, and a small marker at the goal until it's there.
## Holding right click and dragging away sets which way the ship should
## face once there, with a ghost of the ship showing the end pose.

const COLOR := Color(0.35, 0.9, 1.0, 0.5)
const FLASH := 0.7  # seconds a blip takes to flash out
const DRAG := 3.0  # metres of right-drag before it sets a facing

var body: ShipBody
var orders: CrewOrders
var _ring := MeshInstance3D.new()
var _goal := MeshInstance3D.new()
var _from: Variant = null  # world point a held right-click order started at
var _ghost := ShipGhost.new()


func bind(b: ShipBody, o: CrewOrders) -> void:
	body = b
	orders = o
	top_level = true
	_ring.mesh = _torus(1.0, 0.06)
	_goal.mesh = _torus(0.6, 0.08)
	for m: MeshInstance3D in [_ring, _goal]:
		m.material_override = FxKit.glow_mat(COLOR, false)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	add_child(_ghost)
	_ghost.visible = false


## Starts a move order to world point `at`; it is given on release.
func press(at: Vector2) -> void:
	_from = at
	_ghost.copy(body)


## Flashes a blip at world point `at`: two quick expanding rings.
func ping(at: Vector2) -> void:
	Sfx.flat(&"order_move", -8.0)
	for k in 2:
		var m := MeshInstance3D.new()
		m.mesh = _torus(1.0, 0.1)
		m.material_override = FxKit.glow_mat(COLOR, false).duplicate()
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		m.global_position = Vector3(at.x, 0.2, at.y)
		m.scale = Vector3.ONE * 0.3
		var tw := m.create_tween().set_parallel()
		tw.tween_interval(0.18 * k)
		tw.chain().tween_property(m, "scale", Vector3.ONE * 2.5, FLASH)
		tw.tween_property(m.material_override, "albedo_color:a", 0.0, FLASH)
		tw.chain().tween_callback(m.queue_free)


func _process(_delta: float) -> void:
	if body == null or body.sim == null:
		return
	if _from != null:
		_drag()
	var c := body.world(body.pivot())
	_ring.visible = orders == null or orders.ship_selected
	_ring.global_position = Vector3(c.x, 0.15, c.y)
	_ring.scale = Vector3.ONE * _size()
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.004)
	_ring.scale *= pulse
	_goal.visible = body.goal != null
	if body.goal != null:
		_goal.global_position = Vector3(body.goal.x, 0.2, body.goal.y)


## While right click is held, shows the ghost facing the mouse; on
## release sends the ship there, facing that way if dragged far enough.
func _drag() -> void:
	var to: Variant = _mouse()
	var dir: Vector2 = to - _from if to != null else Vector2.ZERO
	var aim := dir.length() > DRAG
	_ghost.visible = aim
	if aim:
		_ghost.place(body, _from, dir)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
	body.goal = _from
	body.heading = dir if aim else null
	ping(_from)
	_from = null
	_ghost.visible = false


## World point under the mouse on the y = 0 plane, or null.
func _mouse() -> Variant:
	var cam := get_viewport().get_camera_3d()
	var m := get_viewport().get_mouse_position()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(
			cam.project_ray_origin(m), cam.project_ray_normal(m)) if cam else null
	return Vector2(hit.x, hit.z) if hit != null else null


## Radius that clears the ship's own piece.
func _size() -> float:
	var s := body.sim.state
	var p := s.pieces
	var r := 2.0
	if p.main >= 0:
		for i in p.pieces[p.main]:
			r = maxf(r, s.center(i).distance_to(body.pivot()) + 2.0)
	return r


static func _torus(r: float, w: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = r - w
	t.outer_radius = r + w
	t.rings = 48
	t.ring_segments = 6
	return t
