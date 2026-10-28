extends CanvasLayer
## Map HUD: a small clock with time controls at the top, a few screen
## buttons bottom-left, and the controls behind "?" (F1).

const HELP := "Space pause · 1/2 speed · WASD pan · middle mouse drag rotate\n" \
		+ "Wheel zoom · B builder at shipyard · N builder in space · C crew"
const SCREENS := {"Builder": KEY_B, "Refit in space": KEY_N, "Crew": KEY_C}

var _clock := Label.new()
var _speed: Array[Button] = []


func _ready() -> void:
	var bar := PanelContainer.new()
	var row := HBoxContainer.new()
	bar.add_child(row)
	_clock.custom_minimum_size.x = 150
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
	_clock.text = "DAY %d   %02d:00" % [GameClock.day(), int(GameClock.hours) % 24]
	for i in _speed.size():
		_speed[i].set_pressed_no_signal(GameClock.speed == i)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		_open(key.keycode)


func _open(k: Key) -> void:
	match k:
		KEY_B, KEY_N:  # no stations yet, so the key picks where you are
			Shipyard.docked = k == KEY_B
			get_tree().change_scene_to_file("res://scenes/ship_editor/ship_editor.tscn")
		KEY_C: get_tree().change_scene_to_file("res://scenes/crew/crew_test.tscn")
