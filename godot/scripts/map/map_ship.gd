class_name MapShip
extends Node3D
## A ship on the system map: its real outside hull shrunk to map size,
## bow along -z, an engine glow while it flies and a ring when selected.

const SIZE := 7.0  # map units the ship's longest side shrinks to

var selected := false: set = set_selected
var moving := false: set = set_moving
var _ring := MeshInstance3D.new()
var _glow := MeshInstance3D.new()


func show_design(d: ShipDesign, col := Color(0.4, 0.85, 1.0)) -> void:
	var box := Rect2(Vector2(d.rect(0).position), Vector2.ZERO)
	for i in d.modules.size():
		box = box.merge(Rect2(Vector2(d.rect(i).position), Vector2(d.rect(i).size)))
	var s := SIZE / (maxf(box.size.x, box.size.y) * ShipView.CELL)
	var v := ShipView.new()
	v.design = d
	v.outside = true
	var mid := box.get_center() * ShipView.CELL
	v.position = -Vector3(mid.x, 0.0, mid.y)
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * s
	holder.add_child(v)
	add_child(holder)
	for l in v.find_children("", "Light3D", true, false):
		l.visible = false  # lamps don't shrink with the model
	var t := TorusMesh.new()
	t.inner_radius = SIZE * 0.62
	t.outer_radius = SIZE * 0.66
	t.material = MapGlow.make(Color(col, 0.7))
	_ring.mesh = t
	_ring.visible = selected
	add_child(_ring)
	var g := SphereMesh.new()
	g.radius = 0.5
	g.height = 1.0
	g.material = MapGlow.make(Color(1.0, 0.6, 0.3, 0.8), 4.0)
	_glow.mesh = g
	_glow.scale = Vector3(1, 1, 3)
	_glow.position = Vector3(0, 0.3, box.size.y * ShipView.CELL * s * 0.5 + 0.8)
	_glow.visible = moving
	add_child(_glow)


func set_selected(v: bool) -> void:
	selected = v
	_ring.visible = v


func set_moving(v: bool) -> void:
	moving = v
	_glow.visible = v
