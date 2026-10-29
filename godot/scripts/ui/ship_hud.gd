class_name ShipHud
extends VBoxContainer
## Ship status panels, styled like the crew priorities panel and pinned
## top right: your ship's hull and crew, and below it a red panel with
## the enemy's overall hull, shown only while `engaged` says it matters.
## With several ships of yours, `shown` decides (e.g. only when one is
## clicked). `say` puts a banner (VICTORY / DEFEAT) on top.

var me: ShipBody
var foe: ShipBody  # null when there's no enemy
var engaged := func() -> bool: return true
var shown := func() -> bool: return true
var _banner := Label.new()
var _mine: Array  # [panel, hull bar, line]
var _theirs: Array


func bind(layer: Node, b: ShipBody, enemy: ShipBody = null) -> void:
	me = b
	foe = enemy
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_font_size_override(&"font_size", 26)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_banner.visible = false
	add_child(_banner)
	_mine = _panel("Your ship", UiStyle.OK)
	_theirs = _panel("Target", UiStyle.WARN)
	_theirs[0].add_theme_stylebox_override(&"panel", UiStyle.box(
			Color(0.16, 0.03, 0.03, 0.9), UiStyle.WARN, 8))
	UiKit.pin(layer, self, Control.PRESET_TOP_RIGHT)


func say(text: String) -> void:
	_banner.text = text
	_banner.visible = text != ""


func _panel(title: String, col: Color) -> Array:
	var p := PanelContainer.new()
	var box := VBoxContainer.new()
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.custom_minimum_size = Vector2(180, 8)
	var fill := UiStyle.box(col, Color(0, 0, 0, 0), 2, 0)
	bar.add_theme_stylebox_override(&"fill", fill)
	bar.add_theme_stylebox_override(&"background",
			UiStyle.box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 2, 0))
	var line := Label.new()
	box.add_child(bar)
	box.add_child(line)
	p.add_child(UiKit.fold(title, box))
	add_child(p)
	return [p, bar, line]


func _process(_delta: float) -> void:
	if me == null:
		return
	var on: bool = shown.call()
	_mine[0].visible = on
	_mine[1].value = hull(me)
	var lost := " · lost %d" % me.sim.lost if me.sim.lost else ""
	_mine[2].text = "Hull %d%% · Crew %d%s" % [roundi(hull(me) * 100.0), me.sim.crew.size(), lost]
	_theirs[0].visible = on and foe != null and engaged.call()
	if _theirs[0].visible:
		_theirs[1].value = hull(foe)
		var p := foe.sim.state.pieces
		var down := p.main < 0 or not p.has_bridge(p.main)
		_theirs[2].text = "Hull %d%%%s" % [roundi(hull(foe) * 100.0),
				" · bridge down" if down else ""]


## Share of the ship's total module hp left, 0..1.
static func hull(b: ShipBody) -> float:
	var s := b.sim.state
	var hp := 0.0
	var top := 0.0
	for i in s.size():
		hp += s.hp[i]
		top += s.module(i).hp
	return hp / top if top > 0.0 else 0.0
