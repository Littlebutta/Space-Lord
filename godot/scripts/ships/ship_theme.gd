class_name ShipTheme
extends Resource
## A purely visual style any part can wear (human, bio, crystal...):
## a colour and a placeholder shape. Themes never change stats. They
## are .tres files under res://data/themes, so new ones need no code.

const DIR := "res://data/themes/"

@export var id: StringName
@export var display_name := ""
@export var order := 0  # position in the builder's list
@export var blurb := ""  # one line shown in the builder
@export var tint := Color.WHITE
@export var tint_mix := 0.3  # how much tint replaces the part colour
@export var accent := Color(0.25, 0.45, 0.8)  # faction stripes on models
@export var grime := 0.2  # dirt and stains on models, 0..1
@export var wear := 0.15  # chipped paint on edges, 0..1
@export var bump := 0.12  # fine surface bumpiness
@export_group("Hull edge")
@export var corner := 0.0  # outer hull corners cut this far, in cells
@export var corner_steps := 1  # 1 = straight chamfer, more = rounder
@export_group("Detail shape")
@export var bevel := 0.0  # cut corners this far along each edge
@export var smooth := 0  # extra corner rounding passes
@export var taper := 0.0  # shrink the top face toward the centre
@export var height := 1.0
@export var jitter := 0.0  # random height change per part
@export_group("Models")
## Folder of Blender .glb parts named by module id, e.g. hull.glb.
## Parts without a file fall back to the placeholder shape.
@export_dir var model_dir := ""

static var _all: Array[ShipTheme] = []
var _models := {}  # module id -> PackedScene or null


static func all() -> Array[ShipTheme]:
	if _all.is_empty():
		for f in ResourceLoader.list_directory(DIR):
			var t := load(DIR + f) as ShipTheme
			if t:
				_all.append(t)
		_all.sort_custom(func(a, b): return a.order < b.order)
	return _all


## The theme with `tid`, or the first one (human) if unknown.
static func by_id(tid: StringName) -> ShipTheme:
	for t in all():
		if t.id == tid:
			return t
	return all()[0]


func paint(c: Color) -> Color:
	return c.lerp(tint, tint_mix)


func shape(p: PackedVector2Array) -> PackedVector2Array:
	if bevel > 0.0:
		p = Prism.cut(p, bevel)
	for k in smooth:
		p = Prism.cut(p, 0.25)
	return p


## This theme's Blender model for `m`, or null to use the placeholder.
func model(m: ShipModule) -> PackedScene:
	if model_dir.is_empty():
		return m.model
	if not _models.has(m.id):
		var p := model_dir.path_join(String(m.id) + ".glb")
		_models[m.id] = load(p) if ResourceLoader.exists(p) else m.model
	return _models[m.id]
