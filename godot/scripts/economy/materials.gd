class_name Materials
extends RefCounted
## The four raw materials mined from asteroids. Modules list what they
## are built from (ShipModule.materials); repairs use a share of that,
## and RECIPES say what ammo and parts take once a refinery makes them.

const ALL: Array[String] = ["iron", "copper", "silicon", "gold"]
const COLORS := {
	"iron": Color(0.62, 0.6, 0.58),
	"copper": Color(0.9, 0.5, 0.25),
	"silicon": Color(0.45, 0.55, 0.85),
	"gold": Color(1.0, 0.82, 0.3),
}
## Raw materials per unit made.
const RECIPES := {
	"ammo": {"iron": 0.4, "copper": 0.2},
	"parts": {"iron": 1.0, "copper": 0.3, "silicon": 0.3},
}
const REPAIR_SHARE := 0.3  # of the build cost, to repair from wrecked-low to full


## Materials to repair `hp` worth of module m.
static func repair_cost(m: ShipModule, hp: float) -> Dictionary:
	var out := {}
	var f := REPAIR_SHARE * hp / maxf(m.hp, 1.0)
	for k in m.materials:
		out[k] = m.materials[k] * f
	return out


## A rock's make-up: share of each material, iron commonest, gold rare.
static func mix(rng: RandomNumberGenerator) -> Dictionary:
	var w := {"iron": rng.randf_range(0.3, 1.0), "copper": rng.randf_range(0.1, 0.6),
			"silicon": rng.randf_range(0.1, 0.6), "gold": rng.randf_range(0.0, 0.15)}
	var sum := 0.0
	for k in w:
		sum += w[k]
	for k in w:
		w[k] /= sum
	return w


static func line(d: Dictionary) -> String:
	var parts: Array[String] = []
	for k in ALL:
		if d.get(k, 0.0) >= 0.5:
			parts.append("%s %.0f" % [k.capitalize(), d[k]])
	return ", ".join(parts)
