class_name UiStyle
extends RefCounted
## The game's sci-fi UI look in one place: dark glass panels with a lit
## edge, chunky buttons and slim bars. UiSkin applies it to every screen.

const BG := Color(0.03, 0.05, 0.08, 0.88)
const BTN := Color(0.07, 0.11, 0.17, 0.95)
const EDGE := Color(0.3, 0.75, 1.0)
const TEXT := Color(0.86, 0.93, 1.0)
const DIM := Color(0.55, 0.66, 0.78)
const ACCENT := Color(1.0, 0.68, 0.25)
const WARN := Color(1.0, 0.45, 0.35)
const OK := Color(0.45, 1.0, 0.6)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	var panel := box(BG, EDGE * Color(1, 1, 1, 0.35), 8)
	panel.border_width_left = 3
	panel.border_color = EDGE * Color(1, 1, 1, 0.6)
	for k in ["PanelContainer", "Panel", "TooltipPanel", "PopupMenu"]:
		t.set_stylebox(&"panel", k, panel)
	var normal := box(BTN, EDGE * Color(1, 1, 1, 0.2), 4)
	var hover := box(BTN.lightened(0.12), EDGE, 4)
	var down := box(Color(0.08, 0.28, 0.42), ACCENT, 4)
	for k in ["Button", "OptionButton"]:
		t.set_stylebox(&"normal", k, normal)
		t.set_stylebox(&"hover", k, hover)
		t.set_stylebox(&"pressed", k, down)
		t.set_stylebox(&"hover_pressed", k, down)
		t.set_stylebox(&"disabled", k, box(BTN, Color(1, 1, 1, 0.05), 4))
		t.set_stylebox(&"focus", k, StyleBoxEmpty.new())
		t.set_color(&"font_color", k, TEXT)
		t.set_color(&"font_hover_color", k, Color.WHITE)
		t.set_color(&"font_pressed_color", k, Color.WHITE)
		t.set_color(&"font_hover_pressed_color", k, Color.WHITE)
	t.set_stylebox(&"hover", "PopupMenu", box(EDGE * Color(1, 1, 1, 0.25), EDGE, 3))
	t.set_color(&"font_color", "Label", TEXT)
	t.set_color(&"font_color", "TooltipLabel", TEXT)
	t.set_color(&"default_color", "RichTextLabel", TEXT)
	t.set_type_variation(&"Header", &"Label")
	t.set_color(&"font_color", "Header", EDGE)
	t.set_font_size(&"font_size", "Header", 13)
	t.set_stylebox(&"background", "ProgressBar", box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 2))
	t.set_stylebox(&"fill", "ProgressBar", box(EDGE, Color(0, 0, 0, 0), 2))
	for k in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox(&"scroll", k, box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 3, 3))
		t.set_stylebox(&"grabber", k, box(EDGE * Color(1, 1, 1, 0.4), Color(0, 0, 0, 0), 3, 3))
		t.set_stylebox(&"grabber_highlight", k, box(EDGE, Color(0, 0, 0, 0), 3, 3))
	return t


## Rounded flat box with an edge colour and inner margin.
static func box(bg: Color, edge: Color, radius: int, margin := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(1 if edge.a > 0.0 else 0)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.content_margin_top = margin * 0.6
	sb.content_margin_bottom = margin * 0.6
	return sb
