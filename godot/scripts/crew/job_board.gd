class_name JobBoard
extends RefCounted
## Works out what the ship needs (staffing, supplies, repairs) and hands
## each job to the free crew member who wants it most, nearest first.
## A station with nothing to run on frees its operators to go haul.

const HAUL_BELOW := 0.6  # restock once on-hand supply drops under this share

var state: ShipState
var nav: ShipNav
var jobs := {}  # key -> CrewJob
var field: MiningField  # asteroids to mine here, if any


func _init(s: ShipState, n: ShipNav) -> void:
	state = s
	nav = n


func refresh() -> void:
	var want := {}
	for i in state.size():
		var m := state.module(i)
		if state.hp[i] > 0.0 and state.pieces.powered(i) and state.supplied(i):
			for s in m.crew:
				want["o%d.%d" % [i, s]] = [&"operate", i, "", s]
		for res in m.upkeep:
			var low := state.room(i, res) > state.buffer(i, res) * (1.0 - HAUL_BELOW)
			if low and state.storage.get_amount(res) > 0.0:
				want["h%d.%s" % [i, res]] = [&"haul", i, res, 0]
		if state.repairable(i):
			want["r%d" % i] = [&"repair", i, "", 0]
	_want_eva(want)
	CrewMining.want(self, want)
	for k in jobs.keys():
		var j: CrewJob = jobs[k]
		if not want.has(k) and (j.worker == null or j.type == &"operate"):
			j.done = true
			jobs.erase(k)
	for k in want:
		if not jobs.has(k):
			jobs[k] = _make(k, want[k])


## Spacewalks: one per drifting piece, and one per wrecked module in
## the hull's edge, while an airlock is up and storage covers the cost.
func _want_eva(want: Dictionary) -> void:
	var p := state.pieces
	for k in p.pieces.size():
		if k != p.main:
			_eva(want, p.pieces[k][0])
	for i in state.size():
		var gap = p.gap(i) if state.hp[i] <= 0.0 else null
		if gap and gap.size() == 1:
			_eva(want, i)


func _eva(want: Dictionary, t: int) -> void:
	var a := state.airlock(state.pieces.world(t))
	if a >= 0 and state.can_pay(state.reattach_cost(t)):
		want["e%d.%d" % [t, a]] = [&"eva", a, "", 0, t]


## An unclaimed job on module i, station work first; null if none.
func open_job(i: int) -> CrewJob:
	var best: CrewJob = null
	for j: CrewJob in jobs.values():
		if j.module == i and j.worker == null and (best == null or j.type == &"operate"):
			best = j
	return best


## Job finished: off the board (it comes back if still needed).
func finish(j: CrewJob) -> void:
	j.done = true
	jobs.erase(j.key)


## Gives idle crew the best open job. Crew at a station only leave it
## for a job they rank strictly higher; one-off jobs run to the end.
func assign(crew: Array[CrewMember]) -> void:
	for c in crew:
		if c.eva or c.strand >= 0.0 or c.order or c.job and c.job.type != &"operate":
			continue
		var cur := c.pref(c.job.type) if c.job else 99
		var best: CrewJob = null
		var best_p := cur
		var best_d := INF
		for j: CrewJob in jobs.values():
			var p := c.pref(j.type)
			if j.worker or p <= 0 or p > best_p or (c.job and p >= cur):
				continue
			if j.type == &"mine" and not CrewMining.in_reach(self, c, j.target, j.module):
				continue
			var at := state.spot(j.module)
			if not nav.connected(c.pos, at):
				continue
			var d := c.pos.distance_squared_to(at)
			if p < best_p or d < best_d:
				best = j
				best_p = p
				best_d = d
		if best:
			if c.job:
				c.job.worker = null
			c.job = best
			c.stage = 0
			best.worker = c


func _make(key: String, w: Array) -> CrewJob:
	var j := CrewJob.new()
	j.key = key
	j.type = w[0]
	j.module = w[1]
	j.res = w[2]
	j.slot = w[3]
	j.target = w[4] if w.size() > 4 else -1
	var n := state.module(j.module).display_name
	match j.type:
		&"operate": j.label = "Operating %s" % n
		&"haul": j.label = "Hauling %s to %s" % [j.res, n]
		&"repair": j.label = "Repairing %s" % n
		&"eva": j.label = "Spacewalk: bring back %s" \
				% state.module(j.target).display_name
		&"mine": j.label = "Spacewalk: fetch %s" % j.res
	return j
