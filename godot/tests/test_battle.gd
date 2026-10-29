extends SceneTree
## Headless checks for ship guns: godot --headless --path godot -s res://tests/test_battle.gd

var _fails := 0


func _init() -> void:
	seed(7)  # hits and crew are random: keep runs repeatable
	var a := _ship(Vector2.ZERO, 0.0)
	var b := _ship(Vector2(0.0, -40.0), PI)  # nose to nose, 40 m apart
	var ga := ShipGuns.new(a)
	var shots := [0, 0]  # fired, hit
	ga.shot.connect(func(_i, _t, h): shots[0] += 1; shots[1] += int(h))
	var hp := _hp(b)
	var low := hp
	for k in 30 * 30:
		for s in [a, b]:
			s._physics_process(1.0 / 30.0)
			s.sim._physics_process(1.0 / 30.0)
		ga.tick(b, 1.0 / 30.0)
		low = minf(low, _hp(b))
	_check(shots[0] > 3, "crewed guns open fire (%d shots)" % shots[0])
	_check(shots[1] > 0, "some shots hit (%d)" % shots[1])
	_check(low < hp - 1.0, "and hurt the enemy (crew patch it up after)")
	var far := _ship(Vector2(0.0, -500.0), PI)
	shots[0] = 0
	for k in 30 * 5:
		ga.tick(far, 1.0 / 30.0)
	_check(shots[0] == 0, "nothing fires out of range")
	_clash()
	_random_ships()
	print("battle tests: %s" % ("FAILED %d" % _fails if _fails else "ok"))
	quit(1 if _fails else 0)


## Two ships rammed together bounce apart and both take damage.
func _clash() -> void:
	var a := _ship(Vector2.ZERO, 0.0)
	var b := _ship(Vector2(0.0, -3.0), 0.0)  # overlapping by a cell
	a.vel = Vector2(0.0, -5.0)
	var ha := _hp(a)
	var hb := _hp(b)
	ShipClash.resolve(a, b)
	_check(a.vel.y > -5.0 and b.vel.y < 0.0, "rammed ships bounce apart")
	_check(_hp(a) < ha and _hp(b) < hb, "and both take damage")


## Random ships get main engines plus side thrusters to turn both ways,
## and the AI picks a plan that suits their guns.
func _random_ships() -> void:
	var bad := 0
	for k in 12:
		var b := ShipBody.new()
		b.setup(ShipGenerator.sandbox(k * 31 + 5), 0)
		b.helm.weigh()
		var mains := 0
		for i in b.sim.state.size():
			mains += int(b.helm.push(i).normalized().y < -0.9)
		var turns := [false, false]
		for i in b.sim.state.size():
			var t := b.helm.twist(i, b.helm.push(i))
			turns[int(t > 0.0)] = turns[int(t > 0.0)] or absf(t) > 1.0
		bad += int(mains < 2 or not (turns[0] and turns[1]))
		var ai := ShipTactics.new(b)
		ai.think(_ship(Vector2(0.0, -40.0), PI))
		bad += int(ai.plan == &"" or ai.plan == &"flee")
	_check(bad == 0, "random ships can fly, turn and fight (%d bad)" % bad)


## Bridge, a corridor under it, a laser turret and a charged capacitor.
func _ship(at: Vector2, turn: float) -> ShipBody:
	var d := ShipDesign.new()
	d.add(ModuleLibrary.by_id(&"bridge"), Vector2i.ZERO)
	for x in [0, 1]:
		d.add(ModuleLibrary.by_id(&"hull"), Vector2i(x, 2))
	d.add(ModuleLibrary.by_id(&"turret"), Vector2i(2, 2))
	d.add(ModuleLibrary.by_id(&"capacitor"), Vector2i(0, 3))  # charge for the laser
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
