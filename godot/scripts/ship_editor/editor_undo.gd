class_name EditorUndo
extends RefCounted
## Ctrl+Z in the builder. The editor calls mark() before each player
## action; the first change that action makes saves the design as it
## was, so one click (even a symmetric pair) undoes in one step.

const LIMIT := 100

var design: ShipDesign
var _stack := []  # [modules, cells, turns, themes] before each action
var _pending: Variant = null
var _busy := false


func _init(d: ShipDesign) -> void:
	design = d
	d.changed.connect(_on_changed)


func mark() -> void:
	_pending = [design.modules.duplicate(), design.cells.duplicate(),
			design.turns.duplicate(), design.themes.duplicate()]


## Puts the design back as it was before the last action; false if none.
func undo() -> bool:
	if _stack.is_empty():
		return false
	var s: Array = _stack.pop_back()
	_busy = true
	design.modules = s[0]
	design.cells = s[1]
	design.turns = s[2]
	design.themes = s[3]
	design.emit_changed()
	_busy = false
	_pending = null
	return true


func _on_changed() -> void:
	if _pending == null or _busy:
		return
	_stack.append(_pending)
	_pending = null
	if _stack.size() > LIMIT:
		_stack.pop_front()
