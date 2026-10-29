class_name CrewLook
extends Node3D
## Draws each crew member as the rigged Blender crew model, playing
## idle, walk or work and facing where they go or what they work on.
## Shirts are coloured by job through an instance uniform, so the
## whole crew shares one material.

const MODEL := "res://assets/models/human/crew.glb"  # fallback race
const SHADER := preload("res://assets/materials/crew.gdshader")
const WALK_SPEED := 1.3  # walk animation playback for CrewSim.SPEED
const TURN := 10.0  # how fast they turn to face, per second
const STEP := 0.42  # seconds between one walker's footsteps

static var _mat: ShaderMaterial
static var _ring_mesh: TorusMesh

var _kinds: Array[CrewSpecies] = []  # whose model each body is
var _step_cd: Array[float] = []  # each walker's time to next step
var _bodies: Array[Node3D] = []
var _players: Array[AnimationPlayer] = []
var _meshes: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []  # selection markers
var _suits: Array[MeshInstance3D] = []  # spacesuits, worn outside
var _crates: Array[MeshInstance3D] = []  # loads held while hauling


func draw(crew: Array[CrewMember], sim: CrewSim, delta: float) -> void:
	var keep := 0
	while keep < mini(crew.size(), _kinds.size()) and _kinds[keep] == crew[keep].species:
		keep += 1
	while _bodies.size() > keep:  # rebuild from the first body that's wrong
		_kinds.pop_back()
		_bodies.pop_back().queue_free()
		_players.pop_back()
		_meshes.pop_back()
		_rings.pop_back()
		_suits.pop_back()
		_crates.pop_back()
		_step_cd.pop_back()
	var ship := sim.state.design.theme(0)
	while _bodies.size() < crew.size():
		var sp := crew[_bodies.size()].species
		_kinds.append(sp)
		_step_cd.append(randf() * STEP)
		var own := CrewSpecies.of_theme(ship) == sp  # e.g. scrap crews look scrappy
		_spawn(race(ship if own else sp.look()))
	for k in crew.size():
		var c := crew[k]
		c.y = c.alt if c.eva else lerpf(c.y, sim.nav.height(c.pos), minf(delta * 10.0, 1.0))
		var b := _bodies[k]
		var at := Vector3(c.pos.x, c.y, c.pos.y)
		var face := _facing(c, sim, at)
		if face.length_squared() > 0.0001:
			var yaw := atan2(-face.x, -face.z)
			b.rotation.y = lerp_angle(b.rotation.y, yaw, minf(delta * TURN, 1.0))
		b.position = at
		_rings[k].visible = c.selected
		_play(k, _anim(c), c.species.speed)
		var col: Color = CrewJob.COLORS[c.job.type if c.job else &""]
		_meshes[k].set_instance_shader_parameter(&"shirt", col)
		_suits[k].visible = c.eva
		var ore := c.job != null and c.job.type == &"mine"  # ore chunks show themselves
		_crates[k].visible = c.cargo > 0.0 and not c.eva and not ore and c.species.carry
		if c.eva and is_inside_tree() and randf() < delta * 3.0:
			CrewGear.puff(_world(), b)
		_footstep(k, c, b, delta)


## The shared crew material; shirts are an instance uniform.
static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		_mat.set_shader_parameter(&"grime_tex", ModelSkin.noise(false))
		_mat.set_shader_parameter(&"bump_tex", ModelSkin.noise(true))
		_mat.set_shader_parameter(&"grime", 0.35)
	return _mat


func _spawn(model: PackedScene) -> void:
	var b: Node3D = model.instantiate()
	var mi := b.find_child("CrewBody*", true, false) as MeshInstance3D
	mi.material_override = material()
	var suit := b.find_child("CrewSuit*", true, false) as MeshInstance3D
	CrewGear.dress(suit)
	var crate := CrewGear.crate()
	b.add_child(crate)
	_suits.append(suit)
	_crates.append(crate)
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
	if c.eva:
		return &"float"
	if c.cargo > 0.0 and c.species.carry:
		return &"carry"
	if not c.arrived():
		return &"walk"
	return &"work" if c.job else &"idle"


func _play(k: int, anim: StringName, pace := 1.0) -> void:
	var ap := _players[k]
	if ap.current_animation != anim:
		ap.play(anim, 0.15)
		ap.speed_scale = WALK_SPEED * pace if anim in [&"walk", &"carry"] else 1.0
		ap.seek(randf() * ap.current_animation_length)  # don't march in step



## The crew model for theme `t`'s race (its crew.glb), else human.
static func race(t: ShipTheme) -> PackedScene:
	var p := t.model_dir.path_join("crew.glb") if t and not t.model_dir.is_empty() else MODEL
	return load(p if ResourceLoader.exists(p) else MODEL)


## Each walker's boots patter softly on their own beat.
func _footstep(k: int, c: CrewMember, b: Node3D, delta: float) -> void:
	_step_cd[k] -= delta * c.species.speed
	if c.eva or c.arrived() or _step_cd[k] > 0.0 or not is_inside_tree():
		return
	_step_cd[k] = STEP * randf_range(0.9, 1.1)
	Sfx.play(_world(), &"footstep", b.global_position, -24.0, 12.0)


## Where puffs and sounds go: the scene, or this node when there's none.
func _world() -> Node:
	var s := get_tree().current_scene
	return s if s else self
