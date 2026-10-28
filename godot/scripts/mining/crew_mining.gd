class_name CrewMining
extends RefCounted
## Ore runs. A crew member steps out an airlock, jetpacks to a floating
## chunk of ore, brings it back in and stows it in a hold. Jobs are only
## posted for what fits: what others already plan to bring counts
## against the free space. A full hold stops those runs; carriers let go.

const GRAB := 1.0  # seconds to net a chunk


## Posts a job per loose chunk while what's planned for its material
## still fits in the hold.
static func want(board: JobBoard, want: Dictionary) -> void:
	var f: MiningField = board.field
	if f == null:
		return
	var planned := {}
	for j: CrewJob in board.jobs.values():
		if j.type == &"mine" and j.worker:
			planned[j.res] = planned.get(j.res, 0.0) + f.amount(j.target)
	for id in f.loose():
		var key := "m%d" % id
		if board.jobs.has(key) and board.jobs[key].worker:
			continue  # counted above
		var r := f.res(id)
		if planned.get(r, 0.0) + f.amount(id) > board.state.storage.free_space(r):
			continue
		var a := board.state.airlock(f.local(id))
		if a < 0:
			return
		planned[r] = planned.get(r, 0.0) + f.amount(id)
		want[key] = [&"mine", a, r, 0, id]


static func work(sim: CrewSim, c: CrewMember, delta: float) -> void:
	var f: MiningField = sim.board.field
	var s := sim.state
	if f == null or s.storage.free_space(c.job.res) <= 0.0:
		sim.finish(c)  # hold full: stop, dropping anything carried
		return
	match c.stage:
		1:
			c.eva = true
			c.air = CrewEva.AIR_RIG
			c.stage = 2
		2:
			var at = f.local(c.job.target)
			if at == null or f.chunks[c.job.target].carrier:
				sim.finish(c)
			elif CrewEva.fly(c, at, delta):
				c.stage = 3
		3:
			c.timer += delta
			if c.timer >= GRAB:
				c.timer = 0.0
				c.cargo = f.pick(c.job.target, c)
				if c.cargo > 0.0:
					c.stage = 4
				else:
					sim.finish(c)
		4:
			_bring_in(sim, c, delta)
		5:
			c.timer += delta
			if c.timer >= CrewSim.LOAD_TIME:
				c.cargo -= s.storage.put(c.job.res, c.cargo)
				if c.cargo <= 0.0:
					f.stow(c.job.target)
				sim.finish(c)


## Fly back to an airlock, go in and walk to the nearest ore hold.
static func _bring_in(sim: CrewSim, c: CrewMember, delta: float) -> void:
	var a := sim.state.airlock(c.pos)
	if a < 0:
		sim.finish(c)
	elif CrewEva.fly(c, sim.state.spot(a), delta):
		c.eva = false
		var hold := sim.nearest_store(c.job.res, c.pos, a)
		if hold < 0:
			sim.finish(c)
			return
		c.path = sim.nav.route(c.pos, sim.state.spot(hold))
		c.stage = 5


## Lets go of a carried chunk: in space where they are, or out of the
## nearest airlock if they were already aboard.
static func release(sim: CrewSim, c: CrewMember) -> void:
	var f: MiningField = sim.board.field
	if f == null:
		return
	var at := c.pos
	if not c.eva:
		var a := sim.state.airlock(c.pos)
		at = sim.state.spot(a) if a >= 0 else c.pos
	f.release(c.job.target, at, c.cargo)
	c.cargo = 0.0
