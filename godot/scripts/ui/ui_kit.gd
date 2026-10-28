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
	b.text = " ? "
	b.toggle_mode = true
	b.tooltip_text = "Controls (F1)"
	b.add_to_group(&"help")
	b.toggled.connect(func(on): tip.visible = on)
	pin(layer, b, Control.PRESET_BOTTOM_RIGHT)
	pin(layer, tip, Control.PRESET_BOTTOM_RIGHT, Vector2(12, 60))
	return b


## Adds `c` to `layer` stuck to a screen corner or edge (`preset`),
## `gap` px in from it, growing away from that edge as it resizes.
static func pin(layer: Node, c: Control, preset: Control.LayoutPreset,
		gap := Vector2(12, 12)) -> void:
	layer.add_child(c)
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	var right := preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT,
			Control.PRESET_CENTER_RIGHT, Control.PRESET_RIGHT_WIDE]
	var bottom := preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT,
			Control.PRESET_CENTER_BOTTOM, Control.PRESET_BOTTOM_WIDE]
	var mid_x := preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM]
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH if mid_x else (
			Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
	var dx := 0.0 if mid_x else (-gap.x if right else gap.x)
	var dy := -gap.y if bottom else gap.y
	c.offset_left += dx
	c.offset_right += dx
	c.offset_top += dy
	c.offset_bottom += dy
