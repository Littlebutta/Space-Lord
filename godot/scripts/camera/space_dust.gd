class_name SpaceDust
extends MultiMeshInstance3D
## Faint motes hanging still in space around the camera, so flying past
## them shows the ship moving even against a far-away sky. Motes wrap
## round a box that follows the camera; one draw call for all of them.

@export var count := 500
@export var box := 120.0  # metres across the dust box
@export var depth := 30.0  # metres of height the motes spread over

var _spots := PackedVector3Array()  # each mote's place, in box units 0..1


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.7, 0.75, 0.9, 0.35)
	quad.material = m
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = count
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in count:
		_spots.append(Vector3(randf(), randf(), randf()))
	top_level = true


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := cam.global_position
	var size := Vector3(box, depth, box)
	for k in count:
		var p := _spots[k] * size
		var at := Vector3(fposmod(p.x - c.x, box), fposmod(p.y, depth) - depth * 0.6,
				fposmod(p.z - c.z, box)) + Vector3(c.x - box * 0.5, 0.0, c.z - box * 0.5)
		multimesh.set_instance_transform(k, Transform3D(Basis(), at))
