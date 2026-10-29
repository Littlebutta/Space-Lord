extends CanvasLayer
## Graphics settings behind the ⚙ button (bottom right, by fullscreen).
## Godot has no DLSS or ray tracing, so this offers what it does have:
## anti-aliasing, AMD FSR 2 upscaling, and the screen-space lighting
## extras. Screen-space reflections stay off so nothing gets too shiny.
## Saved in user://settings.cfg and applied to every scene's environment.

const FILE := "user://settings.cfg"
const AA := ["Off", "FXAA", "MSAA 2x", "MSAA 4x", "TAA"]
const SCALE := ["Native", "FSR 2 Quality", "FSR 2 Balanced", "FSR 2 Performance"]
const SCALES := [1.0, 0.67, 0.59, 0.5]
const EXTRAS := {"ssao": "Ambient occlusion", "ssil": "Bounce light (SSIL)",
		"sdfgi": "Global illumination (SDFGI, heavy)", "glow": "Glow"}
const DEFAULTS := {"aa": 2, "scale": 0, "ssao": true, "ssil": false, "sdfgi": false, "glow": true}

var _set := {}
var _panel := PanelContainer.new()


func _ready() -> void:
	layer = 100
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	for k in DEFAULTS:
		_set[k] = cfg.get_value("graphics", k, DEFAULTS[k])
	var btn := Button.new()
	btn.text = " ⚙ "
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = "Graphics settings"
	btn.pressed.connect(func(): _panel.visible = not _panel.visible)
	UiKit.pin(self, btn, Control.PRESET_BOTTOM_RIGHT, Vector2(112, 12))
	_build()
	get_tree().node_added.connect(_on_node)
	_apply()


func _build() -> void:
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_panel.visible = false
	box.add_child(_choice("Anti-aliasing", AA, "aa"))
	box.add_child(_choice("Upscaling", SCALE, "scale"))
	for k in EXTRAS:
		var c := CheckBox.new()
		c.text = EXTRAS[k]
		c.button_pressed = _set[k]
		c.focus_mode = Control.FOCUS_NONE
		c.toggled.connect(_change.bind(k))
		box.add_child(c)
	UiKit.pin(self, _panel, Control.PRESET_BOTTOM_RIGHT, Vector2(12, 56))


func _choice(label: String, items: Array, key: String) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 110
	row.add_child(l)
	var o := OptionButton.new()
	for t in items:
		o.add_item(t)
	o.selected = _set[key]
	o.focus_mode = Control.FOCUS_NONE
	o.item_selected.connect(_change.bind(key))
	row.add_child(o)
	return row


func _change(v: Variant, key: String) -> void:
	_set[key] = v
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("graphics", key, v)
	cfg.save(FILE)
	_apply()


func _apply() -> void:
	var vp := get_viewport()
	var aa: int = _set.aa
	var fsr: bool = _set.scale > 0
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X,
			Viewport.MSAA_4X, Viewport.MSAA_DISABLED][aa]
	vp.use_taa = aa == 4 and not fsr  # FSR 2 does its own temporal AA
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if fsr else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = SCALES[_set.scale]
	for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_env(n)


func _on_node(n: Node) -> void:
	if n is WorldEnvironment:
		_env.call_deferred(n)


func _env(n: WorldEnvironment) -> void:
	var e := n.environment
	if e == null:
		return
	if not e.has_meta(&"own"):  # what the scene asked for, so "on" restores it
		e.set_meta(&"own", [e.ssao_enabled, e.glow_enabled])
	var own: Array = e.get_meta(&"own")
	e.ssao_enabled = own[0] and _set.ssao
	e.glow_enabled = own[1] and _set.glow
	e.ssil_enabled = _set.ssil
	e.sdfgi_enabled = _set.sdfgi
	e.ssr_enabled = false
