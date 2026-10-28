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
	Wallet.unload(s, 3)
	_check(Wallet.cargo.iron == 35.0 and Wallet.crew == 3, "carried ore and mined ore unloaded")
	print("station tests: %s" % ("FAILED %d" % _fails if _fails else "ok"))
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
