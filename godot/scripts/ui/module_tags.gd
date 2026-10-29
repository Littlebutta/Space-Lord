class_name ModuleTags
extends Control
## Small status cards pinned over each working module: name, crew and
## power, then a bar per supply it burns and one for damage. The left
## edge shows its state (green running, amber idle, red wrecked). Plain
## hull and armour only get a card while damaged. Alt hides them all.
## Reactors also show the capacitors' charge; in a fight, guns show
## what they're aimed at, or why they're silent.

const BG := Color(0.04, 0.06, 0.09, 0.82)
const RUN := Color(0.35, 0.85, 0.5)
const IDLE := Color(1.0, 0.7, 0.25)
const DEAD := Color(1.0, 0.32, 0.28)
const BARS := {"fuel": Color(1.0, 0.55, 0.2), "ammo": Color(0.95, 0.85, 0.3),
		"food": Color(0.5, 0.85, 0.4), "hp": Color(0.9, 0.35, 0.3)}
const LIFT := 1.6  # metres above the deck
const NEAR := 25.0  # cards shrink when the camera is further than this
const FAR := 70.0  # zoomed out further than this, cards would just pile up

var body: ShipBody
var guns: ShipGuns  # set in battle
var _cards: Array[PanelContainer] = []
var _bars: Array[Dictionary] = []  # per card: "hp"/resource -> ProgressBar
var _wait := 0.0


func bind(b: ShipBody) -> void:
	body = b
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in b.sim.state.size():
		_card(b.sim.state.module(i))


func _card(m: ShipModule) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_width_left = 3
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	sb.content_margin_left = 8
	p.add_theme_stylebox_override(&"panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	p.add_child(box)
	box.add_child(_text(m.display_name.to_upper(), 11, Color(0.92, 0.95, 1.0)))
	box.add_child(_text("", 10, Color(0.65, 0.72, 0.8)))
	var bars := {}
	for k in m.upkeep.keys() + ["hp"]:
		bars[k] = _bar(BARS.get(k, Color(0.6, 0.7, 0.9)))
		box.add_child(bars[k])
	add_child(p)
	_cards.append(p)
	_bars.append(bars)


func _text(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	return l


func _bar(col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(84, 4)
	b.max_value = 1.0
	for k in [&"background", &"fill"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col if k == &"fill" else Color(1, 1, 1, 0.1)
		sb.set_corner_radius_all(2)
		b.add_theme_stylebox_override(k, sb)
	return b


func _process(delta: float) -> void:
	if body == null or not visible:
		return
	_wait -= delta
	var fill := _wait <= 0.0
	if fill:
		_wait = 0.2
	var cam := get_viewport().get_camera_3d()
	var s := body.sim.state
	for i in _cards.size():
		var w := body.world(s.pieces.world(i))
		var at := Vector3(w.x, LIFT, w.y)
		var c := _cards[i]
		c.visible = _wanted(i) and not cam.is_position_behind(at) \
				and cam.global_position.distance_to(at) < FAR
		if not c.visible:
			continue
		if fill:
			_fill(i)
		var k := clampf(NEAR / cam.global_position.distance_to(at), 0.6, 1.0)
		c.scale = Vector2(k, k)
		c.position = cam.unproject_position(at) - c.size * k * Vector2(0.5, 1.0)


func _wanted(i: int) -> bool:
	var m := body.sim.state.module(i)
	return m.crew > 0 or not m.upkeep.is_empty() or body.sim.state.damaged(i)


func _fill(i: int) -> void:
	var s := body.sim.state
	var m := s.module(i)
	var line := _cards[i].get_child(0).get_child(1) as Label
	var sb := _cards[i].get_theme_stylebox(&"panel") as StyleBoxFlat
	var bars := _bars[i]
	var dead := s.hp[i] <= 0.0
	sb.border_color = DEAD if dead else (RUN if s.is_running(i) else IDLE)
	var t: Array[String] = []
	if dead:
		t.append("Wrecked")
	elif not s.pieces.powered(i):
		t.append("No power")
	if m.crew > 0 and not dead:
		t.append("Crew %d/%d" % [mini(s.operators[i], m.crew), m.crew])
	if m.power_out > 0.0 and not dead:
		var cap := s.power.stored()
		t.append("Capacitors %d/%d" % [roundi(cap.x), roundi(cap.y)] if cap.y > 0.0 \
				else "No capacitors")
	if guns and m.firepower > 0.0 and not dead:
		var why := guns.why(i)
		if guns.target(i) >= 0:
			t.append("Target: " + guns.target_name(i))
		elif why not in ["", "no target", "charging"]:
			t.append(why.capitalize())
	line.text = " · ".join(t)
	line.visible = not t.is_empty()
	for k in bars:
		var b: ProgressBar = bars[k]
		b.value = s.hp[i] / m.hp if k == "hp" else s.stock[i].get(k, 0.0) / s.buffer(i, k)
		b.visible = not dead and (k != "hp" or s.damaged(i))
