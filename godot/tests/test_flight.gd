extends SceneTree
## Headless checks for flying, loose pieces bumping, and crew stranded
## on cut-off pieces: godot --headless --path godot -s res://tests/test_flight.gd

var _fails := 0


func _init() -> void:
	_strand()
	_suffocate()
	_bump()
	_fly()
	_orders()
	print("flight tests: %s" % ("FAILED %d" % _fails if _fails else "ok"))
	quit(1 if _fails else 0)


## Bridge, airlock below it, and a hull arm 2..4 to the right.
func _ship() -> CrewSim:
	var d := ShipDesign.new()
	d.add(ModuleLibrary.by_id(&"bridge"), Vector2i.ZERO)
	d.add(ModuleLibrary.by_id(&"airlock"), Vector2i(0, 2))
	for x in [2, 3, 4]:
		d.add(ModuleLibrary.by_id(&"hull"), Vector2i(x, 0))
	var sim := CrewSim.new()
	sim.setup(d, 3)
	return sim


func _strand() -> void:
	var sim := _ship()
	var c: CrewMember = sim.crew[0]
	c.pos = sim.state.pieces.home(4)
	sim.state.damage(2, INF)
	_run(sim, 1.0)
	_check(not c.eva and c.strand >= 0.0, "stranded crew stay inside the piece")
	var bailed := false
	var back := false
	for k in 900:
		sim._physics_process(1.0 / 30.0)
		bailed = bailed or c.eva
		back = back or bailed and not c.eva
	_check(bailed, "and later suit up and leave it")
	_check(sim.crew.has(c) and back, "and make it back in")
	sim.free()


func _suffocate() -> void:
	var sim := _ship()
	var c: CrewMember = sim.crew[0]
	c.pos = sim.state.pieces.home(4)
	sim.state.damage(1, INF)  # no airlock to get back in by
	sim.state.damage(2, INF)
	_run(sim, 20.0 + CrewEva.AIR_SUIT)
	_check(not sim.crew.has(c) and sim.lost == 1, "out of air: they die")
	sim.free()


func _bump() -> void:
	var sim := _ship()
	var p := sim.state.pieces
	var bumps := PieceBumps.new(p)
	sim.state.damage(3, INF)  # module 4 breaks off
	for i in 30 * 6:
		bumps.carry(Transform2D(0.0, Vector2(-0.1, 0.0)), sim.crew)  # ship flies at +x
		bumps.collide(Vector2(3.0, 0.0))
		p.tick(1.0 / 30.0)
	_check(p.world(4).x > p.home(2).x + 1.5, "loose piece never ends up inside the ship")
	_check(p.vel[4].x > 2.0, "the ship shoves it along")
	sim.free()


func _fly() -> void:
	var d := ShipDesign.new()
	d.add(ModuleLibrary.by_id(&"bridge"), Vector2i.ZERO)
	d.add(ModuleLibrary.by_id(&"fuel_tank"), Vector2i(2, 0))
	for x in [0, 1]:
		d.add(ModuleLibrary.by_id(&"engine"), Vector2i(x, 2))
	var b := ShipBody.new()
	b.setup(d, 4)
	for k in 30 * 20:
		b._physics_process(1.0 / 30.0)
		b.sim._physics_process(1.0 / 30.0)
	_check(b.power() > 0.0, "crewed, fuelled engines give thrust")
	b.goal = b.world(b.pivot()) + Vector2(30.0, -30.0)
	var start: float = b.world(b.pivot()).distance_to(b.goal)
	for k in 30 * 20:
		b._physics_process(1.0 / 30.0)
		b.sim._physics_process(1.0 / 30.0)
	var left := start if b.goal == null else b.world(b.pivot()).distance_to(b.goal)
	_check(b.goal == null or left < start * 0.5, "flies toward the goal (%.1f of %.1f m left)" % [left, start])
	b.free()


func _orders() -> void:
	var sim := _ship()
	var c: CrewMember = sim.crew[0]
	var to := sim.state.spot(1)
	CrewOrders.order(sim, c, to)
	_run(sim, 6.0)
	_check(c.order and c.pos.distance_to(to) < 0.8, "ordered crew walk there and hold")
	for o in sim.crew:
		if o != c:
			o.priority[&"operate"] = 0
			sim.drop(o)
	CrewOrders.order(sim, c, sim.state.spot(0, 1))
	_run(sim, 4.0)
	_check(c.job and c.job.type == &"operate" and c.job.module == 0, "ordered onto a station: they man it")
	CrewOrders.release(sim, c)
	_check(not c.order and c.job == null, "released back to duties")
	sim.free()


func _run(sim: CrewSim, seconds: float) -> void:
	for k in int(seconds * 30.0):
		sim._physics_process(1.0 / 30.0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + what)
