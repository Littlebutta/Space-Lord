class_name ShipDesign
extends Resource
## A ship blueprint: modules placed on a grid. Used for player ships and
## for procedurally generated encounters and wrecks.

@export var ship_name := "Unnamed"
@export var modules: Array[ShipModule] = []
@export var cells: Array[Vector2i] = []  # grid origin of each module


func fits(m: ShipModule, cell: Vector2i) -> bool:
	var r := Rect2i(cell, m.size)
	for i in modules.size():
		if Rect2i(cells[i], modules[i].size).intersects(r):
			return false
	return true


func add(m: ShipModule, cell: Vector2i) -> bool:
	if not fits(m, cell):
		return false
	modules.append(m)
	cells.append(cell)
	return true


## Sums a numeric module property, e.g. total("mass").
func total(stat: StringName) -> float:
	var sum := 0.0
	for m in modules:
		sum += float(m.get(stat))
	return sum


func build_storage() -> Storage:
	var s := Storage.new()
	for m in modules:
		s.add_capacity(m.storage)
	return s
