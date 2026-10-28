class_name Wallet
extends RefCounted
## The player's money and what they carry between scenes: credits, the
## ore and food in the hold, which crew are aboard and which part
## blueprints they own. Static like Travel, so it lasts the whole run.

const PRICES := {"iron": 2, "copper": 4, "silicon": 5, "gold": 20, "food": 2}
const SELL_SHARE := 0.8  # stations buy ore at this share of PRICES
const SAVE := "user://ships/player.tres"

static var credits := 1000
static var cargo := {}  # resource -> units carried between scenes
static var crew: Array = []  # species id per crew member aboard
static var crewed := false  # false: a new ship's own species fills every berth
static var owned: Array[StringName] = []  # Blueprint.key() values
static var _base := {}  # ore the local scene started with


static func pay(cost: int) -> bool:
	if cost > credits:
		return false
	credits -= cost
	return true


## Sells every unit of `res` carried; returns credits earned.
static func sell(res: String) -> int:
	var got := int(cargo.get(res, 0.0) * PRICES[res] * SELL_SHARE)
	cargo.erase(res)
	credits += got
	return got


static func owns(bp: Blueprint) -> bool:
	return owned.has(bp.key())


## Species of each crew member to start a scene with: the saved
## roster, else every berth filled by the ship's own species.
static func crew_for(d: ShipDesign) -> Array:
	if crewed:
		return crew.slice(0, maxi(int(d.total(&"berths")), 1))
	var full := maxi(int(d.total(&"berths")), int(d.total(&"crew")) + 2)
	var own := CrewSpecies.of_theme(d.theme(0)).id if d.modules else &"human"
	var out := []
	for k in full:
		out.append(own)
	return out


## The player's saved ship, or null.
static func ship() -> ShipDesign:
	return load(SAVE) as ShipDesign if ResourceLoader.exists(SAVE) else null


## Loads carried cargo into a scene's ship storage. The ore baseline is
## taken first, so carried ore goes back into the hold on unload.
static func board(s: Storage) -> void:
	for k in Materials.ALL:
		_base[k] = s.get_amount(k)
	var left := {}
	for k in cargo:
		var n: float = cargo[k] - s.put(k, cargo[k])
		if n > 0.0 and k not in Materials.ALL:
			left[k] = n  # ore that doesn't fit is lost, food waits
	cargo = left


## Leaving a scene: ore gained there goes into the carried hold.
static func unload(s: Storage, aboard: Array) -> void:
	for k in Materials.ALL:
		var n: float = s.get_amount(k) - _base.get(k, 0.0)
		if n > 0.0:
			cargo[k] = cargo.get(k, 0.0) + n
	_base.clear()
	crew = aboard
	crewed = true


## Hires one of species `sp` for ship `d` if a berth and credits allow.
static func hire(d: ShipDesign, sp: CrewSpecies) -> bool:
	var have := crew_for(d)
	if have.size() >= int(d.total(&"berths")) or not pay(sp.hire_cost):
		return false
	crew = have + [sp.id]
	crewed = true
	return true


## Buys up to `qty` food, as much as the ship's food storage can take.
static func buy_food(d: ShipDesign, qty: float) -> bool:
	var room: float = d.build_storage().capacity.get("food", 0.0) - cargo.get("food", 0.0)
	var n := minf(qty, room)
	if n < 1.0 or not pay(int(ceil(n * PRICES.food))):
		return false
	cargo["food"] = cargo.get("food", 0.0) + n
	return true
