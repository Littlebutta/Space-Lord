class_name EditorUI
extends CanvasLayer
## Builder side panels: module palette on the left, live ship stats
## and design warnings on the right. Built in code to stay tiny.

signal module_picked(m: ShipModule)
signal action(what: String)
signal theme_picked(id: StringName)

const HELP := "LMB place · RMB remove · MMB paint theme · R rotate · V outside view · " \
		+ "WASD pan · wheel zoom · Esc map. Ship nose is up; thrusters " \
		+ "fire back or sideways and need a clear lane."

var _stats := RichTextLabel.new()
var _note := Label.new()
var _blurb := _label("", true)


func _ready() -> void:
	var left := _panel(Vector2(12, 12), 210)
	left.add_child(_label("Theme"))
	var themes := OptionButton.new()
	for t in ShipTheme.all():
		themes.add_item(t.display_name)
	themes.item_selected.connect(_on_theme)
	left.add_child(themes)
	left.add_child(_blurb)
	_on_theme(0)
	var group := ButtonGroup.new()
	var last_cat := ""
	for m in ModuleLibrary.all():
		if m.category != last_cat:
			last_cat = m.category
			left.add_child(_label(last_cat.capitalize()))
		var b := Button.new()
		b.text = "%s  %dx%d" % [m.display_name, m.size.x, m.size.y]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = m.id == &"hull"
		b.pressed.connect(module_picked.emit.bind(m))
		left.add_child(b)
	for a in ["save", "random", "clear"]:
		var b := Button.new()
		b.text = a.capitalize()
		b.pressed.connect(action.emit.bind(a))
		left.add_child(b)
	left.add_child(_note)
	var right := _panel(Vector2(get_viewport().size.x - 312, 12), 300)
	_stats.fit_content = true
	_stats.bbcode_enabled = true
	right.add_child(_stats)
	right.add_child(_label(HELP, true))


func _on_theme(k: int) -> void:
	var t := ShipTheme.all()[k]
	_blurb.text = t.blurb
	theme_picked.emit(t.id)


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


func _panel(pos: Vector2, width: float) -> VBoxContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size.x = width
	add_child(p)
	var box := VBoxContainer.new()
	p.add_child(box)
	return box


func _label(text: String, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(0.7, 0.8, 1.0)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l
