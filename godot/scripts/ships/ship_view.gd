class_name ShipView
extends Node3D
## Draws a ShipDesign in 3D. Every part sits on one flush hull deck, so
## the ship reads as a single hull and crew can walk all of it. Themes
## only shape the deck's outer corners and the detail on top: a module's
## Blender model when it has one, else a toon-shaded placeholder.
## Reused by map and battle later.

const CELL := 2.0  # metres per grid cell
const DECK := 0.5  # hull deck thickness, the same for every part
const HULL_COLOR := Color(0.55, 0.57, 0.6)
const HEIGHT := {"hull": 0.5, "command": 1.4, "engine": 1.0, "weapon": 1.2}
const TOON := preload("res://assets/materials/toon.gdshader")

static var _mats := {}  # Color -> shared material, keeps draw calls low

var design: ShipDesign: set = set_design
var show_exhaust := false  # builder hint: tint thruster lanes
var outside := false: set = set_outside  # hull shell over the decks
var _hull: MeshInstance3D  # the outside shell


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
	var filled := design.occupied()
	for i in design.modules.size():
		var m := design.modules[i]
		var r := design.rect(i)
		var n := make_part(m, r, design.turns[i], design.theme(i), filled)
		ModelSkin.set_outside(n, outside)
		add_child(n)
		var l: MeshInstance3D = lane_mesh(m, r, design.turns[i]) if show_exhaust else null
		if l:
			add_child(l)
	if not design.modules.is_empty():
		_hull = _shell()
		add_child(_hull)


func set_outside(v: bool) -> void:
	outside = v
	for c in get_children():
		ModelSkin.set_outside(c, v)
	if is_instance_valid(_hull):
		_hull.visible = v


## The continuous outside hull, shown in outside view.
func _shell() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = &"Shell"
	mi.mesh = HullShell.build(design, DECK * 0.5)
	mi.material_override = ModelSkin.cut_shell(design.theme(0), HullShell.holes(design))
	mi.add_child(HullShell.beacons(design, DECK * 0.5))
	mi.visible = outside
	return mi


static func center(r: Rect2i) -> Vector3:
	var c := Vector2(r.position) + Vector2(r.size) * 0.5
	return Vector3(c.x, 0.0, c.y) * CELL


## `filled` is ShipDesign.occupied(), used to round only outer corners.
static func make_part(m: ShipModule, r: Rect2i, turn: int, t: ShipTheme,
		filled := {}) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = part_mesh(m, r, turn, t, filled)
	var hull := m.color if m.category == "hull" else HULL_COLOR
	var deck := hull.lerp(t.tint, t.tint_mix * 0.5)  # subtle, so hulls blend
	mi.set_surface_override_material(0, toon(deck))
	if mi.mesh.get_surface_count() > 1:
		mi.set_surface_override_material(1, toon(t.paint(m.color)))
	var scene := t.model(m)
	if scene:
		var model: Node3D = scene.instantiate()
		ModelSkin.apply(model, t)
		if t.glass_parts.has(m.id):
			mi.set_meta(&"glass", true)
		mi.set_surface_override_material(0, ModelSkin.deck_material())
		if m.exterior:  # the model is the whole part: no placeholder
			mi.mesh = null
		model.rotation.y = -turn * PI / 2.0
		model.position.y = DECK * 0.5
		mi.add_child(model)
	mi.position = center(r)
	return mi


## Deck slab (surface 0) plus, for non-hull parts without a model, a
## themed detail block on top (surface 1). Centred on the footprint.
static func part_mesh(m: ShipModule, r: Rect2i, turn: int, t: ShipTheme,
		filled := {}) -> ArrayMesh:
	var p := Prism.footprint(m, turn)
	var mesh := ArrayMesh.new()
	if m.exterior:  # no deck: just the part, standing from deck level
		_slab(mesh, _local(p, r), -DECK * 0.5, m.height - DECK * 0.5, m.taper)
		return mesh
	var deck := Prism.round_corners(p, r, filled, t.corner, t.corner_steps)
	_slab(mesh, _local(deck, r), -DECK * 0.5, DECK * 0.5, 0.0)
	var h: float = (m.height if m.height > 0.0 else HEIGHT.get(m.category, 0.9)) * t.height
	h *= 1.0 + t.jitter * (absi(hash(r.position)) % 100 / 100.0 - 0.5)
	if m.category != "hull" and not t.model(m) and h > DECK + 0.05:
		var top := Prism.shrink(p, 0.2)
		_slab(mesh, _local(t.shape(top), r), DECK * 0.5, h - DECK * 0.5, t.taper)
	return mesh


## Cell-unit polygon -> metres around the footprint centre.
static func _local(p: PackedVector2Array, r: Rect2i) -> PackedVector2Array:
	var half := Vector2(r.size) * 0.5
	var out := PackedVector2Array()
	for v in p:
		out.append((v - half) * CELL)
	return out


static func _slab(mesh: ArrayMesh, p: PackedVector2Array, y0: float, y1: float,
		taper: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Prism.add(st, p, y0, y1, taper)
	st.commit(mesh)


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
