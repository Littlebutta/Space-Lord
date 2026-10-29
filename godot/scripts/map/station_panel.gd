class_name StationPanel
extends CanvasLayer
## Trade window for a neutral station: hire crew, buy food, sell ore
## carried in the hold and buy the station faction's part blueprints.
## Refit opens the builder with full station refit rights.

var site: Dictionary
var _body := VBoxContainer.new()


func _ready() -> void:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = 340
	p.add_child(_body)
	UiKit.pin(self, p, Control.PRESET_CENTER_RIGHT)
	_fill()


func _process(_delta: float) -> void:
	if site.pos.distance_to(Travel.pos) > Travel.DOCK_RANGE:
		queue_free()  # flew off


## Rebuilds the window; every purchase calls this to show new totals.
func _fill() -> void:
	for c in _body.get_children():
		c.queue_free()
	var d := Wallet.ship()
	_body.add_child(UiKit.header(site.name))
	_line("Credits %d" % Wallet.credits)
	_body.add_child(UiKit.header("Services"))
	if d:
		_line("Crew aboard %d / %d berths" % [Wallet.crew_for(d).size(), d.total(&"berths")])
		for sp in CrewSpecies.all():
			_buy("Hire %s" % sp.display_name, "%d cr" % sp.hire_cost,
					Wallet.hire.bind(d, sp)).tooltip_text = sp.blurb
		_buy("Food in hold %.0f" % Wallet.cargo.get("food", 0.0),
				"Buy 20 (%d cr)" % (20 * Wallet.PRICES.food), Wallet.buy_food.bind(d, 20.0))
		_buy("Fuel %.0f / %.0f" % [Fleet.tank(), Fleet.cap()],
				"Fill (%d cr)" % ceili(Fleet.room() * Wallet.PRICES.fuel), Wallet.buy_fuel.bind(INF))
	else:
		_line("Build and save a ship to hire crew or buy food")
	_body.add_child(UiKit.header("Sell ore"))
	var any := false
	for k in Materials.ALL:
		var n: float = Wallet.cargo.get(k, 0.0)
		if n >= 1.0:
			any = true
			var cr := int(n * Wallet.PRICES[k] * Wallet.SELL_SHARE)
			_buy("%s %.0f" % [k.capitalize(), n], "Sell (%d cr)" % cr, Wallet.sell.bind(k))
	if not any:
		_line("No ore in the hold. Mine asteroids, then come back.")
	_body.add_child(UiKit.header("Blueprints"))
	for b in Blueprint.sold_by(site.faction):
		var cost := "%d cr" % b.price
		if not b.materials.is_empty():
			cost += ", " + Materials.line(b.materials)
		var btn := _buy("%s\n%s" % [b.title(), cost], "Owned" if Wallet.owns(b) else "Buy", b.buy)
		btn.disabled = Wallet.owns(b)
	var row := HBoxContainer.new()
	_body.add_child(row)
	_button(row, "Refit ship", _refit)
	_button(row, "Undock", queue_free)


func _line(t: String) -> void:
	var l := Label.new()
	l.text = t
	_body.add_child(l)


## A label with a button; the button runs `act` and refreshes.
func _buy(t: String, label: String, act: Callable) -> Button:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = t
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	_body.add_child(row)
	return _button(row, label, func(): act.call(); _fill())


func _button(row: Control, t: String, act: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(act)
	row.add_child(b)
	return b


func _refit() -> void:
	Shipyard.docked = true
	get_tree().change_scene_to_file("res://scenes/ship_editor/ship_editor.tscn")
