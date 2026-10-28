extends Node3D
## Battle sandbox: your ship (the saved design, or a random one) against
## a random enemy. Both crews run their ships; guns fire on their own at
## whatever is in range. The enemy closes to gun range and circles. A
## ship whose bridge is cut off or destroyed is beaten.

const START := 55.0  # metres apart at the start, inside gun range
const STANDOFF := 35.0  # the enemy circles at about this range
const HELP := "Battle · right click fly · left click/drag select crew, right click order them" \
		+ " · Space follow · Alt module cards · Esc map\nWASD pan · middle mouse rotate · wheel zoom"

@onready var _me: ShipBody = $Me
@onready var _foe: ShipBody = $Foe
@onready var _info: Label = $UI/Info
var _guns: Array[ShipGuns] = []
var _follow := true
var _last := Vector2.ZERO
var _think := 0.0


func _ready() -> void:
	var mine := ShipGenerator.sandbox(randi())
	if ResourceLoader.exists("user://ships/player.tres"):
		var saved := load("user://ships/player.tres") as ShipDesign
		mine = saved if saved and not saved.modules.is_empty() else mine
	var theirs := ShipGenerator.sandbox(randi())
	for b: ShipBody in [_me, _foe]:
		var d := mine if b == _me else theirs
		b.setup(d, maxi(int(d.total(&"berths")), int(d.total(&"crew")) + 2))
		var g := ShipGuns.new(b)
		g.shot.connect(func(i, from, to, hit): $Tracers.add(from, to, hit); b.fired.emit(i))
		_guns.append(g)
	_foe.at = Transform2D(PI, Vector2(0.0, -START))  # nose to nose
	$Panel.bind(_me.sim)
	$UI/Tags.bind(_me)
	$UI/Orders.bind(_me)
	_last = _me.world(_me.pivot())
	$Camera.focus = Vector3(_last.x, 0.0, _last.y - START * 0.5)


func _physics_process(delta: float) -> void:
	_guns[0].tick(_foe, delta)
	_guns[1].tick(_me, delta)
	_think -= delta
	if _think <= 0.0:
		_think = 1.0
		_steer_foe()


## The enemy heads for a spot at standoff range, sliding round you.
func _steer_foe() -> void:
	var me := _me.world(_me.pivot())
	var off := (_foe.world(_foe.pivot()) - me).normalized().rotated(0.35)
	_foe.goal = me + off * STANDOFF


func _process(_delta: float) -> void:
	var mid := _me.world(_me.pivot())
	if _follow:
		$Camera.focus += Vector3(mid.x - _last.x, 0.0, mid.y - _last.y)
	_last = mid
	var t := "You: %s · Enemy: %s\n" % [_status(_me), _status(_foe)]
	if _beaten(_foe) or _beaten(_me):
		t = ("VICTORY" if _beaten(_foe) else "DEFEAT") + " · Esc back to the map\n" + t
	_info.text = t + HELP


func _status(b: ShipBody) -> String:
	var s := b.sim.state
	var hp := 0.0
	var top := 0.0
	for i in s.size():
		hp += s.hp[i]
		top += s.module(i).hp
	return "hull %d%% · crew %d · speed %.1f" % [roundi(100.0 * hp / top), b.sim.crew.size(),
			b.vel.length()]


## Beaten: the bridge is gone or cut off from the ship.
func _beaten(b: ShipBody) -> bool:
	var p := b.sim.state.pieces
	return p.main < 0 or not p.has_bridge(p.main)


func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b and b.pressed and b.button_index == MOUSE_BUTTON_RIGHT:
		var cam: Camera3D = $Camera
		var hit = Plane(Vector3.UP, 0.0).intersects_ray(
				cam.project_ray_origin(b.position), cam.project_ray_normal(b.position))
		if hit != null:
			_me.goal = Vector2(hit.x, hit.z)
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE: _follow = not _follow
		KEY_ALT: $UI/Tags.visible = not $UI/Tags.visible
		KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/main.tscn")
