extends SceneTree
## Headless checks for ships breaking apart and crew spacewalks:
## godot --headless --path godot -s res://tests/test_wreck.gd

var _fails := 0
var _outside := false  # someone went on a spacewalk


func _init() -> void:
	var d := ShipDesign.new()
	d.add(ModuleLibrary.by_id(&"bridge"), Vector2i.ZERO)
	d.add(ModuleLibrary.by_id(&"airlock"), Vector2i(0, 2))
	for x in [2, 3, 4]:
		d.add(ModuleLibrary.by_id(&"hull"), Vector2i(x, 0))
	var sim := CrewSim.new()
	sim.setup(d, 4)
	var s := sim.state
	var p := s.pieces
	_check(p.pieces.size() == 1 and not p.drifting(4), "starts in one piece")
	s.damage(2, INF)
	_check(p.pieces.size() == 2 and p.drifting(4), "cut in half")
	_check(not p.powered(4) and p.powered(0), "loose piece loses power")
	var parts := s.storage.get_amount("parts")
	_run(sim, 2.0)
	_check(p.world(4).distance_to(p.home(4)) > 0.3, "loose piece drifts away")
	_run(sim, 60.0)
	_check(not p.drifting(4) and p.pieces.size() == 1, "crew reattached it")
	_check(_outside, "crew went outside through the airlock")
	_check(s.hp[2] > 0.0, "gap rebuilt")
	_check(s.storage.get_amount("parts") < parts, "reattaching cost parts")
	for c in sim.crew:
		_check(not c.eva and sim.nav.walkable(c.pos), "%s back inside" % c.name)
	s.storage.take("parts", INF)
	s.damage(2, INF)
	_run(sim, 20.0)
	_check(p.drifting(4), "no parts: piece stays adrift")
	var c: CrewMember = sim.crew[0]
	c.pos = p.home(3)
	s.damage(3, INF)
	_check(not sim.crew.has(c), "crew on a wrecked module die")
	print("wreck tests: %s" % ("FAILED %d" % _fails if _fails else "ok"))
	sim.free()
	quit(1 if _fails else 0)


func _run(sim: CrewSim, seconds: float) -> void:
	for k in int(seconds * 30.0):
		sim._physics_process(1.0 / 30.0)
		_outside = _outside or sim.crew.any(func(c): return c.eva)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + what)
