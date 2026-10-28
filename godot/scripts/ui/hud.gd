extends CanvasLayer
## Minimal map HUD: date, time speed and controls.

const HELP := "Space pause · 1/2 speed · WASD pan · middle mouse rotate · wheel zoom · B builder at shipyard · N builder in space · C crew"

@onready var _label: Label = $Label


func _process(_delta: float) -> void:
	var hour := int(GameClock.hours) % 24
	_label.text = "Day %d  %02d:00  [%s]\n%s" % [
			GameClock.day(), hour, GameClock.NAMES[GameClock.speed], HELP]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	match key.keycode:
		KEY_B, KEY_N:  # no stations yet, so the key picks where you are
			Shipyard.docked = key.keycode == KEY_B
			get_tree().change_scene_to_file("res://scenes/ship_editor/ship_editor.tscn")
		KEY_C: get_tree().change_scene_to_file("res://scenes/crew/crew_test.tscn")
