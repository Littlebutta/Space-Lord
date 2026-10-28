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
	var can_run := range(s.size()).filter(func(i): return _stocked(s, i))
	var staffed := can_run.all(func(i): return s.manned(i))
	_check(staffed, "every station staffed")
	for c in sim.crew:
		_check(sim.nav.walkable(c.pos), "%s stands on the deck" % c.name)
	var close := 0
	for a in sim.crew:
		for b in sim.crew:
			if a != b and a.arrived() and b.arrived() and a.pos.distance_to(b.pos) < CrewSim.RADIUS:
				close += 1
	_check(close == 0, "nobody standing inside anyone else (%d)" % close)
	var hurt: int = range(s.size()).filter(func(i): return s.module(i).crew > 0)[0]
	s.damage(hurt, 50.0)
	_run(sim, 15.0)
	_check(not s.damaged(hurt), "damaged module repaired")
	for c in sim.crew:
		c.priority[&"repair"] = 0
	s.damage(hurt, 50.0)
	_run(sim, 15.0)
	_check(s.damaged(hurt), "repair priority off: nobody repairs")
	var hungry: Array = can_run.filter(func(i): return not s.module(i).upkeep.is_empty())
	for i in hungry:
		for res in s.stock[i]:
			s.stock[i][res] = 0.0
	_run(sim, 40.0)
	var fed := hungry.all(func(i): return s.is_running(i) or s.hp[i] < s.module(i).hp)
	_check(fed, "haulers restocked every module")
	_check_depot()
	_check_species()
	print("crew tests: %s" % ("FAILED %d" % _fails if _fails else "ok"))
	sim.free()
	quit(1 if _fails else 0)


## Haulers restock from a Supply Depot over an equally near cargo hold.
func _check_depot() -> void:
	var d := ShipDesign.new()
	d.add(ModuleLibrary.by_id(&"bridge"), Vector2i.ZERO)
	d.add(ModuleLibrary.by_id(&"cargo_hold"), Vector2i(2, 0))
	d.add(ModuleLibrary.by_id(&"supply_depot"), Vector2i(0, 2))
	var sim := CrewSim.new()
	sim.setup(d, 3)
	sim.state.stock[0]["food"] = 0.0
	var from_depot := false
	for k in 600:
		sim._physics_process(1.0 / 30.0)
		for c in sim.crew:
			if c.job and c.job.type == &"haul" and c.cargo > 0.0:
				from_depot = from_depot or c.source == 2
	_check(from_depot, "haulers prefer the supply depot")
	_check(sim.state.supplied(0), "bridge restocked from the depot")
	sim.free()


## The ship has storage for everything module i burns.
func _stocked(s: ShipState, i: int) -> bool:
	return s.module(i).upkeep.keys().all(func(r): return s.storage.capacity.has(r))


func _run(sim: CrewSim, seconds: float) -> void:
	for k in int(seconds * 30.0):
		sim._physics_process(1.0 / 30.0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + what)


## Species gaps: bio blobs never go out, crystals never carry by hand.
func _check_species() -> void:
	var bio := CrewMember.new("B", CrewSpecies.by_id(&"bio"))
	var cry := CrewMember.new("C", CrewSpecies.by_id(&"crystal"))
	_check(bio.pref(&"eva") == 0 and bio.pref(&"mine") == 0, "bio blobs stay inside")
	_check(bio.species.speed > 1.0, "bio blobs walk faster")
	_check(cry.pref(&"haul") == 0 and cry.pref(&"mine") > 0, "crystals mine but don't haul")
	_check(cry.species.pulls(), "crystals pull ore in by mind")
	_check(CrewSpecies.all().size() >= 3, "every species can be hired")
