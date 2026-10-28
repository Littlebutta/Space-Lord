class_name CrewSim
extends Node3D
## Runs one ship's crew: free movement with light avoidance, job pickup
## by priority, and what their work does to the ShipState. CrewLook
## draws them.

signal crew_changed
signal crew_lost(who: String)
## Someone died: where (this node's space), which way they fly, shirt.
signal died(at: Vector3, fling: Vector3, shirt: Color)

const SPEED := 3.0  # metres per second
const CARRY := 20.0  # units per haul trip
const BULK_PULL := 3.0  # haulers walk this much further to use a bulk store
const LOAD_TIME := 0.6  # seconds to load or unload
const REPAIR_RATE := 6.0  # hp per second, so guns can outpace repairs
const THINK := 0.5  # seconds between job board passes
const RADIUS := 0.32  # personal space; crew keep 2x this apart
const NAMES := ["Ada", "Bo", "Cy", "Dee", "Eli", "Fay", "Gus", "Hal",
		"Ivy", "Jo", "Kit", "Lux", "Moe", "Nia", "Oz", "Pip"]

@export var hours_per_second := 0.05  # game time burned per real second

var state: ShipState
var nav: ShipNav
var board: JobBoard
var crew: Array[CrewMember] = []
var lost := 0  # crew who died out in space
var sealed := false  # someone else's ship: crew aboard its main piece go unseen
var _looks := {}  # piece -> CrewLook drawing the crew on it
var _think := 0.0


func setup(d: ShipDesign, count: int) -> void:
	state = ShipState.new(d)
	nav = ShipNav.new(d)
	board = JobBoard.new(state, nav)
	state.pieces.changed.connect(_on_broken)
	for k in count:
		add_crew()


func add_crew() -> void:
	var c := CrewMember.new(NAMES[crew.size() % NAMES.size()])
	c.pos = _home() + Vector2(randf() - 0.5, randf() - 0.5)
	if not nav.walkable(c.pos):  # don't start inside equipment
		c.pos = _home()
	crew.append(c)
	crew_changed.emit()


func remove_crew() -> void:
	if crew.is_empty():
		return
	drop(crew[-1])
	crew.pop_back()
	crew_changed.emit()


func _physics_process(delta: float) -> void:
	if state == null:
		return
	_think -= delta
	if _think <= 0.0:
		_think = THINK
		board.refresh()
		board.assign(crew)
	state.operators.fill(0)
	for c in crew.duplicate():
		_act(c, delta)
	_separate()
	state.tick(delta * hours_per_second)
	state.power.tick(delta)
	state.pieces.tick(delta)
	_draw(delta)


func _act(c: CrewMember, delta: float) -> void:
	if CrewEva.survive(self, c, delta):
		return
	var j := c.job
	if j == null:
		if c.eva:
			CrewEva.go_home(self, c, delta)
		elif not c.arrived():
			_walk(c, delta)  # a move order
		return
	if j.done and j.worker == c and j.type in [&"operate", &"mine"]:
		drop(c)
		c.order = false
		return
	if c.stage == 0:
		_go(c, _first_stop(c))
		c.stage = 1
	if not c.arrived():
		_walk(c, delta)
	elif c.job:
		_work(c, delta)


## Where a job starts: the storage to load from, or the module itself.
func _first_stop(c: CrewMember) -> int:
	if c.job.type != &"haul":
		return c.job.module
	c.source = nearest_store(c.job.res, c.pos, c.job.module)
	return c.source


func _work(c: CrewMember, delta: float) -> void:
	var j := c.job
	match j.type:
		&"operate":
			state.operators[j.module] += 1
		&"repair":
			if not state.crew_repair(j.module, REPAIR_RATE, delta):
				finish(c)
		&"eva":
			CrewEva.work(self, c, delta)
		&"mine":
			CrewMining.work(self, c, delta)
		&"salvage":
			CrewSalvage.work(self, c, delta)
		&"haul":
			c.timer += delta
			if c.timer < LOAD_TIME:
				return
			c.timer = 0.0
			if c.stage == 1:
				var want := minf(CARRY, state.room(j.module, j.res))
				c.cargo = state.storage.take(j.res, want)
				c.stage = 2
				_go(c, j.module)
			else:
				c.cargo -= state.deliver(j.module, j.res, c.cargo)
				finish(c)


func _go(c: CrewMember, module: int) -> void:
	if module < 0:
		drop(c)
		return
	var at := state.center(module) + _seat(c)
	if not state.module(module).access.is_empty():
		at = state.spot(module, c.job.slot)
	c.path = nav.route(c.pos, at)
	if c.path.is_empty() and not nav.connected(c.pos, at):
		drop(c)


## Spreads operators of one module over its floor.
func _seat(c: CrewMember) -> Vector2:
	if c.job.type != &"operate" or state.module(c.job.module).crew < 2:
		return Vector2.ZERO
	var s := c.job.slot
	return Vector2((s % 2) - 0.5, ((s >> 1) & 1) - 0.5) * 0.8


func _walk(c: CrewMember, delta: float) -> void:
	var to := c.path[0]
	var d := c.pos.distance_to(to)
	var move := SPEED * delta
	if d <= move:
		c.pos = to
		c.path.remove_at(0)
	else:
		c.pos += (to - c.pos) / d * move


func finish(c: CrewMember) -> void:
	board.finish(c.job)
	drop(c)
	c.order = false


