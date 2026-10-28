extends SceneTree
## Headless crew checks: godot --headless --path godot -s res://tests/test_crew.gd

var _fails := 0


func _init() -> void:
	var pool: Array[ShipModule] = ModuleLibrary.all().filter(
			func(m): return m.category != "command")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var d := ShipGenerator.generate(ModuleLibrary.by_id(&"bridge"), pool, rng, 16)
	var sim := CrewSim.new()
	sim.setup(d, 30)
	var s := sim.state
	_run(sim, 40.0)
	var staffed := range(s.size()).all(func(i): return s.manned(i))
	_check(staffed, "every station staffed")
	for c in sim.crew:
		_check(sim.nav.walkable(c.pos), "%s stands on the deck" % c.name)
	var hurt: int = range(s.size()).filter(func(i): return s.module(i).crew > 0)[0]
	s.damage(hurt, 50.0)
	_run(sim, 15.0)
	_check(not s.damaged(hurt), "damaged module repaired")
	for c in sim.crew:
		c.priority[&"repair"] = 0
	s.damage(hurt, 50.0)
	_run(sim, 15.0)
	_check(s.damaged(hurt), "repair priority off: nobody repairs")
	var hungry: Array = range(s.size()).filter(func(i): return not s.module(i).upkeep.is_empty())
	for i in hungry:
		for res in s.stock[i]:
			s.stock[i][res] = 0.0
	_run(sim, 40.0)
	var fed := hungry.all(func(i): return s.is_running(i) or s.hp[i] < s.module(i).hp)
	_check(fed, "haulers restocked every module")
	print("crew tests: %s" % ("FAILED %d" % _fails if _fails else "ok"))
	sim.free()
	quit(1 if _fails else 0)


func _run(sim: CrewSim, seconds: float) -> void:
	for k in int(seconds * 30.0):
		sim._physics_process(1.0 / 30.0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + what)
