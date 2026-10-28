class_name ShipView
extends Node3D
## Draws a ShipDesign in 3D. Uses each module's Blender model when it
## has one, else a placeholder block. Reused by map and battle later.

const CELL := 2.0  # metres per grid cell
const HEIGHT := {"hull": 0.5, "command": 1.4, "engine": 1.0, "weapon": 1.2}

var design: ShipDesign: set = set_design


func set_design(d: ShipDesign) -> void:
	if design and design.changed.is_connected(rebuild):
		design.changed.disconnect(rebuild)
	design = d
	if design:
		design.changed.connect(rebuild)
	rebuild()


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	if design == null:
		return
	for i in design.modules.size():
		add_child(make_part(design.modules[i], design.rect(i), design.turns[i]))


static func center(r: Rect2i) -> Vector3:
	var c := Vector2(r.position) + Vector2(r.size) * 0.5
	return Vector3(c.x, 0.0, c.y) * CELL


static func make_part(m: ShipModule, r: Rect2i, turn: int) -> Node3D:
	var n: Node3D
	if m.model:
		n = m.model.instantiate()
	else:
		n = MeshInstance3D.new()
		n.mesh = block(m, r.size)
	n.position = center(r)
	n.rotation.y = -turn * PI / 2.0 if m.model else 0.0
	return n


static func block(m: ShipModule, s: Vector2i) -> Mesh:
	var h: float = HEIGHT.get(m.category, 0.9)
	var box := BoxMesh.new()
	box.size = Vector3(s.x * CELL - 0.15, h, s.y * CELL - 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = m.color
	mat.metallic = 0.6
	mat.roughness = 0.45
	box.material = mat
	return box