## Where to draw crew member c, in this node's space.
func local3d(c: CrewMember) -> Vector3:
	var at := Vector3(c.pos.x, c.y, c.pos.y)
	var i := -1 if c.eva else state.design.index_at(Vector2i((c.pos / ShipView.CELL).floor()))
	return ShipPieces.to_3d(state.pieces.xf[i]) * at if i >= 0 else at


## Out of air or caught in a blast: they're gone, leaving a body.
func kill(c: CrewMember, fling := Vector3.ZERO) -> void:
	died.emit(local3d(c), fling, CrewJob.COLORS[c.job.type if c.job else &""])
	drop(c)
	crew.erase(c)
	lost += 1
	crew_lost.emit(c.name)
	crew_changed.emit()


## Lets go of the current job, putting back anything carried.
func drop(c: CrewMember) -> void:
	if c.cargo > 0.0 and c.job and c.job.type == &"mine":
		CrewMining.release(self, c)
	if c.cargo > 0.0:
		state.storage.put(c.job.res if c.job else "", c.cargo)
		c.cargo = 0.0
	if c.job and c.job.worker == c:
		c.job.worker = null
	c.job = null
	c.stage = 0
	c.timer = 0.0
	c.path.clear()


## Keeps crew from overlapping. Idle crew make room, crew at work hold
## their spot, and two walkers slide past each other sideways.
## Bucketed so it stays O(n).
func _separate() -> void:
	var grid := {}
	for c in crew:
		if c.eva:
			continue
		var k := Vector2i((c.pos / (RADIUS * 2.0)).floor())
		if grid.has(k):
			grid[k].append(c)
		else:
			grid[k] = [c]
	for k: Vector2i in grid:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for b in grid.get(k + Vector2i(dx, dy), []):
					for a in grid[k]:
						_push(a, b)


func _push(a: CrewMember, b: CrewMember) -> void:
	var off := a.pos - b.pos
	var d := off.length()
	if a.get_instance_id() >= b.get_instance_id() or d >= RADIUS * 2.0:
		return
	if d < 0.001:
		off = Vector2.RIGHT.rotated(randf() * TAU)
		d = 1.0
	var p := off / d * (RADIUS * 2.0 - d) * 0.5
	var wa := _give(a, b)
	var wb := _give(b, a)
	if not (a.arrived() or b.arrived()):
		p = p.orthogonal().limit_length(0.02)  # sidestep, never shove back
	_nudge(a, p * wa / (wa + wb) * 2.0)
	_nudge(b, -p * wb / (wa + wb) * 2.0)


## Moves c by v, sliding along walls rather than into them.
func _nudge(c: CrewMember, v: Vector2) -> void:
	for t in [v, Vector2(v.x, 0.0), Vector2(0.0, v.y)]:
		if nav.walkable(c.pos + t):
			c.pos += t
			return


## How readily c steps aside for `other`: idle crew most, crew at work
## hardly at all. Walkers keep going past anyone standing (who make
## room) so nobody gets stuck behind a crowd; two walkers share it.
static func _give(c: CrewMember, other: CrewMember) -> float:
	if not c.arrived():
		return 0.5 if not other.arrived() else 0.0
	return 0.1 if c.job else 1.0


## The deck changed shape: re-plan walks, and anyone whose floor was
## just shot away dies in the blast.
func _on_broken() -> void:
	nav = ShipNav.new(state.intact())
	board.nav = nav
	for c in crew.duplicate():
		if c.eva:
			continue
		if not nav.walkable(c.pos):
			var i := state.design.index_at(Vector2i((c.pos / ShipView.CELL).floor()))
			var out: Vector2 = c.pos - state.center(i) if i >= 0 else Vector2.ZERO
			var fling := Vector2.from_angle(randf() * TAU) + out.normalized() * 2.0
			kill(c, Vector3(fling.x, randf_range(0.5, 1.5), fling.y))
		elif not c.path.is_empty():
			c.path = nav.route(c.pos, c.path[-1])
			if c.path.is_empty():
				drop(c)


## One CrewLook per piece so crew ride along when a piece drifts off.
## Crew outside are drawn in the ship's frame.
func _draw(delta: float) -> void:
	var p := state.pieces
	var by := {}
	for c in crew:
		var i := -1 if c.eva else state.design.index_at(Vector2i((c.pos / ShipView.CELL).floor()))
		var k := p.piece_of[i] if i >= 0 else -1
		if not by.has(k):
			var a: Array[CrewMember] = []
			by[k] = a
		by[k].append(c)
	var none: Array[CrewMember] = []
	for k in _looks:
		if not by.has(k):
			_looks[k].draw(none, self, delta)
	for k in by:
		if not _looks.has(k):
			_looks[k] = CrewLook.new()
			add_child(_looks[k])
		var t := p.xf[p.pieces[k][0]] if k >= 0 else Transform2D.IDENTITY
		_looks[k].transform = ShipPieces.to_3d(t)
		_looks[k].visible = not (sealed and k == p.main)
		_looks[k].draw(by[k], self, delta)


## Closest intact store for `res`, bulk stores (supply depots) first.
func nearest_store(res: String, from: Vector2, skip: int) -> int:
	var best := skip if state.module(skip).storage.has(res) else -1
	var best_d := INF
	for i in state.size():
		var m := state.module(i)
		var at := state.spot(i)
		if i == skip or not m.storage.has(res) or state.hp[i] <= 0.0 \
				or not nav.connected(from, at):
			continue
		var d := from.distance_to(at) / (BULK_PULL if m.bulk else 1.0)
		if d < best_d:
			best = i
			best_d = d
	return best


func _home() -> Vector2:
	for i in state.size():
		if state.module(i).berths > 0:
			return state.spot(i)
	return state.spot(0)
