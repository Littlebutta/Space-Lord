class_name MiningField
extends Node3D
## Asteroids at a map site. Left click a rock for what's in it (see
## RockPopup) and Target it: every running Mining Laser in reach turns
## to it and cuts chunks of iron, copper, silicon or gold loose. Chunks
## float until crew (CrewMining) fetch them into the hold. Rocks are
## solid (RockBumps): ramming one hurts.

const RANGE := 150.0  # laser reach to the rock's surface, metres
const CHUNK := 5.0  # units per chunk
const DAMP := 0.6  # chunks slow to a float
const PULL := 4.0  # metres per second a chunk drifts when pulled by mind

var ship: ShipBody
var site: Dictionary
var target := -1
var rocks: Array[Dictionary] = []  # {node, r, left: material -> units}
var chunks := {}  # id -> {node, vel, res, amount, carrier}
var bumps: RockBumps
var _next := 0
var _cut := {}  # laser module -> units cut toward the next chunk
var _beams := {}  # laser module -> MiningBeam
var _popup := RockPopup.new()


func bind(s: ShipBody, at_site: Dictionary) -> void:
	ship = s
	site = at_site
	ship.sim.board.field = self
	bumps = RockBumps.new(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = site.seed
	var mid := ship.world(ship.pivot()) + Vector2(0.0, -110.0)
	var n := 6
	for k in n:
		var r := rng.randf_range(8.0, 20.0)
		var p := mid + Vector2(rng.randf_range(-90, 90), rng.randf_range(-50, 50))
		var mix := Materials.mix(rng)
		var left := {}
		for m in mix:
			left[m] = roundf(mix[m] * site.ore / n)
		rocks.append({node = _rock(rng, r, p, mix), r = r, left = left})
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(_popup)
	_popup.field = self


func _rock(rng: RandomNumberGenerator, r: float, p: Vector2, mix: Dictionary) -> MeshInstance3D:
	var kind: String = mix.keys().reduce(func(a, k): return k if mix[k] > mix[a] else a)
	var mi := MeshInstance3D.new()
	mi.mesh = AsteroidArt.mesh(rng, r, StringName(kind))
	mi.position = Vector3(p.x, 0.0, p.y)
	mi.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU
	add_child(mi)
	return mi


func ore(k: int) -> float:
	var sum := 0.0
	for m in rocks[k].left:
		sum += rocks[k].left[m]
	return sum


## Metres from module i's mount to rock k's surface.
func reach(i: int, k: int) -> float:
	return _world(_mount(i)).distance_to(rocks[k].node.position) - rocks[k].r


func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b == null or not b.pressed or b.button_index != MOUSE_BUTTON_LEFT:
		return
	var cam := get_viewport().get_camera_3d()
	var from := cam.project_ray_origin(b.position)
	var dir := cam.project_ray_normal(b.position)
	for k in rocks.size():
		var c: Vector3 = rocks[k].node.position
		if (c - from).dot(dir) > 0.0 and (c - from).cross(dir).length() < rocks[k].r:
			_popup.open(k)
			get_viewport().set_input_as_handled()
			return


func _physics_process(delta: float) -> void:
	var st := ship.sim.state
	for i in st.size():
		if st.module(i).mining > 0.0:
			_laser(i, delta)
	bumps.tick()
	for id in chunks:
		var c: Dictionary = chunks[id]
		var n: Node3D = c.node
		if c.carrier:
			var cr: CrewMember = c.carrier
			var held := Vector3(cr.face.x * 0.45, 1.0, cr.face.y * 0.45)  # out in front
			if cr.species.pulls():  # floated along by mind, over their head
				held = Vector3(0.0, 2.1 + sin(Time.get_ticks_msec() * 0.003) * 0.1, 0.0)
			n.position = _world(ship.sim.local3d(cr) + held)
			continue
		n.position += c.vel * delta
		c.vel *= 1.0 - DAMP * delta
		n.rotate_y(delta * 0.7)


## Laser module i turns to the target and cuts at it while running,
## in reach and lined up.
func _laser(i: int, delta: float) -> void:
	var st := ship.sim.state
	var rock: Dictionary = rocks[target] if target >= 0 else {}
	var on: bool = not rock.is_empty() and ore(target) > 0.0 and st.is_running(i) \
			and not st.pieces.drifting(i) and reach(i, target) < RANGE
	if on and not ShipGuns.aim_head(ship.hulk.part(i), rock.node.position, delta):
		on = false
	var from := _muzzle(i)
	var bite: Vector3 = rock.node.position + (from - rock.node.position).normalized() \
			* rock.r * 0.9 if on else from  # the rock's near face
	_beam(i, from, bite, on)
	if not on:
		return
	_cut[i] = _cut.get(i, 0.0) + st.module(i).mining * delta
	if _cut[i] < CHUNK:
		return
	_cut[i] = 0.0
	var res := _pick(rock.left)
	var amount := minf(CHUNK, rock.left[res])
	rock.left[res] -= amount
	site.ore = maxf(site.ore - amount, 0.0)
	var out: Vector3 = (from - rock.node.position).normalized()
	_spawn(rock.node.position + out * (rock.r + 1.0), out * 1.5, res, amount)
	if ore(target) <= 0.0:
		target = -1


## A material from what's left, weighted by how much.
static func _pick(left: Dictionary) -> String:
	var roll: float = randf() * left.values().reduce(func(a, b): return a + b, 0.0)
	for m in left:
		roll -= left[m]
		if roll <= 0.0 and left[m] > 0.0:
			return m
	return left.keys().filter(func(m): return left[m] > 0.0)[0]


## A point in the crew sim's frame, in this field's (the scene's) space.
func _world(p: Vector3) -> Vector3:
	return ShipPieces.to_3d(ship.at) * p


## Top of module i, in the crew sim's frame.
func _mount(i: int) -> Vector3:
	var c := ship.sim.state.center(i)
	return ShipPieces.to_3d(ship.sim.state.pieces.xf[i]) * Vector3(c.x, 1.2, c.y)


## Where the beam leaves: the model's Muzzle marker, else the mount.
func _muzzle(i: int) -> Vector3:
	var n: Node3D = ship.hulk.part(i) if ship.hulk else null
	var mz: Node3D = n.find_child("Muzzle*", true, false) as Node3D if n else null
	return mz.global_position if mz and mz.is_inside_tree() else _world(_mount(i))


func _beam(i: int, from: Vector3, to: Vector3, on: bool) -> void:
	if not _beams.has(i):
		_beams[i] = MiningBeam.new()
		add_child(_beams[i])
	var n: Node3D = ship.hulk.part(i) if ship.hulk else null
	_beams[i].muzzle = n.find_child("Muzzle*", true, false) as Node3D if n else null
	_beams[i].span(from, to, on)


func _spawn(at: Vector3, vel: Vector3, res: String, amount: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = OreLump.mesh(res)
	mi.position = Vector3(at.x, CrewEva.UP, at.z)  # up where spacewalkers fly
	mi.rotation = Vector3(randf(), randf(), randf()) * TAU
	add_child(mi)
	chunks[_next] = {node = mi, vel = vel + Vector3(randf() - 0.5, 0, randf() - 0.5) * 0.4,
			res = res, amount = amount, carrier = null}
	_next += 1


## Chunks nobody is carrying, nearest the ship first.
func loose() -> Array:
	var me := _world(Vector3.ZERO)
	var ids := chunks.keys().filter(func(id): return chunks[id].carrier == null)
	ids.sort_custom(func(a, b): return chunks[a].node.position.distance_squared_to(me) \
			< chunks[b].node.position.distance_squared_to(me))
	return ids


func amount(id: int) -> float:
	return chunks[id].amount if chunks.has(id) else 0.0


func res(id: int) -> String:
	return chunks[id].res if chunks.has(id) else ""


## Where chunk id floats in the crew sim's frame, or null if it's gone.
func local(id: int) -> Variant:
	if not chunks.has(id):
		return null
	var p: Vector3 = ShipPieces.to_3d(ship.at).affine_inverse() * chunks[id].node.position
	return Vector2(p.x, p.z)


## Telekinesis: draws chunk id toward `to` (sim frame) at deck height.
## True once it's there.
func drag(id: int, to: Vector2, delta: float) -> bool:
	var at: Vector2 = local(id)
	var step := PULL * delta
	var p := to if at.distance_to(to) <= step else at.move_toward(to, step)
	chunks[id].node.position = _world(Vector3(p.x, 1.5, p.y))
	chunks[id].vel = Vector3.ZERO
	return p == to


## Crew member c grabs chunk id; returns the units in it.
func pick(id: int, c: CrewMember) -> float:
	if not chunks.has(id) or chunks[id].carrier:
		return 0.0
	chunks[id].carrier = c
	return chunks[id].amount


## The chunk went into the hold.
func stow(id: int) -> void:
	if chunks.has(id):
		chunks[id].node.queue_free()
		chunks.erase(id)


## Let go of chunk id at `at` (sim frame) with `left` units still in it.
func release(id: int, at: Vector2, left: float) -> void:
	if not chunks.has(id):
		return
	var c: Dictionary = chunks[id]
	c.carrier = null
	c.amount = left
	c.node.position = _world(Vector3(at.x, CrewEva.UP, at.y))
	c.vel = Vector3(ship.vel.x, 0.0, ship.vel.y) * 0.5
