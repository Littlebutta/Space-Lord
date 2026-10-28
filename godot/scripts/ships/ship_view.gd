class_name ShipView
extends Node3D
## Draws a ShipDesign in 3D. Uses each module's Blender model when it
## has one, else a toon-shaded placeholder prism shaped by its theme.
## Reused by map and battle later.

const CELL := 2.0  # metres per grid cell
const HEIGHT := {"hull": 0.5, "command": 1.4, "engine": 1.0, "weapon": 1.2}
const TOON := preload("res://assets/materials/toon.gdshader")

static var _mats := {}  # Color -> shared material, keeps draw calls low

var design: ShipDesign: set = set_design
var show_exhaust := false  # builder hint: tint thruster lanes


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
		var m := design.modules[i]
		var r := design.rect(i)
		add_child(make_part(m, r, design.turns[i], design.theme(i)))
		var l: MeshInstance3D = lane_mesh(m, r, design.turns[i]) if show_exhaust else null
		if l:
			add_child(l)


static func center(r: Rect2i) -> Vector3:
	var c := Vector2(r.position) + Vector2(r.size) * 0.5
	return Vector3(c.x, 0.0, c.y) * CELL


static func make_part(m: ShipModule, r: Rect2i, turn: int, t: ShipTheme) -> Node3D:
	var n: Node3D
	if m.model:
		n = m.model.instantiate()
		n.rotation.y = -turn * PI / 2.0
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = part_mesh(m, r, turn, t)
		mi.material_override = toon(t.paint(m.color))
		n = mi
	n.position = center(r)
	return n


## Placeholder prism for `m`, centred on its footprint.
static func part_mesh(m: ShipModule, r: Rect2i, turn: int, t: ShipTheme) -> Mesh:
	var h: float = HEIGHT.get(m.category, 0.9) * t.height
	h *= 1.0 + t.jitter * (absi(hash(r.position)) % 100 / 100.0 - 0.5)
	var p := Prism.footprint(m, turn)
	var half := Vector2(r.size) * 0.5
	for k in p.size():
		p[k] = (p[k] - half) * CELL
	return Prism.build(t.shape(p), h, t.taper)


static func toon(c: Color) -> Material:
	if not _mats.has(c):
		var mat := ShaderMaterial.new()
		mat.shader = TOON
		mat.set_shader_parameter("albedo", c)
		_mats[c] = mat
	return _mats[c]


## Faint strip over the first cells of a thruster's exhaust lane.
static func lane_mesh(m: ShipModule, r: Rect2i, turn: int) -> MeshInstance3D:
	var l := ShipRules.lane(m, r, turn, 3)
	if l.size == Vector2i.ZERO:
		return null
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.55, 0.15, 0.25)
	var plane := PlaneMesh.new()
	plane.size = Vector2(l.size) * CELL
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = center(l) + Vector3.UP * 0.02
	return mi
