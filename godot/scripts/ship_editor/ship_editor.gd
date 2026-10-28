extends Node3D
## Grid ship builder. Left click places the picked module in the picked
## theme, right click removes, middle click repaints. R rotates, F
## mirrors the part, X builds both sides at once, M picks parts up to
## move them, Esc returns to the map. Moving is allowed anywhere; adding,
## removing and repainting need a shipyard or a Shipdock (see Shipyard).

const SAVE_PATH := "user://ships/player.tres"
const MAP_SCENE := "res://scenes/main.tscn"

var design := ShipDesign.new()
var picked: ShipModule
var theme_id := &"human"
var turn := 0  # 0-3 quarter turns, +4 when mirrored
var sym := false  # also build the mirror image across the centre line
var moving := false  # move tool: click a part to pick it up
var _held := {}  # the part being moved: {m, cell, turn, theme}
var _cell := Vector2i.ZERO
var _grid := Rect2i()
var _holos: Array[Node3D] = []  # [placed, mirror copy]
var _holo_key := ""

@onready var _view: ShipView = $ShipView
@onready var _ghost: Node3D = $Ghost
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


func _pick(m: ShipModule) -> void:
	_drop_back()
	moving = false
	picked = m
	_sync()


func _pick_theme(tid: StringName) -> void:
	theme_id = tid
	_sync()


func _refresh() -> void:
	_ui.show_stats(ShipStats.of(design), design.ship_name)
	_ui.show_mode(Shipyard.status(design), Shipyard.can_refit(design))
	_fit_grid(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cell = _mouse_cell(event.position)
		_update_ghost()
		_fit_grid()
	elif event is InputEventMouseButton and event.pressed:
		_cell = _mouse_cell(event.position)
		_click(event.button_index)
		_update_ghost()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R: _on_action("rotate")
			KEY_F: _on_action("mirror")
			KEY_X: _on_action("symmetry")
			KEY_M: _on_action("move")
			KEY_V: _view.outside = not _view.outside
			KEY_ESCAPE:
				if _held.is_empty():
					get_tree().change_scene_to_file(MAP_SCENE)
				_drop_back()
		_update_ghost()


func _click(button: MouseButton) -> void:
	if moving and button == MOUSE_BUTTON_LEFT:
		_move_click()
	elif moving and button == MOUSE_BUTTON_RIGHT:
		_drop_back()
	elif not button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		return
	elif not Shipyard.can_refit(design):
		_ui.flash("Building needs a shipyard or a Shipdock. Moving parts (M) works anywhere.")
	elif button == MOUSE_BUTTON_LEFT and picked:
		_place()
	elif button == MOUSE_BUTTON_RIGHT:
		var twin := design.index_at(_twin(_cell))
		var i := design.index_at(_cell)
		design.remove_at(_cell)
		if sym and twin >= 0 and twin != i:
			design.remove_at(_twin(_cell))
	elif button == MOUSE_BUTTON_MIDDLE and _locked(design.index_at(_cell)):
		return
	elif button == MOUSE_BUTTON_MIDDLE:
		design.paint(_cell, theme_id)
		if sym:
			design.paint(_twin(_cell), theme_id)


## Flashes why module i can't wear the picked style; true if locked.
func _locked(i: int) -> bool:
	var why := Blueprint.why_locked(design.modules[i], theme_id) if i >= 0 else ""
	if why:
		_ui.flash(why)
	return not why.is_empty()


func _place() -> void:
	var why := ShipRules.why_not(design, picked, _origin(), turn)
	why = why if why else Blueprint.why_locked(picked, theme_id)
	if why:
		_ui.flash(why)
		return
	design.add(picked, _origin(), turn, theme_id)
	var size := ShipDesign.turned(picked, turn)
	var at := ShipDesign.mirror_cell(_origin(), size)
	if sym and at != _origin() and not design.add(picked, at, ShipDesign.mirror(turn), theme_id):
		_ui.flash("No room for the mirror copy")


## Move tool: the first click lifts a part, the next sets it down.
func _move_click() -> void:
	if _held.is_empty():
		var i := design.index_at(_cell)
		if i < 0:
			return
		_held = {m = design.modules[i], cell = design.cells[i], turn = design.turns[i],
				theme = design.themes[i] if i < design.themes.size() else theme_id}
		picked = _held.m
		turn = _held.turn
		theme_id = _held.theme
		design.remove_at(_cell)
	else:
		var why := ShipRules.why_not(design, picked, _origin(), turn)
		if why:
			_ui.flash(why)
			return
		design.add(picked, _origin(), turn, _held.theme)
		_held = {}
		picked = null
	_sync()


## Puts a lifted part back where it was.
func _drop_back() -> void:
	if _held.is_empty():
		return
	design.add(_held.m, _held.cell, _held.turn, _held.theme)
	_held = {}
	picked = null if moving else picked
	_sync()


## Cell on the other side of the centre line.
static func _twin(c: Vector2i) -> Vector2i:
	return Vector2i(-c.x - 1, c.y)


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


## Grows the grid to keep the ship and the cursor well inside it.
func _fit_grid(force := false) -> void:
	var need := BuildAids.grid_need(design, _cell)
	if force or not _grid.encloses(need):
		_grid = need.grow(4)
		$Grid.mesh = BuildAids.grid_mesh(_grid, sym)


## Rebuilds the holograms when the part, its turn or style change.
func _update_ghost() -> void:
	var key := "%s|%d|%s|%s" % [picked.id if picked else &"", turn, theme_id, sym]
	if key != _holo_key:
		_holo_key = key
		for h in _holos:
			h.queue_free()
		_holos.clear()
		if picked:
			var t := ShipTheme.by_id(theme_id)
			_holos.append(BuildAids.hologram(picked, turn, t))
			if sym and not moving:
				_holos.append(BuildAids.hologram(picked, ShipDesign.mirror(turn), t))
			for h in _holos:
				_ghost.add_child(h)
	if not picked:
		return
	var size := ShipDesign.turned(picked, turn)
	var r := Rect2i(_origin(), size)
	BuildAids.tint(_holos[0], design.fits(picked, r.position, turn)
			and Blueprint.why_locked(picked, theme_id).is_empty())
	_holos[0].position = ShipView.center(r) + Vector3.UP * 0.05
	if _holos.size() > 1:
		var m := Rect2i(ShipDesign.mirror_cell(r.position, size), size)
		_holos[1].visible = m != r
		BuildAids.tint(_holos[1], design.fits(picked, m.position, ShipDesign.mirror(turn)))
		_holos[1].position = ShipView.center(m) + Vector3.UP * 0.05


func _sync() -> void:
	_ui.show_tools(moving, sym)
	_update_ghost()


func _on_action(what: String) -> void:
	match what:
		"rotate": turn = turn - turn % 4 + (turn + 1) % 4
		"mirror": turn = (turn + 4) % 8
		"symmetry":
			sym = not sym
			_fit_grid(true)
		"move":
			_drop_back()
			moving = not moving
			picked = null if moving else ModuleLibrary.by_id(&"hull")
		"save": _save()
		_:
			if not Shipyard.can_refit(design):
				_ui.flash("Needs a shipyard or a Shipdock module")
			elif what == "clear":
				design.clear()
			elif what == "random":
				_randomize()
	_sync()


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
	_drop_back()
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	var err := ResourceSaver.save(design, SAVE_PATH)
	_ui.flash("Saved" if err == OK else "Save failed (%d)" % err)


func _exit_tree() -> void:
	_drop_back()
