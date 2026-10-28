class_name MiningField
extends Node3D
## Asteroids at a map site. Right click a rock to target it: the ship
## closes in and every running Mining Laser cuts ore chunks loose. The
## chunks float until crew (see CrewMining) fetch them into the hold.

const RANGE := 30.0  # laser reach to the rock's surface, metres
const STANDOFF := 12.0  # the ship parks this far off the targeted rock
const CHUNK := 5.0  # ore per chunk
const DAMP := 0.6  # chunks slow to a float

var ship: ShipBody
var site: Dictionary
var target := -1
var rocks: Array[Dictionary] = []  # {node, ore, r}
var chunks := {}  # id -> {node, vel, amount, carrier}
var _next := 0
var _cut := {}  # laser module -> ore cut so far toward the next chunk
var _beams := {}  # laser module -> beam mesh


func bind(s: ShipBody, at_site: Dictionary) -> void:
	ship = s
	site = at_site
	ship.sim.board.field = self
	var rng := RandomNumberGenerator.new()
	rng.seed = site.seed
	var mid := ship.world(ship.pivot()) + Vector2(0.0, -45.0)
	var n := 6
	for k in n:
		var r := rng.randf_range(2.0, 5.0)
		var p := mid + Vector2(rng.randf_range(-25, 25), rng.randf_range(-15, 15))
		rocks.append({node = _rock(rng, r, p), ore = site.ore / n, r = r})


func _rock(rng: RandomNumberGenerator, r: float, p: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = AsteroidArt.mesh(rng, r)
	mi.position = Vector3(p.x, 0.0, p.y)
	mi.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU
	add_child(mi)
	return mi


func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b == null or not b.pressed or b.button_index != MOUSE_BUTTON_RIGHT:
		return
	var cam := get_viewport().get_camera_3d()
	var from := cam.project_ray_origin(b.position)
	var dir := cam.project_ray_normal(b.position)
	for k in rocks.size():
		var c: Vector3 = rocks[k].node.position
		if rocks[k].ore > 0.0 and (c - from).cross(dir).length() < rocks[k].r + 1.0:
			target = k
			var at := Vector2(c.x, c.z)
			var me := ship.world(ship.pivot())
			ship.goal = at + (me - at).normalized() * (rocks[k].r + STANDOFF)
			get_viewport().set_input_as_handled()
			return


func _physics_process(delta: float) -> void:
	var st := ship.sim.state
	for i in st.size():
		if st.module(i).mining > 0.0:
			_laser(i, delta)
	for id in chunks:
		var c: Dictionary = chunks[id]
		var n: Node3D = c.node
		if c.carrier:
			n.position = _world(ship.sim.local3d(c.carrier)) + Vector3.UP * 1.1  # in their arms
			continue
		n.position += c.vel * delta
		c.vel *= 1.0 - DAMP * delta
		n.rotate_y(delta * 0.7)


## Laser module i cuts at the target while running and in range.
func _laser(i: int, delta: float) -> void:
	var st := ship.sim.state
	var from := _world(_mount(i))
	var rock: Dictionary = rocks[target] if target >= 0 else {}
	var on: bool = not rock.is_empty() and rock.ore > 0.0 and st.is_running(i) \
			and not st.pieces.drifting(i) \
			and from.distance_to(rock.node.position) - rock.r < RANGE
	_beam(i, from, rock.node.position if on else from, on)
	if not on:
		return
	_cut[i] = _cut.get(i, 0.0) + st.module(i).mining * delta
	if _cut[i] < CHUNK:
		return
	_cut[i] = 0.0
	var amount := minf(CHUNK, rock.ore)
	rock.ore -= amount
	site.ore = maxf(site.ore - amount, 0.0)
	var out: Vector3 = (from - rock.node.position).normalized()
	_spawn(rock.node.position + out * rock.r, out * 1.5, amount)
	if rock.ore <= 0.0:
		rock.node.scale *= 0.5
		target = -1


## A point in the crew sim's frame, in this field's (the scene's) space.
func _world(p: Vector3) -> Vector3:
	return ShipPieces.to_3d(ship.at) * p


## Top of module i, in the crew sim's frame.
## Where module i's beam starts: its model's muzzle, else its middle.
func _mount(i: int) -> Vector3:
	var n := ship.hulk.part(i)
	var mz := n.find_child("Muzzle*", true, false) as Node3D if n else null
	if mz and mz.is_inside_tree():
		return ship.to_local(mz.global_position)  # the crew sim's frame
	var c := ship.sim.state.center(i)
	return ShipPieces.to_3d(ship.sim.state.pieces.xf[i]) * Vector3(c.x, 1.2, c.y)


func _beam(i: int, from: Vector3, to: Vector3, on: bool) -> void:
	if not _beams.has(i):
		_beams[i] = MiningBeam.new()
		add_child(_beams[i])
	_beams[i].span(from, to, on)


func _spawn(at: Vector3, vel: Vector3, amount: float) -> void:
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.4
	m.material = MapGlow.make(Color(0.95, 0.65, 0.25), 0.6, false)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = at
	add_child(mi)
	chunks[_next] = {node = mi, vel = vel + Vector3(randf() - 0.5, 0, randf() - 0.5) * 0.4,
			amount = amount, carrier = null}
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


## Where chunk id floats in the crew sim's frame, or null if it's gone.
func local(id: int) -> Variant:
	if not chunks.has(id):
		return null
	var p: Vector3 = ShipPieces.to_3d(ship.at).affine_inverse() * chunks[id].node.position
	return Vector2(p.x, p.z)


## Crew member c grabs chunk id; returns the ore in it.
func pick(id: int, c: CrewMember) -> float:
	if not chunks.has(id) or chunks[id].carrier:
		return 0.0
	chunks[id].carrier = c
	return chunks[id].amount


## The chunk's ore went into the hold.
func stow(id: int) -> void:
	if chunks.has(id):
		chunks[id].node.queue_free()
		chunks.erase(id)


## Let go of chunk id at `at` (sim frame) with `left` ore still in it.
func release(id: int, at: Vector2, left: float) -> void:
	if not chunks.has(id):
		return
	var c: Dictionary = chunks[id]
	c.carrier = null
	c.amount = left
	c.node.position = _world(Vector3(at.x, 0.5, at.y))
	c.vel = Vector3(ship.vel.x, 0.0, ship.vel.y) * 0.5
