class_name FxKit
extends RefCounted
## Builders for ship effects: engine exhaust, sparks and floating debris
## (gun effects are in GunFx). Everything is made in code from a soft
## round sprite and a few shared materials, so there are no texture
## files and effects batch well.

const FIRE := Color(1.0, 0.62, 0.25)
const HOT := Color(1.0, 0.9, 0.7)

static var _sprite: GradientTexture2D
static var _mats := {}  # Color -> additive billboard material
static var _wreck: Array[Mesh] = []


## Engine plume: core cone, particle trail and a warm light, blowing +z.
static func exhaust() -> Node3D:
	var root := Node3D.new()
	root.name = &"FxExhaust"
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.55
	cm.height = 1.8
	cm.material = glow_mat(Color(1.0, 0.7, 0.35, 0.55), false)
	cone.mesh = cm
	cone.rotation.x = -PI / 2.0
	cone.position.z = 0.9
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cone)
	var p := particles(64, 0.55, Vector3(0, 0, 1), 6.0, Vector2(7.0, 10.0), 0.9)
	p.local_coords = false  # leaves a trail when the ship moves
	root.add_child(p)
	var l := light(FIRE, 2.5, 6.0)
	l.position.z = 0.6
	root.add_child(l)
	return root


## A short shower of sparks at world point `at`.
static func sparks(parent: Node, at: Vector3) -> void:
	var p := particles(14, 0.5, Vector3.UP, 70.0, Vector2(2.0, 5.0), 0.08)
	p.one_shot = true
	p.explosiveness = 0.9
	(p.process_material as ParticleProcessMaterial).gravity = Vector3(0, -6, 0)
	parent.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)


## A destroyed module: fireball, sparks and wreckage (hull shards, bent
## struts, torn panels and bolts) that tumbles away over ten seconds.
static func debris(parent: Node, xf: Transform3D, size: Vector2) -> void:
	var n := clampf(size.x * size.y * 2.0, 3.0, 14.0)
	for k in _wreck_meshes().size():
		for half in 2:  # two tilts each, so pieces spin on different axes
			var p := _chunks(_wreck_meshes()[k], int(n * (1.0 if k == 3 else 0.5)), size)
			parent.add_child(p)
			var tilt := Basis.from_euler(Vector3(randf(), randf(), randf()) * TAU)
			p.global_transform = Transform3D(xf.basis * tilt, xf.origin)
			p.finished.connect(p.queue_free)
	var boom := particles(24, 0.55, Vector3.UP, 180.0, Vector2(3.0, 7.0), 0.8)
	boom.one_shot = true
	boom.explosiveness = 1.0
	parent.add_child(boom)
	boom.global_position = xf.origin + Vector3.UP
	boom.finished.connect(boom.queue_free)
	sparks(parent, xf.origin + Vector3.UP)


## One kind of wreckage flung out of a `size` footprint, tumbling.
static func _chunks(mesh: Mesh, n: int, size: Vector2) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(n, 1)
	p.lifetime = 10.0
	p.one_shot = true
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(size.x, 0.8, size.y)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3.ZERO
	pm.damping_min = 0.02
	pm.damping_max = 0.15
	pm.angular_velocity_min = -240.0
	pm.angular_velocity_max = 240.0
	pm.particle_flag_rotate_y = true
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	var g := Gradient.new()  # random greys, the odd charred or painted bit
	g.offsets = PackedFloat32Array([0.0, 0.6, 0.85, 1.0])
	g.colors = PackedColorArray([Color(0.75, 0.77, 0.8), Color(0.45, 0.47, 0.5),
			Color(0.15, 0.14, 0.13), Color(0.25, 0.42, 0.75)])
	pm.color_initial_ramp = GradientTexture1D.new()
	pm.color_initial_ramp.gradient = g
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.visibility_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)
	return p


## Shard, bent strut, torn panel and bolt meshes, made once.
static func _wreck_meshes() -> Array[Mesh]:
	if not _wreck.is_empty():
		return _wreck
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.6
	mat.roughness = 0.45
	var shard := PrismMesh.new()
	shard.size = Vector3(0.7, 0.5, 0.05)
	shard.left_to_right = 0.2
	var st := SurfaceTool.new()  # a strut bent in the middle
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.045
	rod.bottom_radius = 0.045
	rod.height = 0.7
	rod.radial_segments = 6
	for s in [-1.0, 1.0]:
		var b := Basis(Vector3.FORWARD, s * 0.45)
		st.append_from(rod, 0, Transform3D(b, b * Vector3(0, 0.33 * s, 0)))
	var panel := BoxMesh.new()
	panel.size = Vector3(0.8, 0.04, 0.5)
	var bolt := CylinderMesh.new()
	bolt.top_radius = 0.05
	bolt.bottom_radius = 0.05
	bolt.height = 0.08
	bolt.radial_segments = 6
	shard.material = mat
	panel.material = mat
	bolt.material = mat
	var bent := st.commit()
	bent.surface_set_material(0, mat)
	_wreck.assign([shard, bent, panel, bolt])
	return _wreck


static func particles(n: int, life: float, dir: Vector3, spread: float,
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
	q.material = glow_mat(Color.WHITE, true)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func light(col: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	return l


## Unshaded additive material; `sprite` makes it a soft round billboard
## coloured by the particle's vertex colour.
static func glow_mat(col: Color, sprite: bool) -> StandardMaterial3D:
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
