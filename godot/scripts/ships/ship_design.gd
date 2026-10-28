class_name ShipDesign
extends Resource
## A ship blueprint: modules placed on a grid. Used for player ships and
## for procedurally generated encounters and wrecks.

@export var ship_name := "Unnamed"
@export var modules: Array[ShipModule] = []
@export var cells: Array[Vector2i] = []  # grid origin of each module
@export var turns: Array[int] = []  # quarter turns of each module


static func turned(m: ShipModule, turn: int) -> Vector2i:
	return Vector2i(m.size.y, m.size.x) if turn % 2 else m.size


func rect(i: int) -> Rect2i:
	return Rect2i(cells[i], turned(modules[i], turns[i]))


func fits(m: ShipModule, cell: Vector2i, turn := 0) -> bool:
	var r := Rect2i(cell, turned(m, turn))
	for i in modules.size():
		if rect(i).intersects(r):
			return false
	return true


func add(m: ShipModule, cell: Vector2i, turn := 0) -> bool:
	if not fits(m, cell, turn):
		return false
	modules.append(m)
	cells.append(cell)
	turns.append(turn % 4)
	emit_changed()
	return true


## Index of the module covering `cell`, or -1.
func index_at(cell: Vector2i) -> int:
	for i in modules.size():
		if rect(i).has_point(cell):
			return i
	return -1


func remove_at(cell: Vector2i) -> ShipModule:
	var i := index_at(cell)
	if i < 0:
		return null
	var m := modules[i]
	modules.remove_at(i)
	cells.remove_at(i)
	turns.remove_at(i)
	emit_changed()
	return m


func clear() -> void:
	modules.clear()
	cells.clear()
	turns.clear()
	emit_changed()


## Sums a numeric module property, e.g. total("mass").
func total(stat: StringName) -> float:
	var sum := 0.0
	for m in modules:
		sum += float(m.get(stat))
	return sum


## Sums a per-resource dictionary property ("storage", "upkeep"...).
func total_dict(prop: StringName) -> Dictionary:
	var sum := {}
	for m in modules:
		var d: Dictionary = m.get(prop)
		for k in d:
			sum[k] = sum.get(k, 0.0) + d[k]
	return sum


func build_storage() -> Storage:
	var s := Storage.new()
	s.add_capacity(total_dict(&"storage"))
	return s


## Modules not joined to the first one through touching sides.
func loose_modules() -> Array[int]:
	var seen := {}
	var todo: Array[int] = []
	if modules.size() > 0:
		todo.append(0)
	while not todo.is_empty():
		var a: int = todo.pop_back()
		seen[a] = true
		for b in modules.size():
			if not seen.has(b) and not todo.has(b) and _touch(rect(a), rect(b)):
				todo.append(b)
	var out: Array[int] = []
	for i in modules.size():
		if not seen.has(i):
			out.append(i)
	return out


## Shares an edge (corner-only contact doesn't count).
static func _touch(a: Rect2i, b: Rect2i) -> bool:
	return a.grow_individual(1, 0, 1, 0).intersects(b) \
			or a.grow_individual(0, 1, 0, 1).intersects(b)
