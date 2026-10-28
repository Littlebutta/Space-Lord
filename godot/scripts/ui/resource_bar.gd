class_name ResourceBar
extends PanelContainer
## Top bar of the ship's supplies: one count per group (fuel, ammo,
## materials, food). Hovering a group drops down each type in it. New ammo or
## material types only need adding to GROUPS.

const GROUPS := {
	"Fuel": ["fuel"],
	"Ammo": ["ammo"],
	"Materials": ["iron", "copper", "silicon", "gold", "parts"],
	"Food": ["food"],
}
const NAMES := {"ammo": "Cannon shells", "parts": "Spare parts"}

var source: Callable  # returns the Storage to show
var _totals := {}  # group -> Label
var _lists := {}  # group -> Label in its dropdown
var _wait := 0.0


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	add_child(row)
	for g in GROUPS:
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(l)
		_totals[g] = l
		var drop := PanelContainer.new()
		drop.top_level = true
		drop.visible = false
		drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var list := Label.new()
		drop.add_child(list)
		l.add_child(drop)
		_lists[g] = list
		l.mouse_entered.connect(func():
			drop.global_position = l.global_position + Vector2(-8, l.size.y + 14)
			drop.visible = true)
		l.mouse_exited.connect(func(): drop.visible = false)


func _process(delta: float) -> void:
	_wait -= delta
	var storage: Storage = source.call() if source.is_valid() else null
	if storage == null or _wait > 0.0:
		return
	_wait = 0.25
	for g in GROUPS:
		var have := 0.0
		var cap := 0.0
		var lines: Array[String] = []
		for id in GROUPS[g]:
			have += storage.get_amount(id)
			cap += storage.capacity.get(id, 0.0)
			if storage.capacity.has(id):
				lines.append("%s  %.0f / %.0f" % [NAMES.get(id, id.capitalize()),
						storage.get_amount(id), storage.capacity[id]])
		_totals[g].text = "%s %.0f / %.0f" % [g.to_upper(), have, cap]
		_totals[g].modulate = UiStyle.WARN if cap > 0.0 and have < cap * 0.15 else Color.WHITE
		_lists[g].text = "\n".join(lines) if lines else "No storage aboard"
