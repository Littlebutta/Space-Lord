class_name Shipyard
extends RefCounted
## Where a ship can be worked on. Additions, removals and major repairs
## need a shipyard (docked at a station) or a Shipdock module aboard.
## Minor repairs are crew work and can happen anywhere.

const MAJOR := 0.5  # below this share of hp a repair counts as major

static var docked := true  # set by the map once stations exist


static func has_dock(d: ShipDesign) -> bool:
	return d.modules.any(func(m): return m.shipdock)


## Can add, remove or restyle parts right now.
static func can_refit(d: ShipDesign) -> bool:
	return docked or has_dock(d)


static func can_repair(hp: float, max_hp: float, d: ShipDesign) -> bool:
	return hp >= max_hp * MAJOR or can_refit(d)


## One line for the builder: where we are and what's allowed.
static func status(d: ShipDesign) -> String:
	if docked:
		return "At shipyard: full refit"
	if has_dock(d):
		return "In space: Shipdock aboard, full refit"
	return "In space: minor repairs only. Additions need a shipyard or a Shipdock."
