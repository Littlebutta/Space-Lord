extends Node
## Gives every screen the UiStyle look, and F1 toggles any "?" help.
## Themes don't pass through CanvasLayers, so each top-level Control of
## a layer gets the theme as it enters the tree.

var theme := UiStyle.build()


func _ready() -> void:
	get_tree().root.theme = theme
	get_tree().node_added.connect(_skin)


func _skin(n: Node) -> void:
	if n is Control and not n.get_parent() is Control and n.theme == null:
		n.theme = theme


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F1:
		for b in get_tree().get_nodes_in_group(&"help"):
			b.button_pressed = not b.button_pressed
