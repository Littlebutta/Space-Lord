class_name CrewSim
extends Node3D
## Runs one ship's crew: free movement with light avoidance, job pickup
## by priority, and what their work does to the ShipState. A single
## MultiMesh draws the whole crew so big ships and fleets stay cheap.

signal crew_changed

const SPEED := 3.0  # metres per second
const CARRY := 20.0  # units per haul trip
const LOAD_TIME := 0.6  # seconds to load or unload
const REPAIR_RATE := 20.0  # hp per second
const THINK := 0.5  # seconds between job board passes
const RADIUS := 0.3
const NAMES := ["Ada", "Bo", "Cy", "Dee", "Eli", "Fay", "Gus", "Hal",
		"Ivy", "Jo", "Kit", "Lux", "Moe", "Nia", "Oz", "Pip"]

@export var hours_per_second := 0.05  # game time burned per real second

var state: ShipState
var nav: ShipNav
var board: JobBoard
var crew: Array[CrewMember] = []
var _mm := MultiMeshInstance3D.new()
var _think := 0.0


func setup(d: ShipDesign, count: int) -> void:
	state = ShipState.new(d)
	nav = ShipNav.new(d)
	board = JobBoard.new(state, nav)
	_mm.multimesh = CrewLook.multimesh()
	add_child(_mm)
	for k in count:
		add_crew()


func add_crew() -> void:
	var c := CrewMember.new(NAMES[crew.size() % NAMES.size()])
	c.pos = _home() + Vector2(randf() - 0.5, randf() - 0.5)
	crew.append(c)
	crew_changed.emit()


func remove_crew() -> void:
	if crew.is_empty():
		return
	_drop(crew[-1])
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
	for c in crew:
		_act(c, delta)
	_separate()
	state.tick(delta * hours_per_second)
	CrewLook.draw(_mm.multimesh, crew, nav, delta)


func _act(c: CrewMember, delta: float) -> void:
	var j := c.job
	if j == null:
		return
	if j.done and j.worker == c and j.type == &"operate":
		_drop(c)
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
	c.source = _nearest_store(c.job.res, c.pos, c.job.module)
	return c.source


func _work(c: CrewMember, delta: float) -> void:
	var j := c.job
	match j.type:
		&"operate":
			state.operators[j.module] += 1
		&"repair":
			state.repair(j.module, REPAIR_RATE * delta)
			if not state.damaged(j.module):
				_finish(c)
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
				_finish(c)


func _go(c: CrewMember, module: int) -> void:
	if module < 0:
		_drop(c)
		return
	var at := state.center(module) + _seat(c)
	c.path = nav.route(c.pos, at)
	if c.path.is_empty() and not nav.connected(c.pos, at):
		_drop(c)


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


func _finish(c: CrewMember) -> void:
	board.finish(c.job)
	_drop(c)


## Lets go of the current job, putting back anything carried.
func _drop(c: CrewMember) -> void:
	if c.cargo > 0.0:
		state.storage.put(c.job.res if c.job else "", c.cargo)
		c.cargo = 0.0
	if c.job and c.job.worker == c:
		c.job.worker = null
	c.job = null
	c.stage = 0
	c.timer = 0.0
	c.path.clear()


## Nudges standing crew apart so they don't stack; walkers slip past
## each other so corridors never jam. Bucketed so it stays O(n).
func _separate() -> void:
	var grid := {}
	for c in crew:
		if not c.arrived():
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
	if a.get_instance_id() >= b.get_instance_id() or d >= RADIUS * 2.0 \
			or d < 0.001:
		return
	var p := off / d * (RADIUS * 2.0 - d) * 0.2
	if nav.walkable(a.pos + p):
		a.pos += p
	if nav.walkable(b.pos - p):
		b.pos -= p


func _nearest_store(res: String, from: Vector2, skip: int) -> int:
	var best := skip if state.module(skip).storage.has(res) else -1
	var best_d := INF
	for i in state.size():
		var at := state.center(i)
		if i == skip or not state.module(i).storage.has(res) \
				or not nav.connected(from, at):
			continue
		if from.distance_squared_to(at) < best_d:
			best = i
			best_d = from.distance_squared_to(at)
	return best


func _home() -> Vector2:
	for i in state.size():
		if state.module(i).berths > 0:
			return state.center(i)
	return state.center(0)
