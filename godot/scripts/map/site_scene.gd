class_name SiteScene
extends RefCounted
## Fills the local 3D scene for the map site the player arrived at
## (Travel.here): an asteroid field to mine, or a derelict wreck.


## The ship to fly here. At asteroids a test Mining Laser, cargo hold
## and airlock get bolted on if missing (on a copy, never the save),
## each where crew can walk to it from the bridge.
static func prepare(d: ShipDesign) -> ShipDesign:
	if Travel.site().get(&"kind") != &"asteroids":
		return d
	var rng := RandomNumberGenerator.new()
	rng.seed = Travel.site().seed
	for id in [&"airlock", &"cargo_hold", &"mining_laser"]:
		var m := ModuleLibrary.by_id(id)
		if d.modules.has(m):
			continue
		for tries in 40:
			var c := _copy(d)
			ShipGenerator.ensure(c, m, rng)
			var nav := ShipNav.new(c)
			if c.modules.has(m) and nav.connected(c.spot(0), c.spot(c.modules.size() - 1)):
				d = c
				break
	return d


static func _copy(d: ShipDesign) -> ShipDesign:
	var c := ShipDesign.new()
	c.ship_name = d.ship_name
	c.modules = d.modules.duplicate()
	c.cells = d.cells.duplicate()
	c.turns = d.turns.duplicate()
	c.themes = d.themes.duplicate()
	return c


## Adds the site's contents next to `ship`; returns a line for the HUD.
static func spawn(scene: Node3D, ship: ShipBody) -> String:
	var s := Travel.site()
	match s.get(&"kind"):
		&"asteroids":
			var f := MiningField.new()
			scene.add_child(f)
			f.bind(ship, s)
			return "Asteroid field · left click a rock to see what it holds and target it"
		&"wreck":
			_wreck(scene, s.seed)
			return "Derelict wreck · select crew, right click it to salvage"
	return ""


static func _wreck(scene: Node3D, seed_: int) -> void:
	var b := ShipBody.new()
	b.add_to_group(&"wrecks")  # crew can board and strip it (CrewSalvage)
	scene.add_child(b)
	b.setup(ShipGenerator.sandbox(seed_), 0)
	b.at = Transform2D(2.4, Vector2(10.0, -45.0))
	var st := b.sim.state
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	for k in 4:
		var i := rng.randi() % st.size()
		if st.module(i).category != "command":
			st.damage(i, INF)
