class_name CrewOrders
extends Control
## RTS crew control. Left click picks a crew member (Shift adds, drag a
## box for several), right click on the deck sends them there, or to
## work the module clicked if it has an open job. R puts the selected
## crew back on their usual duties. Right click with nobody selected is
## left to the scene (e.g. to fly the ship).

const PICK := 18.0  # pixels from a crew member that still picks them
const DRAG := 6.0  # pixels moved before a click becomes a box

var body: ShipBody
var _from := Vector2.ZERO
var _down := false
var _box := Rect2()


func bind(b: ShipBody) -> void:
	body = b
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func selected() -> Array[CrewMember]:
	return body.sim.crew.filter(func(c): return c.selected)


func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b and b.button_index == MOUSE_BUTTON_LEFT:
		if b.pressed:
			_down = true
			_from = b.position
		elif _down:
			_down = false
			_pick(Rect2(_from, Vector2.ZERO).expand(b.position), b.shift_pressed)
			_box = Rect2()
			queue_redraw()
		get_viewport().set_input_as_handled()
	elif b and b.pressed and b.button_index == MOUSE_BUTTON_RIGHT and not selected().is_empty():
		var at = _deck(b.position)
		if at != null:
			for c in selected():
				order(body.sim, c, at)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _down:
		var r := Rect2(_from, Vector2.ZERO).expand(event.position)
		_box = r if r.size.length() > DRAG else Rect2()
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		for c in selected():
			release(body.sim, c)


func _pick(r: Rect2, add: bool) -> void:
	var cam := get_viewport().get_camera_3d()
	var box := r.size.length() > DRAG
	var best: CrewMember = null
	var best_d := PICK
	for c in body.sim.crew:
		var w := body.sim.global_transform * body.sim.local3d(c)
		var s := cam.unproject_position(w + Vector3.UP * 0.9)
		if not add:
			c.selected = false
		if box and r.has_point(s):
			c.selected = true
		elif not box and s.distance_to(r.position) < best_d:
			best = c
			best_d = s.distance_to(r.position)
	if best:
		best.selected = not best.selected if add else true


## Ship-local deck point under the mouse, or null.
func _deck(at: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	var inv := body.global_transform.affine_inverse()
	var o := inv * cam.project_ray_origin(at)
	var n := inv.basis * cam.project_ray_normal(at)
	var hit = Plane(Vector3.UP, ShipView.DECK * 0.5).intersects_ray(o, n)
	return Vector2(hit.x, hit.z) if hit != null else null


func _draw() -> void:
	if _box.has_area():
		draw_rect(_box, Color(0.4, 0.8, 1.0, 0.12))
		draw_rect(_box, Color(0.4, 0.8, 1.0, 0.8), false, 1.0)


## Work the module at `at` (ship-local) if it has an open job, else walk
## there and wait. They hold the order until released.
static func order(sim: CrewSim, c: CrewMember, at: Vector2) -> void:
	if c.eva or c.strand >= 0.0:
		return
	sim.drop(c)
	c.order = true
	var i := sim.state.design.index_at(Vector2i((at / ShipView.CELL).floor()))
	var j := sim.board.open_job(i)
	if j:
		j.worker = c
		c.job = j
	elif sim.nav.walkable(at) and sim.nav.connected(c.pos, at):
		c.path = sim.nav.route(c.pos, at)


static func release(sim: CrewSim, c: CrewMember) -> void:
	if c.order:
		c.order = false
		sim.drop(c)
