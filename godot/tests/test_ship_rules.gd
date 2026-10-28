extends SceneTree
## Headless checks for ship layout rules, themes and placeholder meshes.
## Run: godot --headless --path godot -s res://tests/test_ship_rules.gd

var fails := 0


func _initialize() -> void:
	var eng := ModuleLibrary.by_id(&"engine")
	var hull := ModuleLibrary.by_id(&"hull")
	var fuel := ModuleLibrary.by_id(&"fuel_tank")
	var bridge := ModuleLibrary.by_id(&"bridge")
	var d := ShipDesign.new()
	check(d.add(bridge, Vector2i.ZERO), "bridge placed")
	check(not d.add(eng, Vector2i(0, 2), 2), "thruster can't fire forward")
	check(d.add(eng, Vector2i(0, 2)), "rear thruster placed")
	check(not d.add(hull, Vector2i(0, 9)), "hull blocked in exhaust lane")
	check(d.add(hull, Vector2i(1, 2)), "hull beside thruster ok")
	check(not d.add(eng, Vector2i(1, 0), 0), "overlap refused")
	check(d.add(fuel, Vector2i(6, 0)), "far fuel tank placed")
	check(ShipRules.problems(d).size() == 1, "far-from-fuel warning")
	check(d.add(fuel, Vector2i(2, 0)), "near fuel tank placed")
	check(ShipRules.problems(d).is_empty(), "no warnings once fuel is near")
	var before := ShipStats.of(d)
	d.paint(Vector2i(1, 2), &"crystal")
	check(d.theme(2).id == &"crystal", "paint sets theme")
	var after := ShipStats.of(d)
	check(before.mass == after.mass and before.hp == after.hp, "themes are visual only")
	check(ShipTheme.all().size() >= 4, "themes loaded")
	Shipyard.docked = false
	check(not Shipyard.can_refit(d), "no refit in space without a shipdock")
	check(Shipyard.can_repair(90.0, 100.0, d), "minor repair in space")
	check(not Shipyard.can_repair(30.0, 100.0, d), "major repair needs a yard")
	d.modules.append(ModuleLibrary.by_id(&"shipdock"))
	check(Shipyard.can_refit(d), "shipdock allows refit in space")
	d.modules.pop_back()
	Shipyard.docked = true
	var w := ShipDesign.new()  # ammo rack's shelf (top half) walls off the hull below
	w.add(hull, Vector2i.ZERO)
	w.add(ModuleLibrary.by_id(&"ammo_rack"), Vector2i(0, 1))
	w.add(hull, Vector2i(0, 2))
	var walled := ShipStats.of(w).warnings.any(func(t): return t.begins_with("Crew can't reach"))
	check(walled, "warns when equipment walls crew off a part")
	for t in ShipTheme.all():
		for m in ModuleLibrary.all():
			for turn in 4:
				var r := Rect2i(Vector2i.ZERO, ShipDesign.turned(m, turn))
				var mesh := ShipView.part_mesh(m, r, turn, t)
				check(mesh.get_surface_count() >= 1, "%s %s mesh" % [t.id, m.id])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var g := ShipGenerator.generate(bridge, ModuleLibrary.all(), rng, 20, &"bio")
	check(g.themes.size() == g.modules.size(), "generator themes")
	print("ship rules: %d failure(s)" % fails)
	quit(1 if fails else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: " + what)
