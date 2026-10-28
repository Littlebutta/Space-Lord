class_name MoveMarker
extends Node3D
## RTS feedback for flying a ship: a soft ring round the ship while right
## click will move it (nobody in the crew picked), a blip that flashes
## where you order it to, and a small marker at the goal until it's there.

const COLOR := Color(0.35, 0.9, 1.0, 0.5)
const FLASH := 0.7  # seconds a blip takes to flash out

var body: ShipBody
var orders: CrewOrders
var _ring := MeshInstance3D.new()
var _goal := MeshInstance3D.new()


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


## Flashes a blip at world point `at`: two quick expanding rings.
func ping(at: Vector2) -> void:
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
	var c := body.world(body.pivot())
	_ring.visible = orders == null or orders.selected().is_empty()
	_ring.global_position = Vector3(c.x, 0.15, c.y)
	_ring.scale = Vector3.ONE * _size()
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.004)
	_ring.scale *= pulse
	_goal.visible = body.goal != null
	if body.goal != null:
		_goal.global_position = Vector3(body.goal.x, 0.2, body.goal.y)


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
