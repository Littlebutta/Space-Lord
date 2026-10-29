extends Node
## In-game calendar. Like Bannerlord's campaign map, time can be paused
## or sped up, and everything on the map reads `hours` from here.

signal hour_passed(hour: int)
signal speed_changed(speed: int)

const SPEEDS := [0.0, 2.0, 8.0]  # game hours per real second
const NAMES := ["Paused", "Normal", "Fast"]

var hours := 0.0
var speed := 1: set = set_speed


func _process(delta: float) -> void:
	var before := int(hours)
	hours += SPEEDS[speed] * delta
	for h in range(before + 1, int(hours) + 1):
		hour_passed.emit(h)


func set_speed(value: int) -> void:
	speed = clampi(value, 0, SPEEDS.size() - 1)
	speed_changed.emit(speed)


func day() -> int:
	return int(hours / 24.0) + 1


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE: speed = 0 if speed > 0 else 1
		KEY_1: speed = 1
		KEY_2: speed = 2
