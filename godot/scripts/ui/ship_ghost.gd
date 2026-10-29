class_name ShipGhost
extends Node3D
## A see-through copy of a ship, shown while right-dragging a move order
## so you can see where it will end up and which way it will face.

const COLOR := Color(0.35, 0.9, 1.0, 0.1)


## Rebuilds the copy from the meshes `b` shows right now.
func copy(b: ShipBody) -> void:
	top_level = true
	for c in get_children():
		c.queue_free()
	var inv := b.global_transform.affine_inverse()
	for m: MeshInstance3D in b.hulk.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var g := MeshInstance3D.new()
		g.mesh = m.mesh
		g.transform = inv * m.global_transform
		g.material_override = FxKit.glow_mat(COLOR, false)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)


## Puts the copy with b's pivot on world point `to`, nose along `dir`.
func place(b: ShipBody, to: Vector2, dir: Vector2) -> void:
	var t := Transform2D(b.at.get_rotation() + (-b.at.y).angle_to(dir), Vector2.ZERO)
	t.origin = to - t.basis_xform(b.pivot())
	global_transform = ShipPieces.to_3d(t)
