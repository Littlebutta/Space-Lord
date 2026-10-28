class_name CrewPanel
extends CanvasLayer
## Work-priority grid (RimWorld style): a row per crew member, a column
## per job type. Click a cell to cycle 1 (first) .. 4 (last) .. off;
## click a column header to set the whole column. Jobs a species can't
## do show a cross. Hiring happens at stations (StationPanel).

var sim: CrewSim
var _grid := GridContainer.new()
var _doing: Array[Label] = []


func bind(s: CrewSim) -> void:
	sim = s
	var p := PanelContainer.new()
	var box := VBoxContainer.new()
	p.add_child(UiKit.fold("Crew priorities", box, false))
	UiKit.pin(self, p, Control.PRESET_TOP_LEFT)
	box.add_child(_grid)
	sim.crew_changed.connect(_build)
	_build()


func _process(_delta: float) -> void:
	for k in mini(_doing.size(), sim.crew.size()):
		_doing[k].text = sim.crew[k].status()


func _build() -> void:
	for n in _grid.get_children():
		n.queue_free()
	_doing.clear()
	_grid.columns = CrewJob.TYPES.size() + 2
	_grid.add_child(_label("Crew"))
	for t in CrewJob.TYPES:
		_grid.add_child(_button(t.capitalize(), _cycle_column.bind(t)))
	_grid.add_child(_label("Doing"))
	for c in sim.crew:
		var who := _label(c.name)
		who.tooltip_text = c.species.display_name + ": " + c.species.blurb
		who.mouse_filter = Control.MOUSE_FILTER_STOP
		who.modulate = c.species.look().tint.lerp(Color.WHITE, 0.5)
		_grid.add_child(who)
		for t in CrewJob.TYPES:
			var b := _button(_text(c.pref(t)), Callable())
			b.disabled = not c.species.can(t)
			b.text = "×" if b.disabled else b.text
			b.pressed.connect(_cycle.bind(c, t, b))
			_grid.add_child(b)
		var l := _label("")
		l.custom_minimum_size.x = 220
		_doing.append(l)
		_grid.add_child(l)


func _cycle(c: CrewMember, t: StringName, b: Button) -> void:
	c.priority[t] = CrewMember.next_pref(c.pref(t))
	b.text = _text(c.pref(t))


func _cycle_column(t: StringName) -> void:
	if sim.crew.is_empty():
		return
	var p := CrewMember.next_pref(sim.crew[0].pref(t))
	for c in sim.crew:
		c.priority[t] = p
	_build()


static func _text(p: int) -> String:
	return str(p) if p > 0 else "-"


func _button(text: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.x = 64
	if on.is_valid():
		b.pressed.connect(on)
	return b


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l
