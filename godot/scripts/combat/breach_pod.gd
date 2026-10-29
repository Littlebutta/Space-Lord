class_name BreachPod
extends Node3D
## The capsule a Breaching Pod bay fires at a dead ship. Crew ordered to
## board (CrewBreach) climb in; once everyone heading for it is aboard
## it flies over and latches on, and they spread through the wreck
## stripping it for parts. Click the pod and recall it: crew who can
## make it back climb in, it unlatches and docks in its bay again, and
## the parts go to the hold.

const SPEED := 14.0  # metres per second in flight
const UP := 1.2  # flies this high over the deck
const LOOT_CAP := 60.0  # parts it can bring back

var home: ShipBody
var bay := -1  # our module the pod lives in
var mode := &"docked"  # docked, loading, out, latched, recall, back
var target: ShipBody
var anchor := Vector2.ZERO  # where it latches, target ship-local
var crew: Array[CrewMember] = []  # inside right now
var loot := 0.0
var selected := false
var at := Vector2.ZERO  # world (x, z)
var _ring: MeshInstance3D


## The pod of bay module i on ship b (made the first time it's asked).
static func of(b: ShipBody, i: int) -> BreachPod:
	var pods: Dictionary = b.get_meta(&"pods", {})
	if not pods.has(i) or not is_instance_valid(pods[i]):
		var p := BreachPod.new()
		p.home = b
		p.bay = i
		pods[i] = p
		b.set_meta(&"pods", pods)
		if b.get_parent():
			b.get_parent().add_child(p)
		else:
			b.add_child(p)
	return pods[i]


## Every pod ship b has launched so far.
static func all(b: ShipBody) -> Array:
	return b.get_meta(&"pods", {}).values().filter(func(p): return is_instance_valid(p))


## A free bay on ship b for boarding `t` (its pod docked, or loading for
## the same ship with a seat left), else -1.
static func free_bay(b: ShipBody, t: ShipBody) -> int:
	var s := b.sim.state
	for i in s.size():
		if s.module(i).breach <= 0 or s.hp[i] <= 0.0 or s.pieces.drifting(i):
			continue
		var p := of(b, i)
		var seats := s.module(i).breach - p.boarders().size()
		if p.mode == &"docked" or p.mode == &"loading" and p.target == t and seats > 0:
			return i
	return -1


## Out of the fight: its bridge is gone or cut off.
static func offline(b: ShipBody) -> bool:
	var p := b.sim.state.pieces
	return p.main < 0 or not p.has_bridge(p.main)


func _init() -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.55
	cap.height = 2.4
	mi.mesh = cap
	mi.rotation.x = PI / 2.0  # lies along its flight
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.46, 0.42)
	mat.metallic = 0.6
	mat.roughness = 0.5
	mi.material_override = mat
	add_child(mi)
	add_child(FxKit.light(Color(1.0, 0.5, 0.25), 1.5, 4.0))
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 1.3
	t.outer_radius = 1.45
	_ring.mesh = t
	_ring.material_override = FxKit.glow_mat(Color(0.4, 0.85, 1.0), false)
	add_child(_ring)
	visible = false


## Crew still on a boarding run with this pod (alive, not released).
func boarders() -> Array[CrewMember]:
	return home.sim.crew.filter(func(c): return c.job and c.job.type == &"breach" \
			and c.job.module == bay and c.job.wreck == target)


## A crew member ordered to board `t` at module k: the pod waits for them.
func call_for(t: ShipBody, k: int) -> void:
	if mode == &"docked":
		mode = &"loading"
		target = t
		anchor = t.sim.state.pieces.world(k)
		loot = 0.0


func board(c: CrewMember) -> void:
	if not crew.has(c):
		crew.append(c)
	c.hidden = true


## Sends everyone back to the pod to go home.
func recall() -> void:
	if mode in [&"latched", &"out", &"loading"]:
		mode = &"recall" if mode == &"latched" else &"back"
	selected = false


func _physics_process(delta: float) -> void:
	if not is_instance_valid(home):
		queue_free()
		return
	var left := boarders()
	crew = crew.filter(func(c): return left.has(c))
	var dock := home.world(home.sim.state.pieces.world(bay))
	if not is_instance_valid(target) and mode != &"docked":
		mode = &"back"
	match mode:
		&"docked":
			at = dock
		&"loading":
			at = dock
			if left.is_empty():
				mode = &"docked"
			elif crew.size() == left.size():
				mode = &"out"
		&"out":
			if _fly(target.world(anchor), delta):
				mode = &"latched"
		&"latched":
			at = target.world(anchor)
		&"recall":
			at = target.world(anchor)
			if crew.size() == left.size():
				mode = &"back"
		&"back":
			if _fly(dock, delta):
				_dock()
	visible = mode in [&"out", &"latched", &"recall", &"back"]
	_ring.visible = selected and visible
	position = Vector3(at.x, UP, at.y)


## Flies toward world point `to`, nose first; true on arrival.
func _fly(to: Vector2, delta: float) -> bool:
	var d := at.distance_to(to)
	if d > 0.01:
		var dir := (to - at) / d
		rotation.y = atan2(-dir.x, -dir.y)
	at = at.move_toward(to, SPEED * delta)
	return d <= SPEED * delta


## Home: crew climb out into the bay and the parts go to storage.
func _dock() -> void:
	var s := home.sim.state
	s.storage.put(CrewSalvage.RES, loot)
	loot = 0.0
	var a := s.airlock(s.spot(bay))
	var out := s.spot(bay) if s.hp[bay] > 0.0 or a < 0 else s.spot(a)
	for c in crew:
		c.hidden = false
		c.eva = false
		c.alt = 0.0
		c.pos = out
		home.sim.finish(c)
	crew.clear()
	mode = &"docked"
	target = null
