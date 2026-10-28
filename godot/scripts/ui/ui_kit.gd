class_name UiKit
extends RefCounted
## Small building blocks that keep screens uncluttered: section headers,
## foldable sections and a "?" button that shows the controls on demand.


static func header(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"Header"
	l.text = text.to_upper()
	return l


## A titled section whose body hides when the title is clicked.
static func fold(title: String, body: Control, open := true) -> VBoxContainer:
	var box := VBoxContainer.new()
	var b := Button.new()
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override(&"font_color", UiStyle.EDGE)
	b.add_theme_font_size_override(&"font_size", 13)
	box.add_child(b)
	box.add_child(body)
	var show := func(on: bool) -> void:
		body.visible = on
		b.text = ("▾ " if on else "▸ ") + title.to_upper()
	b.pressed.connect(func(): show.call(not body.visible))
	show.call(open)
	return box


## "?" button pinned bottom-right of `layer`; it shows `text` above it.
static func help(layer: Node, text: String) -> Button:
	var tip := PanelContainer.new()
	var l := Label.new()
	l.text = text
	tip.add_child(l)
	tip.visible = false
	var b := Button.new()
	b.text = "?"
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(36, 36)
	b.tooltip_text = "Controls (F1)"
	b.add_to_group(&"help")
	b.toggled.connect(func(on): tip.visible = on)
	layer.add_child(tip)
	layer.add_child(b)
	_pin(b, Vector2(-48, -48), Vector2(-12, -12))
	tip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tip.offset_right = -12
	tip.offset_bottom = -56
	return b


static func _pin(c: Control, from: Vector2, to: Vector2) -> void:
	c.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	c.offset_left = from.x
	c.offset_top = from.y
	c.offset_right = to.x
	c.offset_bottom = to.y
