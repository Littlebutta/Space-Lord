extends SceneTree
## Headless mining checks: godot --headless --path godot -s res://tests/test_mining.gd

const DT := 1.0 / 30.0

var _fails := 0


func _initialize() -> void:
	_check(Travel.advance(1.0) == -1, "no destination, no travel")
	Travel.make_sites(1)
	Travel.aim = 1
	Travel.dest = Travel.sites[1].pos
	var hours := 0
	while Travel.advance(0.5) < 0 and hours < 400:
		hours += 1
	_check(Travel.pos.distance_to(Travel.sites[1].pos) < Travel.REACH, "flies to a site")
	Travel.here = 1
	var d := SiteScene.prepare(ShipGenerator.sandbox(3))
	var ship := ShipBody.new()
	root.add_child(ship)
	ship.setup(d, maxi(int(d.total(&"berths")), int(d.total(&"crew")) + 2))
	var f := MiningField.new()
	root.add_child(f)
	f.bind(ship, Travel.site())
	var st := ship.sim.state
	var ore := st.storage.get_amount("ore")
	f.target = 0
	var laser: int = range(st.size()).filter(func(i): return st.module(i).mining > 0)[0]
	f.rocks[0].node.position = f._world(f._mount(laser)) + Vector3(0, 0, -15)  # in reach
	var cut := 0
	var over := 0
	for k in 120 * 30:
		_step(ship, f)
		cut = maxi(cut, f._next)
		over += int(_planned(ship, f) > st.storage.free_space("ore") + 0.01)
	_check(cut > 0, "the laser cuts chunks loose (%d)" % cut)
	_check(st.storage.get_amount("ore") > ore, "crew stow ore in the hold")
	_check(over == 0, "planned runs never exceed free space")
	var cap: float = st.storage.capacity["ore"]
	st.storage.amount["ore"] = cap - 7.0  # room for one chunk, not two
	var most := 0
	for k in 40 * 30:
		_step(ship, f)
		most = maxi(most, _runs(ship))
		over += int(_planned(ship, f) > st.storage.free_space("ore") + 0.01)
	_check(most == 1, "only one ore run when one chunk fits (%d)" % most)
	_check(over == 0 and st.storage.get_amount("ore") <= cap, "never overfills")
	st.storage.amount["ore"] = cap
	for k in 30:
		_step(ship, f)
	_check(_runs(ship) == 0, "a full hold stops everyone")
	_check(ship.sim.crew.all(func(c): return c.cargo <= 0.0), "carriers let go")
	print("mining tests: %s" % ("FAILED %d" % _fails if _fails else "ok"))
	quit(1 if _fails else 0)


func _step(ship: ShipBody, f: MiningField) -> void:
	ship._physics_process(DT)
	ship.sim._physics_process(DT)
	f._physics_process(DT)


func _runs(ship: ShipBody) -> int:
	return ship.sim.crew.filter(func(c): return c.job and c.job.type == &"mine").size()


## Ore that crew on ore runs have claimed, carried or not.
func _planned(ship: ShipBody, f: MiningField) -> float:
	var n := 0.0
	for c in ship.sim.crew:
		if c.job and c.job.type == &"mine" and c.stage < 5:
			n += f.amount(c.job.target)
	return n


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + what)
