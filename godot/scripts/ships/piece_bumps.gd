class_name PieceBumps
extends RefCounted
## Makes loose pieces solid. Every build cell of a loose piece is a ball,
## tested against the ship's own cells (boxes) and other loose pieces'
## balls, all in ship-local metres. Hits push pieces apart and the ship
## shoves them along when it flies into them. Pieces being towed (no
## drift velocity) pass through so crew can always bring them home.

const R := ShipView.CELL * 0.45  # ball radius per cell
const BOUNCE := 0.3
const SPIN_KICK := 0.01
const MAX_SPIN := 0.6

var pieces: ShipPieces
var _solid := {}  # build cell -> true, for the ship's own piece


func _init(p: ShipPieces) -> void:
	pieces = p
	p.changed.connect(_cache)
	_cache()


func _cache() -> void:
	_solid.clear()
	if pieces.main < 0:
		return
	for i in pieces.pieces[pieces.main]:
		var r := pieces.design.rect(i)
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				_solid[Vector2i(x, y)] = true


## The ship moved by `s` (new local from old local): loose pieces and
## crew outside stay where they are in space.
func carry(s: Transform2D, crew: Array[CrewMember]) -> void:
	var p := pieces
	for i in p.xf.size():
		if p.drifting(i):
			p.xf[i] = s * p.xf[i]
			p.vel[i] = s.basis_xform(p.vel[i])
	for c in crew:
		if c.eva:
			c.pos = s * c.pos


## `ship_vel`: the ship's own velocity in its local frame.
func collide(ship_vel: Vector2) -> void:
	var balls := {}
	for k in pieces.pieces.size():
		if k != pieces.main and pieces.vel[pieces.pieces[k][0]] != Vector2.ZERO:
			balls[k] = _balls(k)
	var keys := balls.keys()
	for a in keys.size():
		_hit_ship(keys[a], balls[keys[a]], ship_vel)
		for b in range(a + 1, keys.size()):
			_hit_pair(keys[a], keys[b], balls[keys[a]], balls[keys[b]])


func _balls(k: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pieces.pieces[k]:
		var r := pieces.design.rect(i)
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				out.append(pieces.xf[i] * ((Vector2(x, y) + Vector2(0.5, 0.5)) * ShipView.CELL))
	return out


func _hit_ship(k: int, pts: PackedVector2Array, ship_vel: Vector2) -> void:
	var push := Vector2.ZERO
	var hit := Vector2.ZERO
	var n := 0
	var cell := Vector2.ONE * ShipView.CELL
	for w in pts:
		var g := Vector2i((w / ShipView.CELL).floor())
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var c := g + Vector2i(dx, dy)
				if not _solid.has(c):
					continue
				var lo := Vector2(c) * ShipView.CELL
				var q := w.clamp(lo, lo + cell)
				var l := w.distance_to(q)
				if l >= R:
					continue
				var dir := (w - q) / l if l > 0.001 else (w - lo - cell * 0.5).normalized()
				push += dir * (R - l)
				hit += q
				n += 1
	if n > 0:
		_shove(k, push / n, hit / n, ship_vel)


func _hit_pair(ka: int, kb: int, pa: PackedVector2Array, pb: PackedVector2Array) -> void:
	var push := Vector2.ZERO
	var hit := Vector2.ZERO
	var n := 0
	for a in pa:
		for b in pb:
			var l := a.distance_to(b)
			if l < R * 2.0 and l > 0.001:
				push += (a - b) / l * (R * 2.0 - l)
				hit += (a + b) * 0.5
				n += 1
	if n == 0:
		return
	var va := pieces.vel[pieces.pieces[ka][0]]
	var vb := pieces.vel[pieces.pieces[kb][0]]
	_shove(ka, push / n * 0.5, hit / n, vb)
	_shove(kb, -push / n * 0.5, hit / n, va)


## Moves piece k out by `push` and bounces it off something moving at
## `other`, with a little spin from where it was hit.
func _shove(k: int, push: Vector2, at: Vector2, other: Vector2) -> void:
	var mods := pieces.pieces[k]
	var f := mods[0]
	var nrm := push.normalized()
	var v := pieces.vel[f]
	var s := pieces.spin[f]
	var rel := (v - other).dot(nrm)
	if rel < 0.0:
		var kick := nrm * -rel * (1.0 + BOUNCE)
		v += kick
		var arm := at - pieces.center(mods)
		s = clampf(s + arm.cross(kick) * SPIN_KICK, -MAX_SPIN, MAX_SPIN)
	if v == Vector2.ZERO:
		v = nrm * 0.01  # zero means "being towed"
	var move := Transform2D(0.0, push)
	for i in mods:
		pieces.xf[i] = move * pieces.xf[i]
		pieces.vel[i] = v
		pieces.spin[i] = s
