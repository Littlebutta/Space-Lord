class_name ShipStats
extends RefCounted
## Totals and design problems for a ShipDesign, shown in the builder
## and used later to fly and fight the ship.

var mass := 0.0
var hp := 0.0
var crew := 0  # needed
var berths := 0  # housed
var thrust := 0.0
var firepower := 0.0
var storage := {}  # resource -> capacity
var upkeep := {}  # resource -> units per game hour
var warnings: Array[String] = []


static func of(d: ShipDesign) -> ShipStats:
	var s := ShipStats.new()
	s.mass = d.total(&"mass")
	s.hp = d.total(&"hp")
	s.crew = int(d.total(&"crew"))
	s.berths = int(d.total(&"berths"))
	s.thrust = d.total(&"thrust")
	s.firepower = d.total(&"firepower")
	s.storage = d.total_dict(&"storage")
	s.upkeep = d.total_dict(&"upkeep")
	s._check(d)
	return s


func accel() -> float:
	return thrust / mass if mass > 0.0 else 0.0


## Game hours a full ship lasts on `res` at full upkeep (INF if unused).
func endurance(res: String) -> float:
	var use: float = upkeep.get(res, 0.0)
	return storage.get(res, 0.0) / use if use > 0.0 else INF


func _check(d: ShipDesign) -> void:
	if d.modules.is_empty():
		warnings.append("Empty ship")
		return
	if not d.modules.any(func(m): return m.category == "command"):
		warnings.append("No bridge: the ship can't be commanded")
	if crew > berths:
		warnings.append("Crew needs %d berths, has %d" % [crew, berths])
	if thrust <= 0.0:
		warnings.append("No engines: the ship can't move")
	for res in upkeep:
		if storage.get(res, 0.0) <= 0.0:
			warnings.append("Uses %s but has no storage for it" % res)
	warnings.append_array(ShipRules.problems(d))
	var loose := d.loose_modules()
	if loose.size() > 0:
		warnings.append("%d module(s) not attached to the hull" % loose.size())
	for i in ShipNav.walled_off(d):
		if not loose.has(i):
			warnings.append("Crew can't reach the %s: equipment walls it off"
					% d.modules[i].display_name)
