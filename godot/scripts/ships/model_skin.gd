class_name ModelSkin
extends RefCounted
## Dresses an imported Blender part for the game: one shared gritty PBR
## material per theme (its accent colour), one glow material, lamps
## that cast soft shadows up close and switch off far away, and inside
## vs outside view. Models carry "Interior" and "Exterior" meshes; see
## art/tools.

const PBR := preload("res://assets/materials/pbr.gdshader")
const GLOW := preload("res://assets/materials/glow.gdshader")
const LAMP_RANGE := 6.0
const LAMP_ENERGY := 1.1
const SHADOW_FADE := 30.0  # camera distance where lamp shadows stop
const LAMP_FADE := 80.0  # camera distance where lamps start to fade

static var _mats := {}  # theme id -> ShaderMaterial
static var _glow: ShaderMaterial
static var _glass: StandardMaterial3D
static var _grime: NoiseTexture2D
static var _bump: NoiseTexture2D


## Hull deck under Blender parts: dark plating with seams every metre.
static func deck_material() -> ShaderMaterial:
	if not _mats.has(&"_deck"):
		var m := material(null).duplicate() as ShaderMaterial
		m.set_shader_parameter(&"tint", Color(0.36, 0.38, 0.41))
		m.set_shader_parameter(&"seams", 1.0)
		_mats[&"_deck"] = m
	return _mats[&"_deck"]


## Outside hull shell: painted plates, seams every 2 m, accent chamfer.
static func shell_material(t: ShipTheme) -> ShaderMaterial:
	var key := StringName("_shell_" + String(t.id))
	if not _mats.has(key):
		var m := material(t).duplicate() as ShaderMaterial
		m.set_shader_parameter(&"tint", Color(0.5, 0.52, 0.56))
		m.set_shader_parameter(&"seams", 0.5)
		_mats[key] = m
	return _mats[key]


## The shared PBR material for `t`'s parts (or plain grey steel).
static func material(t: ShipTheme = null) -> ShaderMaterial:
	var key: StringName = t.id if t else &""
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = PBR
		m.set_shader_parameter(&"grime_tex", noise(false))
		m.set_shader_parameter(&"bump_tex", noise(true))
		if t:
			m.set_shader_parameter(&"accent", t.accent)
			m.set_shader_parameter(&"grime", t.grime)
			m.set_shader_parameter(&"wear", t.wear)
			m.set_shader_parameter(&"bump", t.bump)
		_mats[key] = m
	return _mats[key]


static func apply(n: Node, t: ShipTheme) -> void:
	if _glow == null:
		_glow = ShaderMaterial.new()
		_glow.shader = GLOW
	if _glass == null:
		_glass = _glass_mat()
	var mat := material(t)
	for c in n.find_children("*", "", true, false):
		if c is MeshInstance3D:
			_skin(c, mat)
		elif c is OmniLight3D:
			_lamp(c)


## Outside view shows the hull shell, inside view the deck and crew.
## Glass parts (meta "glass", see ShipView.make_part) keep their inside
## visible under the glass. Names may carry a Blender suffix.
static func set_outside(n: Node, outside: bool) -> void:
	var glass: bool = n.get_meta(&"glass", false)
	for c in n.find_children("Exterior*", "", true, false):
		c.visible = outside
	for c in n.find_children("Interior*", "", true, false):
		c.visible = glass or not outside


static func _skin(mi: MeshInstance3D, mat: Material) -> void:
	for k in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(k)
		var id := m.resource_name if m else ""
		var use: Material = mat
		if id.begins_with("Glow"):
			use = _glow
		elif id.begins_with("Glass"):
			use = _glass
		mi.set_surface_override_material(k, use)


static func _lamp(l: OmniLight3D) -> void:
	l.omni_range = LAMP_RANGE
	l.omni_attenuation = 1.4
	l.light_energy = LAMP_ENERGY
	l.light_specular = 0.6
	l.shadow_enabled = true
	l.shadow_blur = 1.5
	l.distance_fade_enabled = true
	l.distance_fade_begin = LAMP_FADE
	l.distance_fade_length = 15.0
	l.distance_fade_shadow = SHADOW_FADE


## Clear, slightly tinted glass that reflects a little light.
static func _glass_mat() -> StandardMaterial3D:
	var g := StandardMaterial3D.new()
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g.cull_mode = BaseMaterial3D.CULL_DISABLED
	g.albedo_color = Color(0.55, 0.75, 0.85, 0.18)
	g.metallic = 0.4
	g.roughness = 0.05
	g.metallic_specular = 0.8
	return g


## Hull shell with holes cut over glass parts (rects in ship metres).
static func cut_shell(t: ShipTheme, holes: Array) -> ShaderMaterial:
	if holes.is_empty():
		return shell_material(t)
	var m := shell_material(t).duplicate() as ShaderMaterial
	var v := PackedVector4Array()
	for r: Rect2 in holes.slice(0, 8):
		v.append(Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
	v.resize(8)
	m.set_shader_parameter(&"holes", v)
	m.set_shader_parameter(&"hole_count", mini(holes.size(), 8))
	return m


## Small seamless noise, made once: blotchy grime or a bump normal map.
static func noise(normal: bool) -> NoiseTexture2D:
	if (_bump if normal else _grime):
		return _bump if normal else _grime
	var fn := FastNoiseLite.new()
	fn.seed = 11 if normal else 3
	fn.fractal_octaves = 5
	fn.frequency = 0.03 if normal else 0.012
	if normal:  # soft dents and waviness, not hammered metal
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = fn
	tex.as_normal_map = normal
	tex.bump_strength = 6.0
	tex.generate_mipmaps = true
	if normal:
		_bump = tex
	else:
		_grime = tex
	return tex
