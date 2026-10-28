class_name GunFx
extends RefCounted
## Weapon effects. Cannons: a flash with a forward flare, sparks, a puff
## of smoke, a hot slug and a burst where it lands. Lasers: a red beam
## that snaps out and thins away, with a glow at each end. Built from
## FxKit's sprite, materials and particles.

const SLUG := Color(1.0, 0.7, 0.35)
const LASER := Color(1.0, 0.12, 0.08)
const RANGE := 60.0  # metres the shot travels before it bursts


## Cannon shot from muzzle `m` (fires along its -z).
static func cannon(world: Node, m: Node3D) -> void:
	_flash(m, FxKit.HOT, 2.2)
	_smoke(world, m.global_position)
	var xf := m.global_transform
	var end := xf.origin - xf.basis.z.normalized() * RANGE
	var slug := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.14, 2.6)
	bm.material = FxKit.glow_mat(SLUG, false)
	slug.mesh = bm
	slug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(slug)
	slug.global_transform = xf
	slug.add_child(FxKit.light(SLUG, 2.0, 5.0))
	var tw := slug.create_tween()
	tw.tween_property(slug, "global_position", end, RANGE / 160.0)
	tw.tween_callback(_impact.bind(world, end, SLUG))
	tw.tween_callback(slug.queue_free)


## Laser shot from muzzle `m`: a beam that lasts a moment.
static func laser(world: Node, m: Node3D) -> void:
	_flash(m, LASER, 1.2)
	var xf := m.global_transform
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.07
	cm.height = RANGE
	cm.radial_segments = 8
	cm.material = FxKit.glow_mat(LASER, false)
	beam.mesh = cm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core := MeshInstance3D.new()  # white-hot centre
	var cc := cm.duplicate() as CylinderMesh
	cc.top_radius = 0.025
	cc.bottom_radius = 0.025
	cc.material = FxKit.glow_mat(Color(1, 0.75, 0.7), false)
	core.mesh = cc
	beam.add_child(core)
	world.add_child(beam)
	var fwd := -xf.basis.z.normalized()
	beam.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, fwd)),
			xf.origin + fwd * RANGE * 0.5)
	var tw := beam.create_tween()
	tw.tween_property(beam, "scale", Vector3(0.05, 1.0, 0.05), 0.3)
	tw.tween_callback(beam.queue_free)
	_impact(world, xf.origin + fwd * RANGE, LASER)


## Muzzle pop: a round flash, a flare stretched forward, sparks, light.
static func _flash(m: Node3D, col: Color, size: float) -> void:
	var root := Node3D.new()
	m.add_child(root)
	var s := FxKit.particles(22, 0.3, Vector3(0, 0, -1), 22.0, Vector2(10, 20), 0.16)
	s.one_shot = true
	s.explosiveness = 1.0
	_tint(s, col)
	root.add_child(s)
	for k in 2:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(size, size) if k == 0 else Vector2(size * 0.5, size * 1.8)
		qm.material = FxKit.glow_mat(col, true) if k == 0 else FxKit.glow_mat(col, false)
		q.mesh = qm
		q.position.z = -0.3 - k * size * 0.8
		if k == 1:
			q.rotation.x = -PI / 2.0
		root.add_child(q)
		root.create_tween().tween_property(q, "scale", Vector3.ONE * 0.05, 0.1 + k * 0.05)
	var l := FxKit.light(col, 7.0, 10.0)
	root.add_child(l)
	var tw := root.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.2)
	tw.tween_interval(0.6)
	tw.tween_callback(root.queue_free)


## Grey smoke that drifts off the muzzle and fades.
static func _smoke(world: Node, at: Vector3) -> void:
	var p := FxKit.particles(10, 1.4, Vector3(0, 0.3, -1), 35.0, Vector2(0.5, 1.6), 0.9)
	p.one_shot = true
	p.explosiveness = 0.9
	var m := (p.draw_pass_1 as QuadMesh).material.duplicate() as StandardMaterial3D
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	p.draw_pass_1 = p.draw_pass_1.duplicate()
	(p.draw_pass_1 as QuadMesh).material = m
	_tint(p, Color(0.55, 0.55, 0.55, 0.5))
	world.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)


static func _impact(world: Node, at: Vector3, col: Color) -> void:
	Sfx.play(world, &"impact", at, -3.0, 70.0)
	var p := FxKit.particles(26, 0.45, Vector3.UP, 180.0, Vector2(4, 12), 0.35)
	p.one_shot = true
	p.explosiveness = 1.0
	_tint(p, col)
	world.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	var l := FxKit.light(col, 5.0, 8.0)
	world.add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## Recolours a particle system's fade from `col` to transparent.
static func _tint(p: GPUParticles3D, col: Color) -> void:
	var pm := p.process_material as ParticleProcessMaterial
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col, 0.0))
	pm.color_ramp = GradientTexture1D.new()
	pm.color_ramp.gradient = g
