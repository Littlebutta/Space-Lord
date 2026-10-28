class_name BuildAids
extends RefCounted
## Builder helpers: the see-through hologram of the part being placed
## (its full model, so rotation and mirroring read at a glance) and the
## build grid, which grows with the ship.

const HOLO := preload("res://assets/materials/hologram.gdshader")
const OK_TINT := Color(0.3, 1.0, 0.6)
const BAD_TINT := Color(1.0, 0.3, 0.25)


## The whole part as a hologram, centred on its footprint at the origin.
## Returns the node; its "mat" meta holds the material to tint.
static func hologram(m: ShipModule, turn: int, t: ShipTheme) -> Node3D:
	var r := Rect2i(Vector2i.ZERO, ShipDesign.turned(m, turn))
	var n := ShipView.make_part(m, r, turn, t)
	var holder := Node3D.new()
	holder.add_child(n)
	n.position = Vector3.ZERO
	var mat := ShaderMaterial.new()
	mat.shader = HOLO
	_skin(n, mat)
	holder.set_meta(&"mat", mat)
	var lane := ShipView.lane_mesh(m, r, turn)
	if lane:
		lane.position -= ShipView.center(r)
		holder.add_child(lane)
	return holder


static func tint(holo: Node3D, ok: bool) -> void:
	(holo.get_meta(&"mat") as ShaderMaterial).set_shader_parameter(
			&"tint", OK_TINT if ok else BAD_TINT)


static func _skin(n: Node, mat: Material) -> void:
	if n is GeometryInstance3D:
		n.material_override = mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif n is Light3D:
		n.visible = false
	for c in n.get_children():
		_skin(c, mat)


## Cells to cover: the ship and the cursor with room around them.
static func grid_need(d: ShipDesign, cursor: Vector2i) -> Rect2i:
	var r := Rect2i(-10, -10, 20, 20).expand(cursor - Vector2i(4, 4)).expand(cursor + Vector2i(5, 5))
	for i in d.modules.size():
		r = r.merge(d.rect(i).grow(6))
	return r


## Faint grid lines over cell rect `r`; `axis` adds the bright x = 0
## mirror line used by symmetry building.
static func grid_mesh(r: Rect2i, axis: bool) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat(Color(0.3, 0.5, 0.8, 0.45)))
	var c := ShipView.CELL
	for x in range(r.position.x, r.end.x + 1):
		im.surface_add_vertex(Vector3(x * c, 0, r.position.y * c))
		im.surface_add_vertex(Vector3(x * c, 0, r.end.y * c))
	for y in range(r.position.y, r.end.y + 1):
		im.surface_add_vertex(Vector3(r.position.x * c, 0, y * c))
		im.surface_add_vertex(Vector3(r.end.x * c, 0, y * c))
	im.surface_end()
	if axis:
		im.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat(UiStyle.ACCENT))
		im.surface_add_vertex(Vector3(0, 0.02, r.position.y * c))
		im.surface_add_vertex(Vector3(0, 0.02, r.end.y * c))
		im.surface_end()
	return im


static func _line_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
