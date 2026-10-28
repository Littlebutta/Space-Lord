class_name FxKit
extends RefCounted
## Builders for ship effects: engine exhaust, muzzle flashes, tracers,
## sparks and floating debris. Everything is made in code from a soft
## round sprite and a few shared materials, so there are no texture
## files and effects batch well.

const FIRE := Color(1.0, 0.62, 0.25)
const HOT := Color(1.0, 0.9, 0.7)

static var _sprite: GradientTexture2D
static var _mats := {}  # Color -> additive billboard material


## Engine plume: core cone, particle trail and a warm light, blowing +z.
static func exhaust() -> Node3D:
	var root := Node3D.new()
	root.name = &"FxExhaust"
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.55
	cm.height = 1.8
	cm.material = _glow_mat(Color(1.0, 0.7, 0.35, 0.55), false)
	cone.mesh = cm
	cone.rotation.x = -PI / 2.0
	cone.position.z = 0.9
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cone)
	var p := _particles(64, 0.55, Vector3(0, 0, 1), 6.0, Vector2(7.0, 10.0), 0.9)
	p.local_coords = false  # leaves a trail when the ship moves
	root.add_child(p)
	var l := _light(FIRE, 2.5, 6.0)
	l.position.z = 0.6
	root.add_child(l)
	return root


## Bright pop at a muzzle: flash sprite, sparks and a light that fades.
static func flash(at: Node3D) -> void:
	var root := Node3D.new()
	at.add_child(root)
	var s := _particles(18, 0.25, Vector3(0, 0, -1), 25.0, Vector2(8.0, 16.0), 0.18)
	s.one_shot = true
	s.explosiveness = 1.0
	root.add_child(s)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.6, 1.6)
	qm.material = _glow_mat(HOT, true)
	q.mesh = qm
	q.position.z = -0.4
	root.add_child(q)
	var l := _light(HOT, 6.0, 9.0)
	root.add_child(l)
	var tw := root.create_tween().set_parallel()
	tw.tween_property(l, "light_energy", 0.0, 0.18)
	tw.tween_property(q, "scale", Vector3.ONE * 0.1, 0.12)
	tw.chain().tween_interval(0.5)
	tw.chain().tween_callback(root.queue_free)


## Glowing slug flying from `xf` forward (-z) for `dist` metres.
static func tracer(parent: Node, xf: Transform3D, col: Color, dist := 60.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.09, 1.8)
	bm.material = _glow_mat(col, false)
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_transform = xf
	var to := xf.origin - xf.basis.z.normalized() * dist
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", to, dist / 140.0)
	tw.tween_callback(mi.queue_free)


## A short shower of sparks at world point `at`.
static func sparks(parent: Node, at: Vector3) -> void:
	var p := _particles(14, 0.5, Vector3.UP, 70.0, Vector2(2.0, 5.0), 0.08)
	p.one_shot = true
	p.explosiveness = 0.9
	(p.process_material as ParticleProcessMaterial).gravity = Vector3(0, -6, 0)
	parent.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)


## A destroyed module: fireball, sparks and chunks of hull that tumble
## away and fade out over ten seconds.
static func debris(parent: Node, xf: Transform3D, size: Vector2) -> void:
	var p := GPUParticles3D.new()
	p.amount = int(clampf(size.x * size.y * 6.0, 8.0, 40.0))
	p.lifetime = 10.0
	p.one_shot = true
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(size.x, 0.8, size.y)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3.ZERO
	pm.damping_min = 0.05
	pm.damping_max = 0.2
	pm.angular_velocity_min = -200.0
	pm.angular_velocity_max = 200.0
	pm.scale_min = 0.35
	pm.scale_max = 1.6
	p.process_material = pm
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.6, 0.15, 0.45)
	chunk.material = ModelSkin.shell_material(ShipTheme.by_id(&"human"))
	p.draw_pass_1 = chunk
	p.visibility_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)
	parent.add_child(p)
	p.global_transform = xf
	p.finished.connect(p.queue_free)
	var boom := _particles(40, 0.9, Vector3.UP, 180.0, Vector2(2.0, 6.0), 1.2)
	boom.one_shot = true
	boom.explosiveness = 1.0
	parent.add_child(boom)
	boom.global_position = xf.origin + Vector3.UP
	boom.finished.connect(boom.queue_free)
	sparks(parent, xf.origin + Vector3.UP)


static func _particles(n: int, life: float, dir: Vector3, spread: float,
		speed: Vector2, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	pm.scale_curve = CurveTexture.new()
	pm.scale_curve.curve = c
	var g := Gradient.new()
	g.set_color(0, HOT)
	g.set_color(1, Color(FIRE, 0.0))
	pm.color_ramp = GradientTexture1D.new()
	pm.color_ramp.gradient = g
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	q.material = _glow_mat(Color.WHITE, true)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _light(col: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	return l


## Unshaded additive material; `sprite` makes it a soft round billboard
## coloured by the particle's vertex colour.
static func _glow_mat(col: Color, sprite: bool) -> StandardMaterial3D:
	var key := [col, sprite]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	m.vertex_color_use_as_albedo = sprite
	if sprite:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_texture = _soft()
	_mats[key] = m
	return m


static func _soft() -> GradientTexture2D:
	if _sprite == null:
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color(1, 1, 1, 0))
		_sprite = GradientTexture2D.new()
		_sprite.gradient = g
		_sprite.fill = GradientTexture2D.FILL_RADIAL
		_sprite.fill_from = Vector2(0.5, 0.5)
		_sprite.fill_to = Vector2(1.0, 0.5)
		_sprite.width = 64
		_sprite.height = 64
	return _sprite
