extends Node3D
## Grid ship builder. Left click places the picked module in the picked
## theme, right click removes, middle click repaints, R rotates, Esc
## returns to the system map. ShipRules blocks bad placements, and out in
## space without a Shipdock only crew repairs are allowed (see Shipyard).

const SAVE_PATH := "user://ships/player.tres"
const MAP_SCENE := "res://scenes/main.tscn"

var design := ShipDesign.new()
var picked: ShipModule
var theme_id := &"human"
var turn := 0
var _cell := Vector2i.ZERO

@onready var _view: ShipView = $ShipView
@onready var _ghost: MeshInstance3D = $Ghost
@onready var _ui: EditorUI = $UI
@onready var _cam: Camera3D = $Camera


func _ready() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		design = load(SAVE_PATH)
	_view.show_exhaust = true
	_view.design = design
	design.changed.connect(_refresh)
	_ui.module_picked.connect(_pick)
	_ui.theme_picked.connect(_pick_theme)
	_ui.action.connect(_on_action)
	_pick(ModuleLibrary.by_id(&"hull"))
	_refresh()
	$Grid.mesh = _grid_mesh(16)


## Faint build-grid lines, `n` cells out from the centre each way.
func _grid_mesh(n: int) -> ImmediateMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.5, 0.8, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var e := n * ShipView.CELL
	for i in range(-n, n + 1):
		var k := i * ShipView.CELL
		for v in [Vector3(k, 0, -e), Vector3(k, 0, e), Vector3(-e, 0, k), Vector3(e, 0, k)]:
			im.surface_add_vertex(v)
	im.surface_end()
	return im


func _pick(m: ShipModule) -> void:
	picked = m
	_update_ghost()


func _pick_theme(tid: StringName) -> void:
	theme_id = tid
	_update_ghost()


func _refresh() -> void:
	_ui.show_stats(ShipStats.of(design), design.ship_name)
	_ui.show_mode(Shipyard.status(design), Shipyard.can_refit(design))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cell = _mouse_cell(event.position)
		_update_ghost()
	elif event is InputEventMouseButton and event.pressed:
		_cell = _mouse_cell(event.position)
		var refit: bool = event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT,
				MOUSE_BUTTON_MIDDLE]
		if refit and not Shipyard.can_refit(design):
			_ui.flash("Needs a shipyard or a Shipdock module")
		elif event.button_index == MOUSE_BUTTON_LEFT and picked:
			var why := ShipRules.why_not(design, picked, _origin(), turn)
			why = why if why else Blueprint.why_locked(picked, theme_id)
			if why:
				_ui.flash(why)
			else:
				design.add(picked, _origin(), turn, theme_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			design.remove_at(_cell)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_paint()
		_update_ghost()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R: turn = (turn + 1) % 4
			KEY_V: _view.outside = not _view.outside
			KEY_ESCAPE: get_tree().change_scene_to_file(MAP_SCENE)
		_update_ghost()


## Repaints the part under the mouse unless that style is locked.
func _paint() -> void:
	var i := design.index_at(_cell)
	var why := Blueprint.why_locked(design.modules[i], theme_id) if i >= 0 else ""
	if why:
		_ui.flash(why)
	else:
		design.paint(_cell, theme_id)


## Grid cell under the mouse, on the y = 0 build plane.
func _mouse_cell(screen: Vector2) -> Vector2i:
	var from := _cam.project_ray_origin(screen)
	var dir := _cam.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return _cell
	var hit := from + dir * (-from.y / dir.y)
	return Vector2i(floori(hit.x / ShipView.CELL), floori(hit.z / ShipView.CELL))


## Top-left cell so the module is centred on the mouse.
func _origin() -> Vector2i:
	return _cell - (ShipDesign.turned(picked, turn) - Vector2i.ONE) / 2


func _update_ghost() -> void:
	_ghost.visible = picked != null
	if not picked:
		return
	var r := Rect2i(_origin(), ShipDesign.turned(picked, turn))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ok := design.fits(picked, r.position, turn) \
			and Blueprint.why_locked(picked, theme_id).is_empty()
	mat.albedo_color = Color(0.3, 1, 0.5, 0.45) if ok else Color(1, 0.3, 0.3, 0.45)
	var t := ShipTheme.by_id(theme_id)
	_ghost.mesh = ShipView.part_mesh(picked, r, turn, t, design.occupied())
	_ghost.material_override = mat
	_ghost.position = ShipView.center(r) + Vector3.UP * 0.05
	for c in _ghost.get_children():
		c.queue_free()
	var lane := ShipView.lane_mesh(picked, r, turn)
	if lane:
		lane.position -= _ghost.position
		_ghost.add_child(lane)


func _on_action(what: String) -> void:
	if what != "save" and not Shipyard.can_refit(design):
		_ui.flash("Needs a shipyard or a Shipdock module")
		return
	match what:
		"clear": design.clear()
		"random": _randomize()
		"save": _save()


func _randomize() -> void:
	var pool: Array[ShipModule] = ModuleLibrary.all().filter(
			func(m): return m.category != "command")
	var rng := RandomNumberGenerator.new()
	var themes := ShipTheme.all()
	var tid := themes[rng.randi() % themes.size()].id
	var d := ShipGenerator.generate(ModuleLibrary.by_id(&"bridge"), pool, rng, 16, tid)
	design.clear()
	for i in d.modules.size():
		design.add(d.modules[i], d.cells[i], d.turns[i], d.themes[i])
	design.ship_name = "Derelict %03d" % rng.randi_range(1, 999)
	_refresh()


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	var err := ResourceSaver.save(design, SAVE_PATH)
	_ui.flash("Saved" if err == OK else "Save failed (%d)" % err)
