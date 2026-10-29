class_name CrewSalvage
extends RefCounted
## Salvage runs on a derelict. Ordered out (see CrewOutside), a crew
## member steps out an airlock, jetpacks to the wreck's airlock (or the
## module itself if it has none), cycles it open, climbs through to the
## module picked and strips it for parts, then carries them home to
## storage. A stripped module is gone from the wreck.

const RES := "parts"
const CYCLE := 1.5  # seconds to open the wreck's airlock
const CUT := 4.0  # seconds to strip a module
const YIELD := 2.0  # parts per unit of module mass


static func work(sim: CrewSim, c: CrewMember, delta: float) -> void:
	var w: ShipBody = c.job.wreck
	var t := c.job.target
	if not is_instance_valid(w) or c.stage < 6 and w.sim.state.hp[t] <= 0.0:
		sim.finish(c)  # gone, or someone else stripped it
		return
	var ws := w.sim.state
	match c.stage:
		1:
			c.eva = true
			c.air = CrewEva.AIR_RIG
			c.stage = 2
		2:
			if CrewEva.fly(c, _here(sim, w, _entry(ws, t)), delta, true):
				c.stage = 3
		3:
			c.timer += delta
			if c.timer >= CYCLE:
				c.timer = 0.0
				c.stage = 4
		4:
			if CrewEva.fly(c, _here(sim, w, ws.pieces.world(t)), delta, true, false):
				c.stage = 5
		5:
			c.pos = _here(sim, w, ws.pieces.world(t))
			c.timer += delta
			if c.timer >= CUT:
				c.timer = 0.0
				c.cargo = minf(ceilf(ws.module(t).mass * YIELD), CrewSim.CARRY)
				ws.damage(t, INF)
				c.stage = 6
		6:
			_bring_in(sim, c, delta)
		7:
			c.timer += delta
			if c.timer >= CrewSim.LOAD_TIME:
				sim.state.storage.put(RES, c.cargo)  # any extra is left by the hold
				c.cargo = 0.0
				sim.finish(c)


## Where to get in: the wreck's airlock, else straight to the module.
static func _entry(ws: ShipState, t: int) -> Vector2:
	var a := ws.airlock(ws.pieces.world(t))
	return ws.pieces.xf[a] * ws.spot(a) if a >= 0 else ws.pieces.world(t)


## A point in wreck w's frame, in our crew sim's frame.
static func _here(sim: CrewSim, w: ShipBody, p: Vector2) -> Vector2:
	var me := sim.get_parent() as ShipBody
	return me.at.affine_inverse() * (w.at * p)


static func _bring_in(sim: CrewSim, c: CrewMember, delta: float) -> void:
	var s := sim.state
	var a := s.airlock(c.pos)
	if a < 0:
		sim.finish(c)
	elif CrewEva.fly(c, s.spot(a), delta, true):
		c.eva = false
		var hold := sim.nearest_store(RES, c.pos, a)
		if hold < 0:
			sim.finish(c)
			return
		c.path = sim.nav.route(c.pos, s.spot(hold))
		c.stage = 7
