class_name CrewSpecies
extends Resource
## A crew species and what it can and can't do. Species are .tres files
## under res://data/species, so a new one needs no code. The gaps are
## meant to make a mixed crew worth having.

const DIR := "res://data/species/"

@export var id: StringName
@export var display_name := ""
@export var blurb := ""  # one line shown when hiring
@export var speed := 1.0  # walking speed, times CrewSim.SPEED
@export var eva := true  # may step outside the hull
@export var carry := true  # can carry loads by hand
## Telekinesis: pulls loose things this many metres to an airlock and
## floats them in and on to storage without going outside. 0 = none.
@export var reach := 0.0
## Ship themes this species crews (its bridge theme's crew model is
## theirs); the first one is the look they wear aboard anyone's ship.
@export var themes: Array[StringName] = []

static var _all: Array[CrewSpecies] = []


static func all() -> Array[CrewSpecies]:
	if _all.is_empty():
		for f in ResourceLoader.list_directory(DIR):
			var s := load(DIR + f) as CrewSpecies
			if s:
				_all.append(s)
		_all.sort_custom(func(a, b): return a.id == &"human" or b.id != &"human" and String(a.id) < String(b.id))
	return _all


## The species with `sid`, or the first one (human) if unknown.
static func by_id(sid: StringName) -> CrewSpecies:
	for s in all():
		if s.id == sid:
			return s
	return all()[0]


## Who crews ships of theme t; human if nobody claims it.
static func of_theme(t: ShipTheme) -> CrewSpecies:
	for s in all():
		if t and t.id in s.themes:
			return s
	return all()[0]


## The ship theme whose crew model they wear aboard other ships.
func look() -> ShipTheme:
	return ShipTheme.by_id(themes[0] if themes else &"")


## Whether they can take on job type t at all.
func can(t: StringName) -> bool:
	match t:
		&"haul": return carry
		&"eva": return eva
		&"salvage": return eva and carry
		&"mine": return eva and carry or reach > 0.0
	return true


## Mining by mind alone: they stay inside and pull ore in.
func pulls() -> bool:
	return reach > 0.0 and not (eva and carry)
