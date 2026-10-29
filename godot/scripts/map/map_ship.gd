class_name MapShip
extends Node3D
## A ship on the system map: its real outside hull shrunk to map size,
## bow along -z, engine plumes that spool up while it flies and a ring
## when selected. Plumes sit on the parts' "Nozzle*" markers.

const SIZE := 7.0  # map units the ship's longest side shrinks to
const PLUME := preload("res://assets/materials/map_plume.gdshader")

var selected := false: set = set_selected
var moving := false
var _ring := MeshInstance3D.new()
var _plume := ShaderMaterial.new()
var _plumes: Array[Node3D] = []
var _level := 0.0


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
	_plume.shader = PLUME
	_plume.set_shader_parameter(&"level", 0.0)
	for i in d.modules.size():
		var m := d.modules[i]
		if m.thrust > 0.0 and m.exhaust != Vector2i.ZERO and d.theme(i).id != &"bio":
			v.add_child(_plume_at(m, d.rect(i), d.turns[i]))  # bio swims, no flame


## A cone trailing out of a thruster's exhaust face, in ship units.
func _plume_at(m: ShipModule, r: Rect2i, turn: int) -> Node3D:
	var lane := ShipRules.lane(m, r, turn, 1)
	var dir := (ShipView.center(lane) - ShipView.center(r)).normalized()
	var w := minf(lane.size.x, lane.size.y) * ShipView.CELL
	var c := CylinderMesh.new()
	c.top_radius = w * 0.55
	c.bottom_radius = w * 0.06
	c.height = w * 5.5
	c.radial_segments = 16
	c.material = _plume
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.x = -PI / 2.0  # wide end on the nozzle, tip aft
	mi.position.z = c.height * 0.5
	var root := Node3D.new()
	root.add_child(mi)
	var half := Vector2(r.size) * ShipView.CELL * 0.5
	var at := ShipView.center(r) + dir * (half.x if absf(dir.x) > 0.5 else half.y)
	root.transform = Transform3D(Basis.looking_at(-dir), at + Vector3.UP * 0.9)
	_plumes.append(root)
	return root


func _process(delta: float) -> void:
	_level = move_toward(_level, 1.0 if moving else 0.0, delta * 1.5)
	_plume.set_shader_parameter(&"level", _level)
	var wob := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.03)
	for p in _plumes:
		p.visible = _level > 0.01
		p.scale = Vector3(0.7 + 0.3 * _level, 0.7 + 0.3 * _level, maxf(_level * wob, 0.01))


func set_selected(v: bool) -> void:
	selected = v
	_ring.visible = v
