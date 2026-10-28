class_name CrewEva
extends RefCounted
## Spacewalks. A crew member walks to an airlock, steps out, jetpacks to
## a drifting piece (or a wrecked gap in the hull), tethers it, tows it
## home and welds it back on, paying the parts from storage. Anyone left
## outside with nothing to do flies back to the nearest airlock.

const FLY := 2.5  # metres per second on a jetpack
const UP := 5.0  # metres above the deck crew fly at outside, clear of the hull
const CLIMB := 2.5  # metres per second up out of an airlock, or down into one
const WELD_TIME := 2.0  # seconds to tether a piece or prep a gap
const AIR_SUIT := 30.0  # seconds in an emergency suit
const AIR_RIG := 180.0  # a proper rig for planned spacewalks
const BAIL := Vector2(4.0, 14.0)  # seconds before someone leaves a dead piece


## Air and dead pieces. Anyone outside burns air and dies when it runs
## out. Anyone aboard a cut-off piece stays inside a while, then suits up
## and jetpacks for an airlock. True when that took their turn.
static func survive(sim: CrewSim, c: CrewMember, delta: float) -> bool:
	if c.eva:
		c.air -= delta
		if c.air <= 0.0:
			sim.kill(c)
			return true
		return false
	var p := sim.state.pieces
	var i := sim.state.design.index_at(Vector2i((c.pos / ShipView.CELL).floor()))
	if i < 0 or not p.drifting(i):
		c.strand = -1.0
		return false
	if c.strand < 0.0:
		sim.drop(c)
		c.order = false
		c.strand = randf_range(BAIL.x, BAIL.y)
	c.strand = maxf(c.strand - delta, 0.0)
	if c.strand <= 0.0 and c.species.eva:  # the rest wait to be towed home
		c.pos = p.xf[i] * c.pos
		c.eva = true
		c.air = AIR_SUIT
		c.strand = -1.0
	return true


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
			c.air = AIR_RIG
			c.stage = 2
		2:
			if fly(c, p.world(t), delta, true):
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
	if a >= 0 and fly(c, sim.state.spot(a), delta, true):
		c.eva = false


## Jetpacks toward `to`: straight up out of the airlock to UP first so
## they clear the hull, then across. `land` drops them back down at the
## end (into an airlock, onto a piece); `high` false keeps them low
## (moving about inside a wreck). True on arrival.
static func fly(c: CrewMember, to: Vector2, delta: float, land := false,
		high := true) -> bool:
	var d := c.pos.distance_to(to)
	if high and d > 0.05 and c.alt < UP:
		c.alt = minf(c.alt + CLIMB * delta, UP)
		return false
	if d > FLY * delta:
		c.face = (to - c.pos) / d
		c.pos += c.face * FLY * delta
		return false
	c.pos = to
	if land and c.alt > 0.0:
		c.alt = maxf(c.alt - CLIMB * delta, 0.0)
		return c.alt <= 0.0
	return true
