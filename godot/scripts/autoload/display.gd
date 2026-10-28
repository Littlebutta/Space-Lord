extends CanvasLayer
## Fullscreen on F11 or Alt+Enter, or the ⛶ button bottom right (next to
## "?"). The choice is saved in user://settings.cfg and kept next launch.

const FILE := "user://settings.cfg"

var _btn := Button.new()


func _ready() -> void:
	layer = 100
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	_btn.text = " ⛶ "
	_btn.toggle_mode = true
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.tooltip_text = "Fullscreen (F11)"
	_btn.toggled.connect(set_fullscreen)
	UiKit.pin(self, _btn, Control.PRESET_BOTTOM_RIGHT, Vector2(64, 12))
	_btn.button_pressed = cfg.get_value("display", "fullscreen", false)


func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on
			else DisplayServer.WINDOW_MODE_WINDOWED)
	_btn.set_pressed_no_signal(on)
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("display", "fullscreen", on)
	cfg.save(FILE)


## In _input so a focused button can't swallow Alt+Enter as a click.
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.keycode == KEY_F11
			or k.alt_pressed and k.keycode in [KEY_ENTER, KEY_KP_ENTER]):
		set_fullscreen(not _btn.button_pressed)
		get_viewport().set_input_as_handled()
