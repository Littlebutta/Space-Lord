extends "res://scripts/crew/crew_test.gd"
## Crew sandbox on a fixed sample ship using every module, so art
## changes can be checked (and screenshotted) on the same layout.

const LAYOUT := [  # module id, cell, turn
	["bridge", Vector2i(0, 0), 0], ["turret", Vector2i(0, -2), 0],
	["cannon", Vector2i(-1, -3), 0], ["cannon", Vector2i(2, -3), 0],
	["hull_slope", Vector2i(0, -3), 1], ["hull_slope", Vector2i(1, -3), 2],
	["crew_quarters", Vector2i(-2, 0), 0], ["cargo_hold", Vector2i(2, 0), 0],
	["hull_curve", Vector2i(-4, 0), 0], ["hull_wedge", Vector2i(4, 0), 0],
	["ammo_rack", Vector2i(-1, 2), 0], ["ammo_rack", Vector2i(2, 2), 0],
	["fuel_tank", Vector2i(0, 2), 0], ["fuel_tank", Vector2i(1, 2), 0],
	["hull", Vector2i(-1, 3), 0], ["hull", Vector2i(2, 3), 0],
	["armor", Vector2i(-2, 2), 0], ["armor_slope", Vector2i(-2, 3), 0],
	["armor", Vector2i(3, 2), 0], ["armor_slope", Vector2i(3, 3), 3],
	["engine", Vector2i(0, 4), 0], ["engine", Vector2i(1, 4), 0],
]


func _design() -> ShipDesign:
	var d := ShipDesign.new()
	for e in LAYOUT:
		if not d.add(ModuleLibrary.by_id(e[0]), e[1], e[2]):
			print("gallery skip ", e, ": ", ShipRules.why_not(d,
					ModuleLibrary.by_id(e[0]), e[1], e[2]))
	return d
