class_name SosTalk
extends CanvasLayer
## Talking to whoever answered the SOS. Each caller is a small dialog
## tree: a line they say and the replies on offer. A reply can cost
## credits (a price, a share of what you have, or per unit of fuel),
## hand over your ore, give fuel (-1 fills the tanks) and lead on to the
## next line ("" ends the talk, a list picks one at random).

signal finished

const WHO := {&"merchant": "Merchant hauler", &"pirate": "Pirate raider",
		&"samaritan": "Good samaritan"}
const TREES := {
	&"merchant": {
		start = {say = "Trader here, heard your distress call. Fuel's scarce this far out, but I'll sell you some.",
			opts = [{text = "Buy 60 fuel", cost = 240, fuel = 60, next = "deal"},
				{text = "Fill the tanks", per = 6.0, fuel = -1, next = "deal"},
				{text = "That's robbery. Go lower?", next = ["cheap", "firm"]},
				{text = "I'll wait for someone else", next = "bye"}]},
		cheap = {say = "Ha. You look like you need it. 60 for 150, final offer.",
			opts = [{text = "Buy 60 fuel", cost = 150, fuel = 60, next = "deal"},
				{text = "Still too much", next = "bye"}]},
		firm = {say = "Price is the price. Haggle again and it's 300.",
			opts = [{text = "Buy 60 fuel", cost = 300, fuel = 60, next = "deal"},
				{text = "Forget it", next = "bye"}]},
		deal = {say = "Pleasure doing business. Fly safe.", opts = [{text = "Farewell"}]},
		bye = {say = "Suit yourself. Space is big and empty.", opts = [{text = "Watch them leave"}]},
	},
	&"pirate": {
		start = {say = "Well, well. A ship dead in the water. Your fuel problem is now a credits problem.",
			opts = [{text = "Pay them off", share = 0.35, fuel = 80, next = "paid"},
				{text = "Offer all your ore instead", ore = true, fuel = 60, next = "paid"},
				{text = "Bluff: \"My escort is two minutes out.\"", next = ["bluffed", "called"]},
				{text = "Refuse", next = "fight"}]},
		bluffed = {say = "...Fine. 30 fuel for 100 credits, and don't follow us.",
			opts = [{text = "Deal", cost = 100, fuel = 30, next = "paid"},
				{text = "Refuse", next = "fight"}]},
		called = {say = "Nice try. The price just went up.",
			opts = [{text = "Pay up", share = 0.5, fuel = 80, next = "paid"},
				{text = "Refuse", next = "fight"}]},
		paid = {say = "Smart choice. Maybe we'll meet again.", opts = [{text = "Watch them go"}]},
		fight = {say = "Then we'll take it off your wreck!",
			opts = [{text = "Battle stations!", battle = true}]},
	},
	&"samaritan": {
		start = {say = "Easy there, we heard your call. We can spare enough fuel to reach a station.",
			opts = [{text = "Thank you!", fuel = 40, next = "thanks"},
				{text = "Offer 50 credits for a bit more", cost = 50, fuel = 90, next = "thanks"},
				{text = "Could you fill us up?", next = ["kind", "sorry"]}]},
		kind = {say = "Ah, why not. Someone did the same for us once.",
			opts = [{text = "Fill the tanks, thank you", fuel = -1, next = "thanks"}]},
		sorry = {say = "Wish we could. Forty is all we can spare.",
			opts = [{text = "That's plenty, thanks", fuel = 40, next = "thanks"}]},
		thanks = {say = "Clear skies, friend.", opts = [{text = "Wave them off"}]},
	},
}

var kind := &"merchant"
var _body := VBoxContainer.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var p := PanelContainer.new()
	p.custom_minimum_size.x = 420
	p.add_child(_body)
	UiKit.pin(self, p, Control.PRESET_CENTER)
	_show("start")


func _show(id: String) -> void:
	for c in _body.get_children():
		c.queue_free()
	var n: Dictionary = TREES[kind][id]
	_body.add_child(UiKit.header(WHO[kind]))
	var l := Label.new()
	l.text = n.say
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body.add_child(l)
	for o in n.opts:
		if o.get("ore") and not _has_ore():
			continue
		var b := Button.new()
		var cost := _cost(o)
		b.text = o.text + (" (%d cr)" % cost if cost > 0 else "")
		b.disabled = cost > Wallet.credits
		b.pressed.connect(_pick.bind(o))
		_body.add_child(b)


func _pick(o: Dictionary) -> void:
	Wallet.pay(_cost(o))
	if o.get("ore"):
		for k in Materials.ALL:
			Wallet.cargo.erase(k)
	if o.has("fuel"):
		Fleet.add_fuel(o.fuel)
	if o.get("battle"):
		_end()
		get_tree().change_scene_to_file("res://scenes/combat/battle.tscn")
		return
	var next: Variant = o.get("next", "")
	if next is Array:
		next = next[_rng.randi() % next.size()]
	if next == "":
		_end()
	else:
		_show(next)


func _cost(o: Dictionary) -> int:
	if o.has("share"):
		return int(Wallet.credits * o.share)
	if o.has("per"):
		return ceili(o.per * Fleet.room())
	return o.get("cost", 0)


func _has_ore() -> bool:
	return Materials.ALL.any(func(k): return Wallet.cargo.get(k, 0.0) >= 1.0)


func _end() -> void:
	Fleet.sos = {}
	finished.emit()
	queue_free()
