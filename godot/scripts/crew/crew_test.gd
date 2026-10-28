extends Node3D
## Crew sandbox: loads the saved player ship (or a random one) and lets
## the crew run it. X damages a random module, B wrecks one outright so
## the ship can split; crew spacewalk out of an airlock to bring pieces back.

const HELP := "X damage · B wreck a module · F fire · V outside view · Alt or H module cards\n" \
		+ "Left click/drag select crew · right click order them (R releases)\n" \
		+ "Click your ship, then right click to fly it · E stop · Space follow ship\n" \
		+ "WASD pan · middle drag rotate · wheel zoom · Esc map\n" \
		+ "Blue operating · yellow hauling · green repairing · pink spacewalk · grey idle"

@onready var _ship: ShipBody = $Ship
@onready var _info: Label = $UI/Info
var _marker := MoveMarker.new()
var _last := Vector2.ZERO  # ship middle last frame, for the camera to follow
var _follow := false  # Space: camera rides along with the ship
var _site := ""  # what's here, from the map site we arrived at


func _ready() -> void:
	var d := SiteScene.prepare(_design())
	_ship.setup(d, maxi(int(d.total(&"berths")), int(d.total(&"crew")) + 2))
	$Panel.bind(_ship.sim)
	$UI/Tags.bind(_ship)
	$UI/Orders.bind(_ship)
	add_child(_marker)
	_marker.bind(_ship, $UI/Orders)
	_site = SiteScene.spawn(self, _ship)
	_last = _ship.world(_ship.pivot())
	_hud()
	$Camera.focus = Vector3(_last.x, 0.0, _last.y)


func _design() -> ShipDesign:
	if ResourceLoader.exists("user://ships/player.tres"):
		var d := load("user://ships/player.tres") as ShipDesign
		if d and not d.modules.is_empty():
			return d
	return ShipGenerator.sandbox(randi())


func _process(_delta: float) -> void:
	var mid := _ship.world(_ship.pivot())
	if _follow:
		$Camera.focus += Vector3(mid.x - _last.x, 0.0, mid.y - _last.y)
	_last = mid
	var s := _ship.sim.state
	var running := 0
	for i in s.size():
		running += int(s.is_running(i))
	var t := _site + "\n" if _site else ""
	t += "Modules running %d / %d · speed %.1f m/s" % [running, s.size(),
			_ship.vel.length()]
	t += " · crew lost %d\n" % _ship.sim.lost if _ship.sim.lost else "\n"
	for res in s.storage.capacity:
		t += "%s %.0f / %.0f\n" % [res.capitalize(), s.storage.get_amount(res),
				s.storage.capacity[res]]
	_info.text = t.strip_edges()


## Status card bottom-left with a cards toggle; controls behind "?".
func _hud() -> void:
	var card := PanelContainer.new()
	var box := VBoxContainer.new()
	card.add_child(box)
	_info.reparent(box)
	_info.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var cards := Button.new()
	cards.text = "Module cards (Alt)"
	cards.toggle_mode = true
	cards.button_pressed = true
	cards.toggled.connect(func(on): $UI/Tags.visible = on)
	$UI/Tags.visibility_changed.connect(
			func(): cards.set_pressed_no_signal($UI/Tags.visible))
	box.add_child(cards)
	UiKit.pin($UI, card, Control.PRESET_BOTTOM_LEFT)
	UiKit.help($UI, HELP)


## Alt (or H) toggles the module cards. Caught in _input, before any
## focused button or the OS menu key handling can swallow it.
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.keycode == KEY_ALT \
			or k.physical_keycode == KEY_ALT or k.keycode == KEY_H):
		$UI/Tags.visible = not $UI/Tags.visible
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b and b.pressed and b.button_index == MOUSE_BUTTON_RIGHT and $UI/Orders.ship_selected:
		var cam: Camera3D = $Camera
		var hit = Plane(Vector3.UP, 0.0).intersects_ray(
				cam.project_ray_origin(b.position), cam.project_ray_normal(b.position))
		if hit != null:
			_ship.goal = Vector2(hit.x, hit.z)
			_marker.ping(_ship.goal)
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_E: _ship.halt()
		KEY_X: _ship.sim.state.damage(randi() % _ship.sim.state.size(), 60.0)
		KEY_B: _ship.sim.state.damage(randi() % _ship.sim.state.size(), INF)
		KEY_V: _ship.hulk.outside = not _ship.hulk.outside
		KEY_F: _fire()
		KEY_SPACE: _follow = not _follow
		KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/main.tscn")


## Every working weapon fires once, a little staggered.
func _fire() -> void:
	var s := _ship.sim.state
	var k := 0
	for i in s.size():
		if s.module(i).firepower > 0.0 and s.can_shoot(i):
			get_tree().create_timer(0.12 * k).timeout.connect(s.shoot.bind(i))
			k += 1
