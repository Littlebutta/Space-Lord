extends CanvasLayer
## Minimal map HUD: date, time speed and controls.

const HELP := "Space pause · 1/2 speed · WASD pan · Q/E rotate · wheel zoom"

@onready var _label: Label = $Label


func _process(_delta: float) -> void:
	var hour := int(GameClock.hours) % 24
	_label.text = "Day %d  %02d:00  [%s]\n%s" % [
			GameClock.day(), hour, GameClock.NAMES[GameClock.speed], HELP]
