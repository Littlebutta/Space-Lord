class_name CrewEva
extends RefCounted
## Spacewalks. A crew member walks to an airlock, steps out, jetpacks to
## a drifting piece (or a wrecked gap in the hull), tethers it, tows it
## home and welds it back on, paying the parts from storage. Anyone left
## outside with nothing to do flies back to the nearest airlock.

const FLY := 2.5  # metres per second on a jetpack
const WELD_TIME := 2.0  # seconds to tether a piece or prep a gap


static func work(sim: CrewSim, c: CrewMember, delta: float) -> void:
	var s := sim.state
	var p := s.pieces
	var t := c.job.target
	if c.stage > 1 and not (p.drifting(t) or s.hp[t] <= 0.0):
		sim.finish(c)  # someone else brought it back
		return
	match c.stage:
		1:  # at the airlock: step outside
			c.eva = true
			c.stage = 2
		2:
			if fly(c, p.world(t), delta):
				c.stage = 3
		3:
			c.timer += delta
			if c.timer >= WELD_TIME:
				c.timer = 0.0
				c.stage = 4
				if not s.can_pay(s.reattach_cost(t)):
					sim.finish(c)  # not enough parts after all
		4:  # tow the piece home riding on it, then weld the gap shut
			if p.drifting(t) and not p.tow(t, delta):
				c.pos = p.world(t)
				return
			c.pos = p.home(t)
			if s.reattach(t):
				c.eva = false  # standing on rebuilt deck now
			else:
				p.update()  # couldn't weld it: it drifts off again
			sim.finish(c)


## Outside with no job: head for the nearest airlock and go back in.
static func go_home(sim: CrewSim, c: CrewMember, delta: float) -> void:
	var a := sim.state.airlock(c.pos)
	if a >= 0 and fly(c, sim.state.center(a), delta):
		c.eva = false


## Moves straight toward `to`; true on arrival.
static func fly(c: CrewMember, to: Vector2, delta: float) -> bool:
	var d := c.pos.distance_to(to)
	if d <= FLY * delta:
		c.pos = to
		return true
	c.pos += (to - c.pos) / d * FLY * delta
	return false
