extends SceneTree
## Headless checks for tiered parts, teleporters, breaching pods, cargo
## holds and builder aids: godot --headless --path godot -s res://tests/test_modules.gd

const DT := 1.0 / 30.0

var _fails := 0


func _initialize() -> void:
	_check_parts()
	_check_teleport()
	_check_builder()
	_check_hold()
	_check_breach()
	print("module tests: %s" % ("FAILED %d" % _fails if _fails else "ok"))
	quit(1 if _fails else 0)


## Tiers are bigger, need more crew and hit harder; every part's work
## spots are on open deck and cosmetic bits stay out of the builder.
func _check_parts() -> void:
	for id in ["engine", "fuel_tank", "cargo_hold", "cannon", "turret"]:
		var a := ModuleLibrary.by_id(StringName(id))
		for t in [2, 3]:
			var b := ModuleLibrary.by_id(StringName("%s_t%d" % [id, t]))
			_check(b != null and b.size.x * b.size.y > a.size.x * a.size.y,
					"%s tier %d is bigger" % [id, t])
			if b and a.crew > 0:
				_check(b.crew > a.crew, "%s tier %d needs more crew" % [id, t])
			if b and a.firepower > 0.0:
				_check(b.firepower > a.firepower * 2.0, "%s tier %d hits harder" % [id, t])
			a = b if b else a
	var ids := ModuleLibrary.buildable().map(func(m): return m.id)
	_check(not ids.has(&"antenna") and not ids.has(&"sensor_mast"), "no antennas in the builder")
	_check(ids.has(&"teleporter") and ids.has(&"breach_pod"), "new parts in the builder")
	_check(ids.filter(func(i): return String(i).begins_with("armor")).size() >= 7, "more armor")
	for m in ModuleLibrary.all():
		if m.exterior:
			continue
		var d := ShipDesign.new()
		d.add(m, Vector2i.ZERO)
		var nav := ShipNav.new(d)
		for k in maxi(m.access.size(), 1):
			_check(nav.walkable(d.spot(0, k)), "%s work spot %d is on open deck" % [m.id, k])


## Crew blink between teleporters, even onto a piece that broke off.
func _check_teleport() -> void:
	var d := ShipDesign.new()
	d.add(ModuleLibrary.by_id(&"bridge"), Vector2i.ZERO)
	d.add(ModuleLibrary.by_id(&"teleporter"), Vector2i(0, 2))
	d.add(ModuleLibrary.by_id(&"teleporter"), Vector2i(8, 0))  # loose: it drifts off
	d.add(ModuleLibrary.by_id(&"hull"), Vector2i(8, 2))
	var nav := ShipNav.new(d)
	var far := d.spot(3)
	_check(nav.connected(d.spot(0), far), "teleporters link cut-off decks")
	var path := nav.route(d.spot(0), far)
	var hops := range(1, path.size()).filter(func(k): return path[k] == path[k - 1])
	_check(hops.size() == 1, "the route takes one teleporter hop")
	_check(ShipNav.walled_off(d).is_empty(), "nothing walled off with teleporters")
	var sim := CrewSim.new()
	root.add_child(sim)
	sim.setup(d, 1)
	var c := sim.crew[0]
	CrewOrders.order(sim, c, far)
	var blinked := [false]
	sim.teleported.connect(func(_a, _b): blinked[0] = true)
	for k in 30 * 20:
		sim._physics_process(DT)
	_check(blinked[0] and c.pos.distance_to(far) < 0.5, "crew teleport across")
	_check(c.strand < 0.0 and not c.eva, "nobody stranded with a teleporter aboard")
	sim.free()


## Undo steps back one action; the crew view finds supply routes.
func _check_builder() -> void:
	var d := ShipDesign.new()
	var u := EditorUndo.new(d)
	u.mark()
	d.add(ModuleLibrary.by_id(&"bridge"), Vector2i.ZERO)
	u.mark()
	d.add(ModuleLibrary.by_id(&"hull"), Vector2i(0, 2))
	d.add(ModuleLibrary.by_id(&"hull"), Vector2i(1, 2))  # same action
	_check(u.undo() and d.modules.size() == 1, "undo takes back the last action")
	_check(u.undo() and d.modules.is_empty() and not u.undo(), "and the one before")
	d.add(ModuleLibrary.by_id(&"bridge"), Vector2i.ZERO)
	d.add(ModuleLibrary.by_id(&"engine"), Vector2i(0, 2))
	d.add(ModuleLibrary.by_id(&"fuel_tank"), Vector2i(1, 2))
	var r := CrewView.routes(d, ShipNav.new(d), 1)
	_check(r.size() == 2, "thruster shows its fuel run and its operator (%d)" % r.size())
	var v := CrewView.new()
	v.show_floor(d)
	v.show_routes(d, 1)
	_check(v.get_child(0).mesh != null and v.get_child(1).mesh != null, "crew view draws")
	v.free()


## No cargo hold: crew can't bring loose ore or salvage aboard.
func _check_hold() -> void:
	var d := ShipDesign.new()
	d.add(ModuleLibrary.by_id(&"bridge"), Vector2i.ZERO)
	d.add(ModuleLibrary.by_id(&"airlock"), Vector2i(0, 2))
	var sim := CrewSim.new()
	sim.setup(d, 1)
	_check(not sim.state.has_hold(), "no hold aboard")
	_check(not CrewOutside.order(sim, sim.crew[0], {kind = &"mine", id = 0}),
			"no ore runs without a hold")
	sim.free()


## A pod boards a dead ship, strips it, and comes home when recalled.
func _check_breach() -> void:
	var me := _ship([[&"bridge", 0, 0], [&"breach_pod", 2, 0], [&"airlock", 0, 2]], Vector2.ZERO)
	var foe := _ship([[&"bridge", 0, 0], [&"cargo_hold", 2, 0], [&"hull", 0, 2]],
			Vector2(0, -30))
	foe.sim.state.damage(0, INF)
	_check(BreachPod.offline(foe), "a ship without its bridge is offline")
	var bay := 1
	var c := me.sim.crew[0]
	_check(CrewBreach.order(me.sim, c, foe, 1), "crew ordered to board")
	var pod := BreachPod.of(me, bay)
	var parts := me.sim.state.storage.get_amount("parts")
	var latched := false
	for k in 30 * 30:
		_step([me, foe], pod)
		latched = latched or pod.mode == &"latched"
	_check(latched, "the pod latches on (%s)" % pod.mode)
	_check(pod.loot > 0.0, "boarders strip the wreck (%.0f)" % pod.loot)
	pod.recall()
	for k in 30 * 30:
		_step([me, foe], pod)
	_check(pod.mode == &"docked" and not c.hidden and not c.eva, "pod docks with its crew")
	_check(me.sim.state.storage.get_amount("parts") > parts, "the parts come home")


func _ship(parts: Array, at: Vector2) -> ShipBody:
	var d := ShipDesign.new()
	for p in parts:
		d.add(ModuleLibrary.by_id(p[0]), Vector2i(p[1], p[2]))
	var b := ShipBody.new()
	root.add_child(b)
	b.setup(d, 2)
	b.at = Transform2D(0.0, at)
	return b


func _step(ships: Array, pod: BreachPod) -> void:
	for s: ShipBody in ships:
		s._physics_process(DT)
		s.sim._physics_process(DT)
	pod._physics_process(DT)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + what)
