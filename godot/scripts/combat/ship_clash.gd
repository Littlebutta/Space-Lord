class_name ShipClash
extends RefCounted
## Ships bump into each other. Modules are circles; where two ships'
## pieces overlap they are pushed apart and bounce. A real knock (closing
## faster than SAFE) damages the touching module of each, split by mass:
## the heavier ship takes the smaller share.

const BOUNCE := 0.3  # how much closing speed comes back as bounce
const SAFE := 0.8  # m/s closing speed that just nudges
const HARM := 12.0  # damage per m/s of closing speed, shared out


static func resolve(a: ShipBody, b: ShipBody) -> void:
	var hit := _contact(a, b)
	if hit.is_empty():
		return
	# Push along centre to centre (b -> a): steadier than one module pair.
	var n := (a.world(a.pivot()) - b.world(b.pivot())).normalized()
	if n == Vector2.ZERO:
		n = hit[2]
	var ma := a.helm.mass
	var mb := b.helm.mass
	var push: float = hit[3]  # overlap, shared so the lighter moves more
	a.at.origin += n * push * mb / (ma + mb)
	b.at.origin -= n * push * ma / (ma + mb)
	var closing := (a.vel - b.vel).dot(n)
	if closing >= 0.0:
		return  # already parting
	var j := -(1.0 + BOUNCE) * closing / (1.0 / ma + 1.0 / mb)
	a.vel += n * j / ma
	b.vel -= n * j / mb
	if -closing > SAFE:
		var at := a.world(a.sim.state.pieces.world(hit[0]))
		Sfx.play(a, &"ship_bump", Vector3(at.x, 1.0, at.y), minf(-closing * 2.0 - 6.0, 4.0), 80.0)
		var dmg := HARM * -closing
		a.sim.state.damage(hit[0], dmg * mb / (ma + mb))
		b.sim.state.damage(hit[1], dmg * ma / (ma + mb))


## The deepest overlap between the two ships' own pieces:
## [module of a, module of b, normal b->a, overlap metres], or [].
static func _contact(a: ShipBody, b: ShipBody) -> Array:
	var best := []
	var deep := 0.0
	var bs := _circles(b)
	for ca in _circles(a):
		for cb in bs:
			var d: Vector2 = ca[1] - cb[1]
			var over: float = ca[2] + cb[2] - d.length()
			if over > deep:
				deep = over
				best = [ca[0], cb[0], d.normalized() if d != Vector2.ZERO else Vector2.UP, over]
	return best


## [module, world centre, radius] for each intact module of the main piece.
static func _circles(s: ShipBody) -> Array:
	var st := s.sim.state
	var p := st.pieces
	var out := []
	if p.main < 0:
		return out
	for i in p.pieces[p.main]:
		if st.hp[i] > 0.0:
			var r := Vector2(st.design.rect(i).size).length() * ShipView.CELL * 0.35
			out.append([i, s.world(p.world(i)), r])
	return out
