class_name EditorUI
extends CanvasLayer
## Builder panels, also used for refits out in space: parts on the left
## (scrolls), a foldable ship summary top right, the shipyard status
## at the top and the controls behind "?" (F1). Fits any window size.

signal module_picked(m: ShipModule)
signal action(what: String)
signal theme_picked(id: StringName)

const HELP := "LMB place · RMB remove · MMB paint theme · R rotate · F mirror part\n" \
		+ "X symmetry (builds both sides) · M move parts (works anywhere)\n" \
		+ "V outside view · WASD pan · middle drag rotate · wheel zoom\n" \
		+ "Esc map · the ship's nose points up the screen"
const TOOLS := [["move", "Move", "Pick parts up and set them down (M). Allowed anywhere."],
		["symmetry", "Symmetry", "Build both sides at once across the amber line (X)"],
		["mirror", "Mirror", "Flip the part left-right (F)"],
		["rotate", "Rotate", "Turn the part (R)"]]

var _stats := RichTextLabel.new()
var _warn := RichTextLabel.new()
var _warn_box: Control
var _note := Label.new()
var _mode := Label.new()
var _tools := {}  # action -> Button


func _ready() -> void:
	var left := _side(320)
	left.add_child(UiKit.header("Parts"))
	var row := HBoxContainer.new()
	row.add_child(Label.new())
	row.get_child(0).text = "Style"
	var themes := OptionButton.new()
	themes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in ShipTheme.all():
		themes.add_item(t.display_name)
		themes.set_item_tooltip(themes.item_count - 1, t.blurb)
	themes.item_selected.connect(_on_theme)
	row.add_child(themes)
	left.add_child(row)
	_on_theme(0)
	var tools := GridContainer.new()
	tools.columns = 2
	for t in TOOLS:
		var b := Button.new()
		b.text = t[1]
		b.tooltip_text = t[2]
		b.toggle_mode = t[0] in ["move", "symmetry"]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(action.emit.bind(t[0]))
		tools.add_child(b)
		_tools[t[0]] = b
	left.add_child(tools)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(_palette())
	left.add_child(sc)
	var acts := HBoxContainer.new()
	for a in ["save", "random", "clear"]:
		var b := Button.new()
		b.text = a.capitalize()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(action.emit.bind(a))
		acts.add_child(b)
	left.add_child(acts)
	_note.add_theme_color_override(&"font_color", UiStyle.WARN)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(_note)
	var pill := PanelContainer.new()
	pill.add_child(_mode)
	UiKit.pin(self, pill, Control.PRESET_CENTER_TOP)
	var info := PanelContainer.new()
	info.custom_minimum_size.x = 280
	var col := VBoxContainer.new()
	info.add_child(col)
	for r in [_stats, _warn]:
		r.fit_content = true
		r.bbcode_enabled = true
		r.custom_minimum_size.x = 260
	col.add_child(UiKit.fold("Ship", _stats))
	_warn_box = UiKit.fold("Warnings", _warn)
	col.add_child(_warn_box)
	UiKit.pin(self, info, Control.PRESET_TOP_RIGHT)
	UiKit.help(self, HELP)


## Part buttons grouped by category, two per row.
func _palette() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var group := ButtonGroup.new()
	var grid: GridContainer
	for m in ModuleLibrary.all():
		if grid == null or m.category != grid.name:
			box.add_child(UiKit.header(m.category))
			grid = GridContainer.new()
			grid.name = m.category
			grid.columns = 2
			box.add_child(grid)
		var b := Button.new()
		b.text = "%s %dx%d" % [m.display_name, m.size.x, m.size.y]
		b.clip_text = true
		b.tooltip_text = b.text
		b.custom_minimum_size.x = 140
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = m.id == &"hull"
		b.pressed.connect(module_picked.emit.bind(m))
		grid.add_child(b)
	return box


## Shipyard status pill: green when refits are allowed, else orange.
func show_mode(text: String, refit: bool) -> void:
	_mode.text = text
	_mode.add_theme_color_override(&"font_color", UiStyle.OK if refit else UiStyle.WARN)


## Keeps the Move and Symmetry buttons in step with keys.
func show_tools(moving: bool, sym: bool) -> void:
	_tools.move.set_pressed_no_signal(moving)
	_tools.symmetry.set_pressed_no_signal(sym)


func _on_theme(k: int) -> void:
	theme_picked.emit(ShipTheme.all()[k].id)


func show_stats(s: ShipStats, ship_name: String) -> void:
	var t := "[b]%s[/b]\n" % ship_name
	t += "Mass %.0f t   Hull %.0f hp\n" % [s.mass, s.hp]
	t += "Crew %d / %d berths\n" % [s.crew, s.berths]
	t += "Thrust %.0f   Accel %.2f\n" % [s.thrust, s.accel()]
	t += "Firepower %.0f dps\n" % s.firepower
	t += "Build cost: %s" % Materials.line(s.cost)
	for res in s.storage:
		var hrs := s.endurance(res)
		var last := "" if hrs == INF else "  (%.0f h)" % hrs
		t += "\n%s %.0f%s" % [res.capitalize(), s.storage[res], last]
	_stats.text = t
	var w := ""
	for x in s.warnings:
		w += "[color=#ff8866]• %s[/color]\n" % x
	_warn.text = w.strip_edges()
	_warn_box.visible = not s.warnings.is_empty()


func flash(msg: String) -> void:
	_note.text = msg
	get_tree().create_timer(2.0).timeout.connect(func(): _note.text = "")


## Full-height panel down the left side, `width` px wide.
func _side(width: float) -> VBoxContainer:
	var p := PanelContainer.new()
	add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE, 12)
	p.offset_right = p.offset_left + width
	var box := VBoxContainer.new()
	p.add_child(box)
	return box
