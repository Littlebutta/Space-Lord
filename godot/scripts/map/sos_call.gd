class_name SosCall
extends Node3D
## The ship answering an SOS (Fleet.sos): it flies in from the dark in
## game time, pulls up alongside, pauses the clock and opens the talk.

var _ship: MapShip
var _talk: SosTalk


func _process(_delta: float) -> void:
	if Fleet.sos.is_empty():
		if _ship:
			_ship.queue_free()
			_ship = null
		return
	if _ship == null:
		_ship = MapShip.new()
		add_child(_ship)
		_ship.show_design(ShipGenerator.sandbox(Fleet.sos.seed, 10), Color(1, 0.7, 0.3))
	var from: Vector3 = Fleet.sos.from
	var to := Travel.pos + (from - Travel.pos).normalized() * MapShip.SIZE * 1.6
	var t := Fleet.sos_progress(GameClock.hours)
	_ship.position = from.lerp(to, t) + Vector3.UP
	_ship.rotation.y = atan2(-(to - from).x, -(to - from).z)
	_ship.moving = t < 1.0
	if t >= 1.0 and not is_instance_valid(_talk):
		GameClock.speed = 0
		_talk = SosTalk.new()
		_talk.kind = Fleet.sos.kind
		_talk.finished.connect(func(): GameClock.speed = 1)
		add_child(_talk)
