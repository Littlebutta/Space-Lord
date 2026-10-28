extends Node
## Gives every screen the UiStyle look, and F1 toggles any "?" help.


func _ready() -> void:
	get_tree().root.theme = UiStyle.build()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F1:
		for b in get_tree().get_nodes_in_group(&"help"):
			b.button_pressed = not b.button_pressed
