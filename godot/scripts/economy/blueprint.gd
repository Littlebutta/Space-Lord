class_name Blueprint
extends Resource
## Plans for one part in one faction's style, sold at that faction's
## stations. A part and theme pair with a blueprint file is locked in the
## builder until bought. Unique race parts get one .tres each under
## res://data/blueprints, so new ones need no code.

const DIR := "res://data/blueprints/"

@export var module: StringName  # ShipModule.id
@export var theme: StringName  # ShipTheme.id, the faction selling it
@export var price := 200  # credits
@export var materials := {}  # raw materials paid on top, from the hold

static var _all: Array[Blueprint] = []


static func all() -> Array[Blueprint]:
	if _all.is_empty():
		for f in ResourceLoader.list_directory(DIR):
			var b := load(DIR + f) as Blueprint
			if b:
				_all.append(b)
	return _all


## Blueprints a station of faction `tid` sells.
static func sold_by(tid: StringName) -> Array[Blueprint]:
	return all().filter(func(b): return b.theme == tid)


static func find(mid: StringName, tid: StringName) -> Blueprint:
	for b in all():
		if b.module == mid and b.theme == tid:
			return b
	return null


## Why `m` can't be built in theme `tid` right now, or "" if it can.
static func why_locked(m: ShipModule, tid: StringName) -> String:
	var b := find(m.id, tid)
	if b and not Wallet.owns(b):
		return "Needs the %s blueprint from a %s station" % [b.title(),
				ShipTheme.by_id(tid).display_name]
	return ""


func key() -> StringName:
	return StringName("%s/%s" % [theme, module])


func title() -> String:
	var m := ModuleLibrary.by_id(module)
	return "%s %s" % [ShipTheme.by_id(theme).display_name,
			m.display_name if m else String(module)]


## Pays credits and materials from the carried hold; false if short.
func buy() -> bool:
	if Wallet.owns(self) or Wallet.credits < price:
		return false
	for k in materials:
		if Wallet.cargo.get(k, 0.0) < materials[k]:
			return false
	for k in materials:
		Wallet.cargo[k] -= materials[k]
	Wallet.pay(price)
	Wallet.owned.append(key())
	return true
