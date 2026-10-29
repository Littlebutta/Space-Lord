extends SceneTree
## Headless checks for stations, credits and blueprints:
## godot --headless --path godot -s res://tests/test_station.gd

var _fails := 0


func _init() -> void:
	Travel.make_sites(1337)
	var st: Array = Travel.sites.filter(func(s): return s.kind == &"station")
	_check(st.size() == 1, "one station per system")
	Travel.pos = st[0].pos + Vector3(10, 0, 0)
	_check(not Travel.near_station().is_empty(), "in refit range near the station")
	var bp := Blueprint.find(&"cannon", &"bio")
	var cannon := ModuleLibrary.by_id(&"cannon")
	_check(bp != null and Blueprint.why_locked(cannon, &"bio") != "", "bio cannon locked")
	_check(Blueprint.why_locked(cannon, &"human") == "", "human cannon free")
	Wallet.credits = 1000
	_check(not bp.buy(), "blueprint needs its copper")
	Wallet.cargo = {"copper": 12.0, "iron": 50.0}
	_check(bp.buy() and Wallet.owns(bp), "bought the bio cannon blueprint")
	_check(Wallet.credits == 600 and Wallet.cargo.copper == 2.0, "paid credits and copper")
	_check(Wallet.sell("iron") == 80 and Wallet.credits == 680, "sold iron")
	var s := Storage.new()
	s.add_capacity({"iron": 100.0, "food": 10.0})
	s.put("iron", 20.0)
	Wallet.cargo = {"iron": 5.0, "food": 15.0}
	Wallet.board(s)
	_check(s.get_amount("iron") == 25.0 and Wallet.cargo.food == 5.0, "boarded cargo")
	s.put("iron", 30.0)
	Wallet.unload(s, [&"human", &"bio"])
	_check(Wallet.cargo.iron == 35.0 and Wallet.crew.size() == 2, "carried ore and mined ore unloaded")
	var d := ShipDesign.new()
	d.add(ModuleLibrary.by_id(&"bridge"), Vector2i.ZERO)
	d.add(ModuleLibrary.by_id(&"crew_quarters"), Vector2i(0, 2))
	Wallet.crew = [&"human"]
	var sp := CrewSpecies.by_id(&"crystal")
	var cr := Wallet.credits
	_check(Wallet.hire(d, sp) and Wallet.crew_for(d).back() == &"crystal", "hired a crystal")
	_check(Wallet.credits == cr - sp.hire_cost, "paid the species hire cost")
	Fleet.fuel = 3.0
	Travel.dest = Travel.pos + Vector3(100, 0, 0)
	Fleet.travel(50.0)
	_check(Travel.dest == null and Fleet.fuel == 0.0 and Fleet.stranded(), "ran dry and stopped")
	Fleet.call_sos(0.0)
	_check(Fleet.sos.kind in Fleet.SOS_KINDS and Fleet.sos_progress(99.0) == 1.0, "SOS answered")
	var jumps: Array = Travel.sites.filter(func(s): return s.kind == &"jump")
	Travel.jump(jumps[0].to)
	_check(Travel.system == jumps[0].to and Travel.sites.size() == 8, "jumped to the next system")
	print("station tests: %s" % ("FAILED %d" % _fails if _fails else "ok"))
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
