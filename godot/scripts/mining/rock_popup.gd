class_name RockPopup
extends PanelContainer
## The card shown when you left click an asteroid: what's in it, how far
## the nearest Mining Laser is, and a button to target (or stop) it.

var field: MiningField
var rock := -1
var _text := Label.new()
var _go := Button.new()


func _ready() -> void:
	visible = false
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(_text)
	var row := HBoxContainer.new()
	box.add_child(row)
	_go.pressed.connect(_toggle)
	row.add_child(_go)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): rock = -1; visible = false)
	row.add_child(close)


func open(k: int) -> void:
	rock = k
	visible = true


func _toggle() -> void:
	field.target = -1 if field.target == rock else rock


func _process(_delta: float) -> void:
	if rock < 0:
		return
	var t := "Asteroid\n"
	for m in Materials.ALL:
		t += "%s  %.0f\n" % [m.capitalize(), field.rocks[rock].left.get(m, 0.0)]
	var near := INF
	var st := field.ship.sim.state
	for i in st.size():
		if st.module(i).mining > 0.0 and st.hp[i] > 0.0:
			near = minf(near, field.reach(i, rock))
	if near == INF:
		t += "No Mining Laser aboard"
	else:
		t += "In range (%.0f m)" % near if near < MiningField.RANGE \
				else "Out of range: %.0f m, laser reaches %.0f" % [near, MiningField.RANGE]
	_text.text = t
	_go.text = "Stop mining" if field.target == rock else "Target"
	var cam := get_viewport().get_camera_3d()
	var at: Vector3 = field.rocks[rock].node.position
	if cam and not cam.is_position_behind(at):
		position = cam.unproject_position(at) + Vector2(30, -size.y * 0.5)
