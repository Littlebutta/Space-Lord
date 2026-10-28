class_name CrewOutside
extends RefCounted
## Player orders onto things outside the hull. With crew selected, right
## click an ore chunk to fetch it, a piece of our own ship that broke off
## to bring it back, or a module on a wreck to board it and strip it for
## parts (CrewSalvage). They go out the nearest airlock.

const NEAR := 1.5  # metres from the click ray that still picks a chunk


## What's outside under screen point `at`: {kind, id, wreck?}, or {}.
static func pick(body: ShipBody, cam: Camera3D, at: Vector2) -> Dictionary:
	var from := cam.project_ray_origin(at)
	var dir := cam.project_ray_normal(at)
	var f: MiningField = body.sim.board.field
	if f:
		for id in f.chunks:
			var p: Vector3 = f.chunks[id].node.global_position
			if f.chunks[id].carrier == null and (p - from).cross(dir).length() < NEAR:
				return {kind = &"mine", id = id}
	var i := module_at(body, from, dir)
	if i >= 0 and body.sim.state.pieces.drifting(i):
		return {kind = &"eva", id = i}
	for w in body.get_tree().get_nodes_in_group(&"wrecks"):
		var k := module_at(w, from, dir)
		if k >= 0:
			return {kind = &"salvage", id = k, wreck = w}
	return {}


## Intact module of ship b under the ray, drift included; -1 if none.
static func module_at(b: ShipBody, from: Vector3, dir: Vector3) -> int:
	var inv := b.global_transform.affine_inverse()
	var hit = Plane(Vector3.UP, ShipView.DECK * 0.5).intersects_ray(inv * from, inv.basis * dir)
	if hit == null:
		return -1
	var s := b.sim.state
	for i in s.size():
		var p: Vector2 = s.pieces.xf[i].affine_inverse() * Vector2(hit.x, hit.z)
		if s.hp[i] > 0.0 and Rect2(s.design.rect(i)).has_point(p / ShipView.CELL):
			return i
	return -1


## Sends c out to `what` (from pick). False if they can't get out.
static func order(sim: CrewSim, c: CrewMember, what: Dictionary) -> bool:
	var s := sim.state
	var a := s.airlock(c.pos)
	if c.eva or c.strand >= 0.0 or a < 0 or not sim.nav.connected(c.pos, s.spot(a)):
		return false
	sim.drop(c)
	var key := _key(sim, c, what)
	var j: CrewJob = sim.board.jobs.get(key)
	if j == null:
		j = CrewJob.new()
		j.key = key
		j.type = what.kind
		j.module = a
		j.target = what.id
		j.wreck = what.get("wreck")
		match j.type:
			&"mine": j.res = sim.board.field.res(j.target)
			&"salvage": j.res = CrewSalvage.RES
		j.label = _label(sim, j)
		sim.board.jobs[key] = j
	elif j.worker:
		sim.drop(j.worker)
	j.worker = c
	c.job = j
	c.order = true
	return true


## The job board's own key where it posts the same job, so nobody doubles up.
static func _key(sim: CrewSim, c: CrewMember, what: Dictionary) -> String:
	match what.kind:
		&"mine":
			return "m%d" % what.id
		&"eva":
			return "e%d.%d" % [what.id, sim.state.airlock(sim.state.pieces.world(what.id))]
	return "s%d.%d" % [what.wreck.get_instance_id(), c.get_instance_id()]


static func _label(sim: CrewSim, j: CrewJob) -> String:
	match j.type:
		&"mine":
			return "Spacewalk: fetch ore"
		&"eva":
			return "Spacewalk: bring back %s" % sim.state.module(j.target).display_name
	return "Salvaging %s from the wreck" % j.wreck.sim.state.module(j.target).display_name
