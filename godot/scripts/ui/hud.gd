extends CanvasLayer
## Map HUD: a small clock with time controls at the top, a few screen
## buttons bottom-left, and the controls behind "?" (F1).

const HELP := "Space pause · 1/2 speed · WASD pan · middle mouse drag rotate\n" \
		+ "Wheel zoom · B builder (refits near a station) · C crew · V battle\n" \
		+ "Right click fly your ship there, or to a wreck, asteroid or station ping"
const SCREENS := {"Builder": KEY_B, "Crew": KEY_C, "Battle": KEY_V}

var _clock := Label.new()
var _speed: Array[Button] = []


func _ready() -> void:
	var bar := PanelContainer.new()
	var row := HBoxContainer.new()
	bar.add_child(row)
	_clock.custom_minimum_size.x = 210
	row.add_child(_clock)
	for i in GameClock.NAMES.size():
		var b := Button.new()
		b.text = ["❚❚", "▶", "▶▶"][i]
		b.tooltip_text = GameClock.NAMES[i]
		b.toggle_mode = true
		b.pressed.connect(func(): GameClock.speed = i)
		row.add_child(b)
		_speed.append(b)
	UiKit.pin(self, bar, Control.PRESET_CENTER_TOP)
	var nav := HBoxContainer.new()
	for s in SCREENS:
		var b := Button.new()
		b.text = s
		b.pressed.connect(_open.bind(SCREENS[s]))
		nav.add_child(b)
	UiKit.pin(self, nav, Control.PRESET_BOTTOM_LEFT)
	UiKit.help(self, HELP)


func _process(_delta: float) -> void:
	_clock.text = "DAY %d   %02d:00   %d cr" % [GameClock.day(),
			int(GameClock.hours) % 24, Wallet.credits]
	for i in _speed.size():
		_speed[i].set_pressed_no_signal(GameClock.speed == i)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		_open(key.keycode)


func _open(k: Key) -> void:
	match k:
		KEY_B:
			Shipyard.docked = not Travel.near_station().is_empty()
			get_tree().change_scene_to_file("res://scenes/ship_editor/ship_editor.tscn")
		KEY_C: get_tree().change_scene_to_file("res://scenes/crew/crew_test.tscn")
		KEY_V: get_tree().change_scene_to_file("res://scenes/combat/battle.tscn")
