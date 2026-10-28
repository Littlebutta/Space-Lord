extends Node
## A soft click on every button press in any menu or panel, added as
## buttons appear. One player, so fast clicking never stacks up.

var _player := AudioStreamPlayer.new()


func _ready() -> void:
	_player.stream = Sfx.stream(&"ui_click")
	_player.volume_db = -8.0
	add_child(_player)
	get_tree().node_added.connect(_on_node)


func _on_node(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).pressed.connect(_click)


func _click() -> void:
	_player.play()
