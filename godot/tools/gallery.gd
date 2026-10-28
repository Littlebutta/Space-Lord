extends "res://scripts/crew/crew_test.gd"
## Crew sandbox on a fixed random Human ship holding every part, so art
## changes can be checked (and screenshotted) on the same layout.

const SEED := 4
const PARTS := 34


func _design() -> ShipDesign:
	var pool: Array[ShipModule] = ModuleLibrary.all().filter(
			func(m): return m.category != "command")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return ShipGenerator.generate(ModuleLibrary.by_id(&"bridge"), pool, rng,
			PARTS, &"human", 0.0)
