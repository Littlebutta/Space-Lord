extends Node3D
## Crew sandbox: loads the saved player ship (or a random one) and lets
## the crew run it. X damages a random module, Esc returns to the map.

const HELP := "Crew sandbox · X damage a module · WASD/QE/wheel camera · Esc map\n" \
		+ "Blue operating · yellow hauling · green repairing · grey idle"

@onready var _sim: CrewSim = $CrewSim
@onready var _info: Label = $UI/Info
var _tags: Array[Label3D] = []


func _ready() -> void:
	var d := _design()
	_sim.setup(d, maxi(int(d.total(&"berths")), 4))
	$Panel.bind(_sim)
	$ShipView.design = d
	var box := Rect2(d.rect(0))
	for i in d.modules.size():
		box = box.merge(Rect2(d.rect(i)))
	var mid := box.get_center() * ShipView.CELL
	$Camera.focus = Vector3(mid.x, 0.0, mid.y)
	for i in d.modules.size():
		var t := Label3D.new()
		t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		t.font_size = 32
		t.pixel_size = 0.008
		t.outline_size = 8
		t.position = ShipView.center(d.rect(i)) + Vector3.UP * 1.5
		add_child(t)
		_tags.append(t)


func _design() -> ShipDesign:
	if ResourceLoader.exists("user://ships/player.tres"):
		var d := load("user://ships/player.tres") as ShipDesign
		if d and not d.modules.is_empty():
			return d
	var pool: Array[ShipModule] = ModuleLibrary.all().filter(
			func(m): return m.category != "command")
	return ShipGenerator.generate(ModuleLibrary.by_id(&"bridge"), pool,
			RandomNumberGenerator.new(), 16)


func _process(_delta: float) -> void:
	var s := _sim.state
	var running := 0
	for i in s.size():
		running += int(s.is_running(i))
		_tags[i].text = _tag(i)
	var t := "Modules running %d / %d\n" % [running, s.size()]
	for res in s.storage.capacity:
		t += "%s %.0f / %.0f\n" % [res.capitalize(), s.storage.get_amount(res),
				s.storage.capacity[res]]
	_info.text = t + HELP


func _tag(i: int) -> String:
	var s := _sim.state
	var m := s.module(i)
	var t := ""
	if m.crew > 0:
		t += "crew %d/%d " % [mini(s.operators[i], m.crew), m.crew]
	for res in m.upkeep:
		t += "%s %d%% " % [res, roundi(100.0 * s.stock[i][res] / s.buffer(i, res))]
	if s.damaged(i):
		t += "hp %d%%" % roundi(100.0 * s.hp[i] / m.hp)
	return t.strip_edges()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_X: _sim.state.damage(randi() % _sim.state.size(), 60.0)
		KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/main.tscn")
