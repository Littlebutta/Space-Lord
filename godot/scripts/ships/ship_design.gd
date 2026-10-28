class_name ShipDesign
extends Resource
## A ship blueprint: modules placed on a grid. Used for player ships and
## for procedurally generated encounters and wrecks.

@export var ship_name := "Unnamed"
@export var modules: Array[ShipModule] = []
@export var cells: Array[Vector2i] = []  # grid origin of each module
@export var turns: Array[int] = []  # quarter turns of each module, +4 if mirrored
@export var themes: Array[StringName] = []  # ShipTheme id of each module


static func turned(m: ShipModule, turn: int) -> Vector2i:
	return Vector2i(m.size.y, m.size.x) if turn % 2 else m.size


## The same placement flipped left-right (the ship's own mirror image
## is mirror(turn) at the reflected cell: see mirror_cell).
static func mirror(turn: int) -> int:
	return (4 - turn % 4) % 4 + (0 if turn >= 4 else 4)


## Origin of the copy of a `size` part at `cell` reflected across x = 0.
static func mirror_cell(cell: Vector2i, size: Vector2i) -> Vector2i:
	return Vector2i(-cell.x - size.x, cell.y)


func rect(i: int) -> Rect2i:
	return Rect2i(cells[i], turned(modules[i], turns[i]))


func theme(i: int) -> ShipTheme:
	return ShipTheme.by_id(themes[i] if i < themes.size() else &"")


## Overlap and layout rules; ShipRules.why_not says what's wrong.
func fits(m: ShipModule, cell: Vector2i, turn := 0) -> bool:
	return ShipRules.why_not(self, m, cell, turn) == ""


func add(m: ShipModule, cell: Vector2i, turn := 0, tid := &"human") -> bool:
	if not fits(m, cell, turn):
		return false
	themes.resize(modules.size())  # older saves had no themes
	modules.append(m)
	cells.append(cell)
	turns.append(turn % 8)
	themes.append(tid)
	emit_changed()
	return true


## Re-themes the module covering `cell`.
func paint(cell: Vector2i, tid: StringName) -> void:
	var i := index_at(cell)
	if i >= 0:
		themes.resize(modules.size())
		themes[i] = tid
		emit_changed()


## Every covered cell -> index of the module on it.
func occupied() -> Dictionary:
	var out := {}
	for i in modules.size():
		var r := rect(i)
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				out[Vector2i(x, y)] = i
	return out


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
	themes.resize(modules.size())
	themes.remove_at(i)
	modules.remove_at(i)
	cells.remove_at(i)
	turns.remove_at(i)
	emit_changed()
	return m


func clear() -> void:
	modules.clear()
	cells.clear()
	turns.clear()
	themes.clear()
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


## Where crew stand to work on module i: its access spot k (wrapping
## round), or the middle when it has none. Ship-local metres (x, z).
func spot(i: int, k := 0) -> Vector2:
	var m := modules[i]
	var r := rect(i)
	if m.access.is_empty():
		return (Vector2(r.position) + Vector2(r.size) * 0.5) * ShipView.CELL
	var p := Prism.turned(PackedVector2Array([m.access[k % m.access.size()]]),
			Vector2(m.size), turns[i])
	return (Vector2(r.position) + p[0]) * ShipView.CELL
