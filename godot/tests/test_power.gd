extends SceneTree
## Headless checks for reactors, capacitors and power-hungry lasers:
## godot --headless --path godot -s res://tests/test_power.gd

var _fails := 0


func _init() -> void:
	var s := ShipState.new(_ship(true), 0.0)
	_check(s.power.capacity() == 170.0, "reactor buffer plus capacitor")
	s.stock[1]["fuel"] = 1.0
	s.power.tick(10.0)
	_check(s.power.charge == 100.0, "fuelled reactor charges the grid")
	var shots := [0]
	s.fired.connect(func(_i): shots[0] += 1)
	s.operators[3] = 2
	var n := 0
	while s.shoot(3):
		n += 1
	_check(n == 6 and shots[0] == 6, "laser fires on power, not ammo (%d)" % n)
	_check(not s.can_shoot(3), "drained grid: laser can't fire")
	s.stock[1]["fuel"] = 0.0
	s.power.tick(10.0)
	_check(s.power.charge < 15.0, "no fuel, no power")
	var bare := ShipState.new(_ship(false), 0.0)
	bare.stock[1]["fuel"] = 1.0
	bare.power.tick(100.0)
	_check(bare.power.charge == 20.0, "no capacitor: only the reactor buffer")
	_check(ShipStats.of(_ship(true)).power_out == 10.0, "stats count reactor output")
	print("power tests: %s" % ("FAILED %d" % _fails if _fails else "ok"))
	quit(1 if _fails else 0)


## Bridge, reactor, optional capacitor, laser turret.
func _ship(cap: bool) -> ShipDesign:
	var d := ShipDesign.new()
	d.add(ModuleLibrary.by_id(&"bridge"), Vector2i.ZERO)
	d.add(ModuleLibrary.by_id(&"generator"), Vector2i(2, 0))
	d.add(ModuleLibrary.by_id(&"capacitor" if cap else &"hull"), Vector2i(4, 0))
	d.add(ModuleLibrary.by_id(&"turret"), Vector2i(0, 2))
	return d


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
