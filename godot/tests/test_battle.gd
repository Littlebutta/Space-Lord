extends SceneTree
## Headless checks for ship guns: godot --headless --path godot -s res://tests/test_battle.gd

var _fails := 0


func _init() -> void:
	var a := _ship(Vector2.ZERO, 0.0)
	var b := _ship(Vector2(0.0, -40.0), PI)  # nose to nose, 40 m apart
	var ga := ShipGuns.new(a)
	var shots := [0]
	ga.shot.connect(func(_i, _f, _t, _h): shots[0] += 1)
	var hp := _hp(b)
	var low := hp
	for k in 30 * 30:
		for s in [a, b]:
			s._physics_process(1.0 / 30.0)
			s.sim._physics_process(1.0 / 30.0)
		ga.tick(b, 1.0 / 30.0)
		low = minf(low, _hp(b))
	_check(shots[0] > 3, "crewed guns open fire (%d shots)" % shots[0])
	_check(low < hp, "and hurt the enemy (crew patch it up after)")
	var far := _ship(Vector2(0.0, -500.0), PI)
	shots[0] = 0
	for k in 30 * 5:
		ga.tick(far, 1.0 / 30.0)
	_check(shots[0] == 0, "nothing fires out of range")
	print("battle tests: %s" % ("FAILED %d" % _fails if _fails else "ok"))
	quit(1 if _fails else 0)


## Bridge, a corridor under it and a laser turret off the corridor.
func _ship(at: Vector2, turn: float) -> ShipBody:
	var d := ShipDesign.new()
	d.add(ModuleLibrary.by_id(&"bridge"), Vector2i.ZERO)
	for x in [0, 1]:
		d.add(ModuleLibrary.by_id(&"hull"), Vector2i(x, 2))
	d.add(ModuleLibrary.by_id(&"turret"), Vector2i(2, 2))
	var b := ShipBody.new()
	b.setup(d, 6)
	b.at = Transform2D(turn, at)
	return b


func _hp(b: ShipBody) -> float:
	var sum := 0.0
	for h in b.sim.state.hp:
		sum += h
	return sum


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + what)
