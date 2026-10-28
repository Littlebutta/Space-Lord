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
	var ore := _held(st)
	f.target = 0
	var laser: int = range(st.size()).filter(func(i): return st.module(i).mining > 0)[0]
	f.rocks[0].node.position = f._world(f._mount(laser)) + Vector3(0, 0, -60)  # in reach
	var cut := 0
	var over := 0
	for k in 120 * 30:
		_step(ship, f)
		cut = maxi(cut, f._next)
		over += _over(ship, f)
	_check(cut > 0, "the laser cuts chunks loose (%d)" % cut)
	_check(_held(st) > ore, "crew stow ore in the hold")
	_check(over == 0, "planned runs never exceed free space")
	for m in Materials.ALL:  # full first, so runs from before stop
		st.storage.amount[m] = st.storage.capacity[m]
	for k in 30:
		_step(ship, f)
	for m in Materials.ALL:  # room for one chunk of each, not two
		st.storage.amount[m] = st.storage.capacity[m] - 7.0
	var most := 0
	for k in 40 * 30:
		_step(ship, f)
		most = maxi(most, _runs(ship))
		over += _over(ship, f)
	_check(most <= 4, "one run per material when one chunk fits (%d)" % most)
	_check(over == 0, "never overfills")
	for m in Materials.ALL:
		st.storage.amount[m] = st.storage.capacity[m]
	for k in 30:
		_step(ship, f)
	_check(_runs(ship) == 0, "a full hold stops everyone")
	_check(ship.sim.crew.all(func(c): return c.cargo <= 0.0 or c.job and c.job.type == &"haul"),
			"carriers let go")  # haulers restocking modules may still hold supplies
	_check_crystals(ship, f)
	var me := ship.world(ship.pivot())
	f.rocks[1].node.position = Vector3(me.x, 0, me.y - 30.0)
	var before := st.hp.duplicate()
	ship.vel = Vector2(0, -8.0)  # ram it
	for k in 4 * 30:
		_step(ship, f)
	var hurt := range(st.size()).any(func(i): return st.hp[i] < before[i])
	_check(hurt, "ramming a rock damages the ship")
	_check(ship.world(ship.pivot()).distance_to(me) < 30.0, "and the rock stops it")
	print("mining tests: %s" % ("FAILED %d" % _fails if _fails else "ok"))
	quit(1 if _fails else 0)


## An all-crystal crew pulls ore in by mind and never steps outside.
func _check_crystals(ship: ShipBody, f: MiningField) -> void:
	var sim := ship.sim
	for c in sim.crew:
		sim.drop(c)
		c.species = CrewSpecies.by_id(&"crystal")
		c.eva = false
		c.alt = 0.0
		c.pos = sim._home()
	for m in Materials.ALL:
		sim.state.storage.amount[m] = 0.0
	var out := false
	for k in 60 * 30:
		_step(ship, f)
		out = out or sim.crew.any(func(c): return c.eva)
	_check(_held(sim.state) > 0.0, "crystals pull ore into the hold")
	_check(not out, "crystals never step outside to mine")


func _step(ship: ShipBody, f: MiningField) -> void:
	ship._physics_process(DT)
	ship.sim._physics_process(DT)
	f._physics_process(DT)


func _runs(ship: ShipBody) -> int:
	return ship.sim.crew.filter(func(c): return c.job and c.job.type == &"mine").size()


func _held(st: ShipState) -> float:
	return Materials.ALL.reduce(func(a, m): return a + st.storage.get_amount(m), 0.0)


## 1 if the ore claimed on runs (carried or not) overfills any material.
func _over(ship: ShipBody, f: MiningField) -> int:
	var n := {}
	for c in ship.sim.crew:
		if c.job and c.job.type == &"mine" and c.stage < 5:
			n[c.job.res] = n.get(c.job.res, 0.0) + f.amount(c.job.target)
	for m in n:
		if n[m] > ship.sim.state.storage.free_space(m) + 0.01:
			return 1
	return 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + what)
