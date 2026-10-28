class_name CrewCorpse
extends Node3D
## A dead crew member: the crew model goes limp (limbs flop loosely on
## their joints, like a cheap ragdoll) and tumbles off into space.

const LIMBS := [&"spine", &"head", &"arm.L", &"arm.R", &"hand.L", &"hand.R",
		&"thigh.L", &"thigh.R", &"shin.L", &"shin.R"]
const LIFE := 90.0  # seconds before the body is cleaned up
const FLOP := 1.1  # radians a limb swings at first
const SETTLE := 0.4  # how fast the flopping dies down

var vel := Vector3.ZERO
var spin := Vector3.ZERO
var _skel: Skeleton3D
var _bones := {}  # bone index -> [axis, speed, phase, rest rotation]
var _age := 0.0


static func spawn(parent: Node, at: Vector3, fling: Vector3, shirt: Color) -> CrewCorpse:
	var c := CrewCorpse.new()
	c.vel = fling
	c.spin = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	var body: Node3D = load(CrewLook.MODEL).instantiate()
	var mi: MeshInstance3D = body.find_children("*", "MeshInstance3D", true, false)[0]
	mi.material_override = CrewLook.material()
	mi.set_instance_shader_parameter(&"shirt", shirt.darkened(0.3))
	for ap in body.find_children("*", "AnimationPlayer", true, false):
		ap.queue_free()
	body.position.y = -0.9  # tumble round the waist, not the feet
	c.add_child(body)
	parent.add_child(c)
	c.global_position = at + Vector3.UP * 0.9
	c._limp(body)
	return c


func _limp(body: Node3D) -> void:
	_skel = body.find_children("*", "Skeleton3D", true, false)[0]
	for n in LIMBS:
		var b := _skel.find_bone(n)
		if b >= 0:
			var axis := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1))
			_bones[b] = [axis.normalized(), randf_range(1.5, 3.5), randf() * TAU,
					_skel.get_bone_pose_rotation(b)]


func _process(delta: float) -> void:
	_age += delta
	position += vel * delta
	if spin != Vector3.ZERO:
		rotate(spin.normalized(), spin.length() * delta)
	var amp := FLOP * (0.35 + 0.65 * exp(-_age * SETTLE))
	for b in _bones:
		var d: Array = _bones[b]
		var swing := Quaternion(d[0], sin(_age * d[1] + d[2]) * amp)
		_skel.set_bone_pose_rotation(b, d[3] * swing)
	if _age > LIFE:
		queue_free()
