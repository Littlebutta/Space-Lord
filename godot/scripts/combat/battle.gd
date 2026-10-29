extends Node3D
## Battle sandbox: your ship (the saved design, or a random one) against
## a random enemy. Both crews run their ships; guns fire on their own at
## whatever is in range. A ship whose bridge is cut off or destroyed is beaten, and guns stop
## shooting at it unless you right click it again to finish it off.
## The enemy fights to suit its guns (ShipTactics).

const START := 55.0  # metres apart at the start, inside gun range
const HELP := "Click your ship, right click to fly · right click a beaten enemy to keep firing\n" \
		+ "E stop · left click/drag select crew, right click order them · Space follow\n" \
		+ "V outside view · Alt/H module cards · Esc map · WASD pan · middle mouse rotate · wheel zoom"

@onready var _me: ShipBody = $Me
@onready var _foe: ShipBody = $Foe
var _hud := ShipHud.new()
var _attack := false  # ordered to keep shooting a beaten enemy
var _marker := MoveMarker.new()
var _guns: Array[ShipGuns] = []
var _follow := true
var _last := Vector2.ZERO
var _think := 0.0
var _ai: ShipTactics


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
		g.shot.connect(func(_i, to, hit): if hit: FxKit.sparks(self, to))
		_guns.append(g)  # ShipBody's own ShipFx shows each shot via state.fired
	_foe.at = Transform2D(PI, Vector2(0.0, -START))  # nose to nose
	_foe.hulk.sealed = true  # never see inside the enemy, only broken-off bits
	_foe.sim.sealed = true
	_ai = ShipTactics.new(_foe)
	$Panel.bind(_me.sim)
	$UI/Tags.bind(_me)
	$UI/Tags.guns = _guns[0]
	_hud.bind($UI, _me, _foe)
	_hud.engaged = func(): return _guns[0].engaged()
	UiKit.help($UI, HELP)
	$UI/Orders.bind(_me)
	add_child(_marker)
	_marker.bind(_me, $UI/Orders)
	_last = _me.world(_me.pivot())
	$Camera.focus = Vector3(_last.x, 0.0, _last.y - START * 0.5)


func _physics_process(delta: float) -> void:
	_guns[0].hold = _beaten(_foe) and not _attack
	_guns[1].hold = _beaten(_me)
	_guns[0].tick(_foe, delta)
	_guns[1].tick(_me, delta)
	ShipClash.resolve(_me, _foe)
	_think -= delta
	if _think <= 0.0:
		_think = 1.0
		if _beaten(_foe):
			_foe.goal = null
			_foe.look = null
		else:
			_ai.think(_me)


func _process(_delta: float) -> void:
	var mid := _me.world(_me.pivot())
	if _follow:
		$Camera.focus += Vector3(mid.x - _last.x, 0.0, mid.y - _last.y)
	_last = mid
	var won := _beaten(_foe)
	_hud.say("" if not (won or _beaten(_me)) else ("VICTORY" if won else "DEFEAT") + " · Esc to map")


## Beaten: the bridge is gone or cut off from the ship.
func _beaten(b: ShipBody) -> bool:
	var p := b.sim.state.pieces
	return p.main < 0 or not p.has_bridge(p.main)


## World point p lies on one of b's intact modules.
func _on(b: ShipBody, p: Vector2) -> bool:
	var s := b.sim.state
	for k in s.size():
		var r := Vector2(s.design.rect(k).size).length() * ShipView.CELL * 0.5
		if s.hp[k] > 0.0 and b.world(s.pieces.world(k)).distance_to(p) < r:
			return true
	return false


## Alt (or H) toggles the module cards; caught in _input like the crew
## sandbox does, before a focused button can swallow it.
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.keycode == KEY_ALT \
			or k.physical_keycode == KEY_ALT or k.keycode == KEY_H):
		$UI/Tags.visible = not $UI/Tags.visible
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b and b.pressed and b.button_index == MOUSE_BUTTON_RIGHT and $UI/Orders.ship_selected:
		var cam: Camera3D = $Camera
		var hit = Plane(Vector3.UP, 0.0).intersects_ray(
				cam.project_ray_origin(b.position), cam.project_ray_normal(b.position))
		if hit != null and _on(_foe, Vector2(hit.x, hit.z)):
			_attack = _beaten(_foe)  # only a fresh order counts once it's beaten
		elif hit != null:
			_me.goal = Vector2(hit.x, hit.z)
			_marker.ping(_me.goal)
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_E: _me.halt()
		KEY_SPACE: _follow = not _follow
		KEY_V: _me.hulk.outside = not _me.hulk.outside
		KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/main.tscn")
