class_name CrewBreach
extends RefCounted
## A crew member's boarding run (job "breach", player orders only). They
## walk to a Breaching Pod bay and climb in. Once it latches onto the
## dead ship they spread through it, stripping one module after another
## for parts the pod carries home, until the pod is recalled; then they
## head back to it and ride home. See BreachPod.

const CUT := 5.0  # seconds to strip a module aboard
const YIELD := 1.5  # parts per unit of module mass


## Sends c to board ship `t` at module k from a free bay. False if none.
static func order(sim: CrewSim, c: CrewMember, t: ShipBody, k: int) -> bool:
	var me := sim.get_parent() as ShipBody
	var bay := BreachPod.free_bay(me, t) if me else -1
	if bay < 0 or c.eva or c.strand >= 0.0 or not c.species.eva \
			or not sim.nav.connected(c.pos, sim.state.spot(bay)):
		return false
	sim.drop(c)
	var j := CrewJob.new()
	j.key = "b%d.%d" % [bay, c.get_instance_id()]
	j.type = &"breach"
	j.module = bay
	j.target = k
	j.wreck = t
	j.slot = BreachPod.of(me, bay).boarders().size()
	j.label = "Boarding the enemy by breaching pod"
	sim.board.jobs[j.key] = j
	j.worker = c
	c.job = j
	c.order = true
	BreachPod.of(me, bay).call_for(t, k)
	return true


static func work(sim: CrewSim, c: CrewMember, delta: float) -> void:
	var me := sim.get_parent() as ShipBody
	var pod := BreachPod.of(me, c.job.module)
	var w: ShipBody = c.job.wreck
	if pod.target != w and not c.hidden:
		sim.finish(c)  # the pod left without them, or went home
		return
	match c.stage:
		1:  # at the bay: climb in, unless it already left
			if pod.mode != &"loading":
				sim.finish(c)
				return
			pod.board(c)
			c.stage = 2
		2:  # riding along until it latches
			if pod.mode in [&"latched", &"recall"]:
				c.hidden = false
				c.eva = true
				c.air = CrewEva.AIR_RIG
				c.pos = me.at.affine_inverse() * pod.at
				pod.crew.erase(c)
				c.stage = 3
		3, 4:
			c.air = CrewEva.AIR_RIG  # the wreck still holds some air
			if pod.mode == &"recall":
				c.stage = 5
			else:
				_strip(sim, c, pod, delta)
		5:  # back to the pod
			if CrewEva.fly(c, me.at.affine_inverse() * pod.at, delta, false, false):
				pod.board(c)
				c.stage = 6


## Goes to the nearest module still standing on the wreck and strips it.
static func _strip(sim: CrewSim, c: CrewMember, pod: BreachPod, delta: float) -> void:
	var me := sim.get_parent() as ShipBody
	var w: ShipBody = c.job.wreck
	var ws := w.sim.state
	var t := c.job.target
	if t < 0 or ws.hp[t] <= 0.0 or pod.loot >= BreachPod.LOOT_CAP:
		t = -1 if pod.loot >= BreachPod.LOOT_CAP else _nearest(ws, w.at.affine_inverse() * pod.at)
		c.job.target = t
		c.stage = 3
		c.timer = 0.0
		if t < 0:
			return  # nothing left worth taking: wait for the recall
	var to := me.at.affine_inverse() * w.world(ws.pieces.world(t))
	if c.stage == 3:
		if CrewEva.fly(c, to, delta, false, false):
			c.stage = 4
		return
	c.timer += delta
	if c.timer >= CUT:
		c.timer = 0.0
		pod.loot = minf(pod.loot + ceilf(ws.module(t).mass * YIELD), BreachPod.LOOT_CAP)
		ws.damage(t, INF)


static func _nearest(ws: ShipState, from: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in ws.size():
		var d := from.distance_squared_to(ws.pieces.world(i))
		if ws.hp[i] > 0.0 and d < best_d:
			best = i
			best_d = d
	return best
