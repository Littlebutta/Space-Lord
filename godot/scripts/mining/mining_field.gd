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

var ship: ShipBody
var site: Dictionary
var target := -1
var rocks: Array[Dictionary] = []  # {node, r, left: material -> units}
var chunks := {}  # id -> {node, vel, res, amount, carrier}
var bumps: RockBumps
var _next := 0
var _cut := {}  # laser module -> units cut toward the next chunk
var _beams := {}  # laser module -> beam mesh
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
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 20
	m.rings = 12
	var mat := StandardMaterial3D.new()
	var tint := Color(0.34, 0.32, 0.3).lerp(Materials.COLORS["copper"], mix.copper * 0.3)
	mat.albedo_color = tint.lerp(Materials.COLORS["gold"], mix.gold)
	mat.roughness = 1.0
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = Vector3(p.x, 0.0, p.y)
	mi.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU
	mi.scale = Vector3(rng.randf_range(0.85, 1.15), rng.randf_range(0.7, 0.95), 1.0)
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
			n.position = _world(ship.sim.local3d(c.carrier)) + Vector3.UP * 0.5
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
	_beam(i, from, rock.node.position if on else from, on)
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
		var m := CylinderMesh.new()
		m.top_radius = 0.08
		m.bottom_radius = 0.08
		m.height = 1.0
		m.material = MapGlow.make(Color(1.0, 0.55, 0.15))
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_beams[i] = mi
	var b: MeshInstance3D = _beams[i]
	b.visible = on and from.distance_to(to) > 0.1
	if b.visible:
		var up := (to - from).normalized()
		var side := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
		var bs := Basis(side, up, side.cross(up)).scaled(Vector3(1, from.distance_to(to), 1))
		b.transform = Transform3D(bs, (from + to) * 0.5)


func _spawn(at: Vector3, vel: Vector3, res: String, amount: float) -> void:
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.5
	m.material = MapGlow.make(Materials.COLORS[res], 0.6, false)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = at
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
	c.node.position = _world(Vector3(at.x, 0.5, at.y))
	c.vel = Vector3(ship.vel.x, 0.0, ship.vel.y) * 0.5
