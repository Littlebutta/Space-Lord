class_name EditorUI
extends CanvasLayer
## Builder panels, also used for refits out in space: parts on the left
## (scrolls), live stats and warnings on the right (scrolls), controls
## along the bottom. Anchored, so it fits any window size.

signal module_picked(m: ShipModule)
signal action(what: String)
signal theme_picked(id: StringName)

const HELP := "LMB place · RMB remove · MMB paint theme · R rotate · V outside view" \
		+ " · WASD pan · wheel zoom · Esc map · Ship nose is up"
const WARN := Color(1, 0.55, 0.4)
const OK := Color(0.55, 1, 0.6)

var _stats := RichTextLabel.new()
var _note := Label.new()
var _mode := _label("", true)


func _ready() -> void:
	var left := _panel(Control.PRESET_LEFT_WIDE, 320)
	left.add_child(_mode)
	var row := HBoxContainer.new()
	row.add_child(_label("Theme"))
	var themes := OptionButton.new()
	themes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in ShipTheme.all():
		themes.add_item(t.display_name)
		themes.set_item_tooltip(themes.item_count - 1, t.blurb)
	themes.item_selected.connect(_on_theme)
	row.add_child(themes)
	left.add_child(row)
	_on_theme(0)
	left.add_child(_scroll(_palette()))
	var acts := HBoxContainer.new()
	for a in ["save", "random", "clear"]:
		var b := Button.new()
		b.text = a.capitalize()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(action.emit.bind(a))
		acts.add_child(b)
	left.add_child(acts)
	_note.modulate = WARN
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(_note)
	var right := _panel(Control.PRESET_RIGHT_WIDE, 300)
	_stats.fit_content = true
	_stats.bbcode_enabled = true
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_scroll(_stats))
	var help := _label(HELP, true)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(help)
	help.anchor_left = 0.0
	help.anchor_right = 1.0
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 12
	help.offset_right = -12
	help.offset_top = -44
	help.offset_bottom = -10


## Part buttons grouped by category, two per row.
func _palette() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var group := ButtonGroup.new()
	var grid: GridContainer
	for m in ModuleLibrary.all():
		if grid == null or m.category != grid.name:
			box.add_child(_label(m.category.capitalize()))
			grid = GridContainer.new()
			grid.name = m.category
			grid.columns = 2
			box.add_child(grid)
		var b := Button.new()
		b.text = "%s %dx%d" % [m.display_name, m.size.x, m.size.y]
		b.clip_text = true
		b.tooltip_text = b.text
		b.custom_minimum_size.x = 146
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = m.id == &"hull"
		b.pressed.connect(module_picked.emit.bind(m))
		grid.add_child(b)
	return box


## Shipyard status line: green when refits are allowed, else orange.
func show_mode(text: String, refit: bool) -> void:
	_mode.text = text
	_mode.modulate = OK if refit else WARN


func _on_theme(k: int) -> void:
	theme_picked.emit(ShipTheme.all()[k].id)


func show_stats(s: ShipStats, ship_name: String) -> void:
	var t := "[b]%s[/b]\n" % ship_name
	t += "Mass %.0f t   Hull %.0f hp\n" % [s.mass, s.hp]
	t += "Crew %d / %d berths\n" % [s.crew, s.berths]
	t += "Thrust %.0f   Accel %.2f\n" % [s.thrust, s.accel()]
	t += "Firepower %.0f dps\n\n[b]Storage[/b]\n" % s.firepower
	for res in s.storage:
		var hrs := s.endurance(res)
		var last := "" if hrs == INF else "  (%.0f h)" % hrs
		t += "%s %.0f%s\n" % [res.capitalize(), s.storage[res], last]
	for w in s.warnings:
		t += "\n[color=#ff8866]! %s[/color]" % w
	_stats.text = t


func flash(msg: String) -> void:
	_note.text = msg
	get_tree().create_timer(2.0).timeout.connect(func(): _note.text = "")


## Full-height side panel anchored by `preset`, `width` px wide.
func _panel(preset: Control.LayoutPreset, width: float) -> VBoxContainer:
	var p := PanelContainer.new()
	add_child(p)
	p.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 12)
	p.custom_minimum_size.x = width
	if preset == Control.PRESET_RIGHT_WIDE:
		p.offset_left = p.offset_right - width
	else:
		p.offset_right = p.offset_left + width
	p.offset_bottom -= 48  # room for the help line
	var box := VBoxContainer.new()
	p.add_child(box)
	return box


func _scroll(c: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(c)
	return sc


func _label(text: String, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(0.7, 0.8, 1.0)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l
