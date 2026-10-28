extends Camera3D
## Top-down orbit camera shared by the system map and RTS battles.
## WASD pans, Q/E rotates, mouse wheel zooms.

@export var focus := Vector3.ZERO
@export var distance := 140.0
@export var zoom_range := Vector2(15.0, 400.0)
@export var pitch_deg := -55.0
@export var yaw_deg := 0.0
@export var pan_speed := 1.2  # scaled by distance


func _process(delta: float) -> void:
	var move := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	move += _wasd()
	var basis_y := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var step := Vector3(move.x, 0.0, move.y) * pan_speed * distance * delta
	focus += basis_y * step
	if Input.is_key_pressed(KEY_Q):
		yaw_deg += 90.0 * delta
	if Input.is_key_pressed(KEY_E):
		yaw_deg -= 90.0 * delta
	var rot := basis_y * Basis(Vector3.RIGHT, deg_to_rad(pitch_deg))
	transform = Transform3D(rot, focus + rot * Vector3(0, 0, distance))


func _wasd() -> Vector2:
	var v := Vector2.ZERO
	v.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	v.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	return v


func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b == null or not b.pressed:
		return
	if b.button_index == MOUSE_BUTTON_WHEEL_UP:
		distance = maxf(zoom_range.x, distance * 0.9)
	elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		distance = minf(zoom_range.y, distance * 1.1)
