class_name CrewGear
extends RefCounted
## What a crew member wears and carries: the spacesuit (helmet and
## jetpack, shown on spacewalks), the crate held at the chest while
## hauling, and the little jetpack puffs that steer them outside.

const PUFF := Color(0.85, 0.92, 1.0, 0.8)
const JETS := [Vector3(-0.11, 1.07, 0.22), Vector3(0.11, 1.07, 0.22),
		Vector3(-0.11, 1.41, 0.22), Vector3(0.11, 1.41, 0.22)]

static var _crate: BoxMesh


## Gives the suit mesh its materials (glass helmet, lit trim) and hides it.
static func dress(suit: MeshInstance3D) -> void:
	for k in suit.mesh.get_surface_count():
		var m := suit.mesh.surface_get_material(k)
		var id := m.resource_name if m else ""
		var use: Material = CrewLook.material()
		if id.begins_with("Glass"):
			use = ModelSkin.glass_material()
		elif id.begins_with("Glow"):
			use = ModelSkin.glow_material()
		suit.set_surface_override_material(k, use)
	suit.visible = false


## A crate held in front of the chest (child of the crew body).
static func crate() -> MeshInstance3D:
	if _crate == null:
		_crate = BoxMesh.new()
		_crate.size = Vector3(0.42, 0.3, 0.32)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.42, 0.45, 0.32)
		m.roughness = 0.75
		_crate.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = _crate
	mi.position = Vector3(0, 1.05, -0.3)
	mi.visible = false
	return mi


## One short jet puff from a random nozzle of `body`'s jetpack, kicking
## out in a random direction, into `world`.
static func puff(world: Node, body: Node3D) -> void:
	var p := FxKit.particles(6, 0.35, Vector3.ZERO, 180.0, Vector2(1.0, 2.5), 0.12)
	p.one_shot = true
	p.explosiveness = 1.0
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
	pm.spread = 12.0
	var g := Gradient.new()
	g.set_color(0, PUFF)
	g.set_color(1, Color(PUFF, 0.0))
	pm.color_ramp = GradientTexture1D.new()
	pm.color_ramp.gradient = g
	world.add_child(p)
	p.global_position = body.global_transform * JETS[randi() % JETS.size()]
	p.finished.connect(p.queue_free)
