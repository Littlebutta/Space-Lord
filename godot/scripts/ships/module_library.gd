class_name ModuleLibrary
extends RefCounted
## Every ShipModule .tres under res://data/modules, loaded once.

const DIR := "res://data/modules/"
const ORDER := ["command", "hull", "engine", "weapon", "storage", "crew", "utility", "exterior"]

static var _all: Array[ShipModule] = []


static func all() -> Array[ShipModule]:
	if _all.is_empty():
		for f in ResourceLoader.list_directory(DIR):
			var m := load(DIR + f) as ShipModule
			if m:
				_all.append(m)
		_all.sort_custom(func(a, b): return _key(a) < _key(b))
	return _all


static func by_id(id: StringName) -> ShipModule:
	for m in all():
		if m.id == id:
			return m
	return null


static func _key(m: ShipModule) -> String:
	return "%02d%s" % [ORDER.find(m.category), m.display_name]
