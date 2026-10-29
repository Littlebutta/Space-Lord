class_name FleetPanel
extends CanvasLayer
## Window for the selected fleet on the map: its ships, with a way into
## each one's builder and crew priorities, the fuel they carry, and an
## SOS button once they can't fly any further.

const BUILDER := "res://scenes/ship_editor/ship_editor.tscn"
const CREW := "res://scenes/crew/crew_test.tscn"

var _body := VBoxContainer.new()
var _fuel := Label.new()
var _note := Label.new()
var _sos := Button.new()


func _ready() -> void:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = 320
	p.add_child(_body)
	UiKit.pin(self, p, Control.PRESET_TOP_LEFT, Vector2(12, 60))
	var ships := Fleet.ships()
	_body.add_child(UiKit.header("Fleet · %d ships" % ships.size() if ships.size() > 1
			else "Fleet"))
	for d in ships:
		_ship_row(d)
	_body.add_child(UiKit.header("Supplies"))
	_body.add_child(_fuel)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body.add_child(_note)
	_sos.text = "Send SOS signal"
	_sos.tooltip_text = "Someone will answer: a merchant, a pirate or a good samaritan"
	_sos.pressed.connect(func(): Fleet.call_sos(GameClock.hours))
	_body.add_child(_sos)


func _ship_row(d: ShipDesign) -> void:
	var l := Label.new()
	l.text = "%s · %d parts · %d crew" % [d.ship_name, d.modules.size(),
			Wallet.crew_for(d).size()]
	_body.add_child(l)
	var row := HBoxContainer.new()
	for b in [["Ship builder", BUILDER], ["Crew priorities", CREW]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.pressed.connect(func(): get_tree().change_scene_to_file(b[1]))
		row.add_child(btn)
	_body.add_child(row)


func _process(_delta: float) -> void:
	_fuel.text = "Fuel %.0f / %.0f · burns %.1f an hour flying\nCredits %d" % [
			Fleet.tank(), Fleet.cap(), Fleet.burn(), Wallet.credits]
	var help := not Fleet.sos.is_empty()
	_sos.visible = Fleet.stranded() and not help
	_note.text = ""
	if help:
		_note.text = "SOS sent. A ship is %d hours out." % ceili(
				Fleet.sos.eta * (1.0 - Fleet.sos_progress(GameClock.hours)))
	elif Fleet.stranded():
		_note.text = "Out of fuel. Send an SOS to call for help."
