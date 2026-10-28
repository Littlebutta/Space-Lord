class_name CrewLook
extends Node3D
## Draws each crew member as the rigged Blender crew model, playing
## idle, walk or work and facing where they go or what they work on.
## Shirts are coloured by job through an instance uniform, so the
## whole crew shares one material.

const MODEL := preload("res://assets/models/human/crew.glb")
const SHADER := preload("res://assets/materials/crew.gdshader")
const WALK_SPEED := 1.3  # walk animation playback for CrewSim.SPEED
const TURN := 10.0  # how fast they turn to face, per second

static var _mat: ShaderMaterial
static var _ring_mesh: TorusMesh

var _bodies: Array[Node3D] = []
var _players: Array[AnimationPlayer] = []
var _meshes: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []  # selection markers


func draw(crew: Array[CrewMember], sim: CrewSim, delta: float) -> void:
	while _bodies.size() < crew.size():
		_spawn()
	while _bodies.size() > crew.size():
		_bodies.pop_back().queue_free()
		_players.pop_back()
		_meshes.pop_back()
		_rings.pop_back()
	for k in crew.size():
		var c := crew[k]
		c.y = lerpf(c.y, sim.nav.height(c.pos), minf(delta * 10.0, 1.0))
		var b := _bodies[k]
		var at := Vector3(c.pos.x, c.y, c.pos.y)
		var face := _facing(c, sim, at)
		if face.length_squared() > 0.0001:
			var yaw := atan2(-face.x, -face.z)
			b.rotation.y = lerp_angle(b.rotation.y, yaw, minf(delta * TURN, 1.0))
		b.position = at
		_rings[k].visible = c.selected
		_play(k, _anim(c))
		var col: Color = CrewJob.COLORS[c.job.type if c.job else &""]
		_meshes[k].set_instance_shader_parameter(&"shirt",
				col.lightened(0.4) if c.cargo > 0.0 else col)


func _spawn() -> void:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		_mat.set_shader_parameter(&"grime_tex", ModelSkin.noise(false))
		_mat.set_shader_parameter(&"bump_tex", ModelSkin.noise(true))
		_mat.set_shader_parameter(&"grime", 0.35)
	var b: Node3D = MODEL.instantiate()
	var mi: MeshInstance3D = b.find_children("*", "MeshInstance3D", true, false)[0]
	mi.material_override = _mat
	var ap: AnimationPlayer = b.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ap.get_animation_list():
		ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	b.add_child(_ring())
	add_child(b)
	_bodies.append(b)
	_players.append(ap)
	_meshes.append(mi)


func _ring() -> MeshInstance3D:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.34
		_ring_mesh.outer_radius = 0.4
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.4, 0.85, 1.0)
		_ring_mesh.material = m
	var r := MeshInstance3D.new()
	r.mesh = _ring_mesh
	r.position.y = 0.03
	r.scale.y = 0.3
	_rings.append(r)
	return r


## Direction to face: along the path when walking; at work, their
## module's equipment next to them (its blocked deck), else the bow when
## operating, else the job module.
func _facing(c: CrewMember, sim: CrewSim, at: Vector3) -> Vector3:
	if not c.arrived():
		var to := c.path[0]
		return Vector3(to.x, at.y, to.y) - at
	if c.job and c.job.module >= 0 and c.job.module < sim.state.size():
		var n := sim.nav.cell(c.pos)
		var own: Vector2i = sim.state.design.cells[c.job.module]
		for dir in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			if sim.nav.solid.get(n + dir) == own:
				return Vector3(dir.x, 0.0, dir.y)
		if c.job.type == &"operate":
			var turn := sim.state.design.turns[c.job.module]
			return Vector3.FORWARD.rotated(Vector3.UP, -turn * PI / 2.0)
		var m := sim.state.center(c.job.module)
		return Vector3(m.x, at.y, m.y) - at
	return Vector3.ZERO


static func _anim(c: CrewMember) -> StringName:
	if not c.arrived():
		return &"walk"
	return &"work" if c.job else &"idle"


func _play(k: int, anim: StringName) -> void:
	var ap := _players[k]
	if ap.current_animation != anim:
		ap.play(anim, 0.15)
		ap.speed_scale = WALK_SPEED if anim == &"walk" else 1.0
		ap.seek(randf() * ap.current_animation_length)  # don't march in step

