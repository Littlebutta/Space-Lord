extends Node3D
## Crew sandbox: loads the saved player ship (or a random one) and lets
## the crew run it. X damages a random module, B wrecks one outright so
## the ship can split; crew spacewalk out of an airlock to bring pieces back.

const HELP := "Crew sandbox · X damage · B wreck a module · V outside view" \
		+ " · Alt module cards · Esc map\nLeft click/drag select crew · right click order them" \
		+ " (R releases) · right click with none selected flies the ship" \
		+ "\nWASD pan · middle mouse rotate · wheel zoom · F follow ship\nBlue operating · yellow hauling" \
		+ " · green repairing · pink spacewalk · grey idle"

@onready var _ship: ShipBody = $Ship
@onready var _info: Label = $UI/Info
var _last := Vector2.ZERO  # ship middle last frame, for the camera to follow
var _follow := false  # F: camera rides along with the ship


func _ready() -> void:
	var d := _design()
	_ship.setup(d, maxi(int(d.total(&"berths")), int(d.total(&"crew")) + 2))
	$Panel.bind(_ship.sim)
	$UI/Tags.bind(_ship)
	$UI/Orders.bind(_ship)
	_last = _ship.world(_ship.pivot())
	$Camera.focus = Vector3(_last.x, 0.0, _last.y)


func _design() -> ShipDesign:
	if ResourceLoader.exists("user://ships/player.tres"):
		var d := load("user://ships/player.tres") as ShipDesign
		if d and not d.modules.is_empty():
			return d
	var pool: Array[ShipModule] = ModuleLibrary.all().filter(
			func(m): return m.category != "command")
	var rng := RandomNumberGenerator.new()
	var g := ShipGenerator.generate(ModuleLibrary.by_id(&"bridge"), pool, rng, 16)
	for id in [&"airlock", &"engine", &"fuel_tank"]:
		ShipGenerator.ensure(g, ModuleLibrary.by_id(id), rng)
	return g


func _process(_delta: float) -> void:
	var mid := _ship.world(_ship.pivot())
	if _follow:
		$Camera.focus += Vector3(mid.x - _last.x, 0.0, mid.y - _last.y)
	_last = mid
	var s := _ship.sim.state
	var running := 0
	for i in s.size():
		running += int(s.is_running(i))
	var t := "Modules running %d / %d · speed %.1f m/s" % [running, s.size(),
			_ship.vel.length()]
	t += " · crew lost %d\n" % _ship.sim.lost if _ship.sim.lost else "\n"
	for res in s.storage.capacity:
		t += "%s %.0f / %.0f\n" % [res.capitalize(), s.storage.get_amount(res),
				s.storage.capacity[res]]
	_info.text = t + HELP


func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b and b.pressed and b.button_index == MOUSE_BUTTON_RIGHT:
		var cam: Camera3D = $Camera
		var hit = Plane(Vector3.UP, 0.0).intersects_ray(
				cam.project_ray_origin(b.position), cam.project_ray_normal(b.position))
		if hit != null:
			_ship.goal = Vector2(hit.x, hit.z)
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_X: _ship.sim.state.damage(randi() % _ship.sim.state.size(), 60.0)
		KEY_B: _ship.sim.state.damage(randi() % _ship.sim.state.size(), INF)
		KEY_V: _ship.hulk.outside = not _ship.hulk.outside
		KEY_F: _follow = not _follow
		KEY_ALT: $UI/Tags.visible = not $UI/Tags.visible
		KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/main.tscn")
