class_name ShipPieces
extends RefCounted
## Splits a damaged ship into pieces: modules still joined through intact
## neighbours that sit where they were built. The piece with a bridge is
## the ship; anything cut off loses power and slowly drifts away until
## crew tow it back (see CrewEva). Drift is a Transform2D per module in
## ship-local metres (x, z), so a piece that splits again keeps its place.

signal changed

const DRIFT := 0.35  # metres per second a loose piece moves away
const SPIN := 0.03  # radians per second it tumbles
const DAMP := 0.01  # drift dies off, so a piece coasts ~35 m and stops
const TOW := 1.5  # metres per second crew tow a piece home

var design: ShipDesign
var alive := PackedByteArray()  # per module: still intact
var piece_of := PackedInt32Array()  # module -> piece, -1 if destroyed
var pieces: Array[PackedInt32Array] = []
var main := -1  # the piece that is the ship itself
var xf: Array[Transform2D] = []  # per module drift from its built spot
var vel := PackedVector2Array()  # per module drift velocity
var spin := PackedFloat32Array()
var _near: Array[PackedInt32Array] = []  # modules sharing an edge


func _init(d: ShipDesign) -> void:
	design = d
	var n := d.modules.size()
	alive.resize(n)
	alive.fill(1)
	vel.resize(n)
	spin.resize(n)
	xf.resize(n)
	xf.fill(Transform2D.IDENTITY)
	for a in n:
		var near := PackedInt32Array()
		for b in n:
			if a != b and ShipDesign._touch(d.rect(a), d.rect(b)):
				near.append(b)
		_near.append(near)
	update()


## Regroups after a module is destroyed or rebuilt.
func update() -> void:
	piece_of.resize(alive.size())
	piece_of.fill(-1)
	pieces.clear()
	for start in alive.size():
		if alive[start] and piece_of[start] < 0:
			pieces.append(_flood(start, pieces.size()))
	main = _pick_main()
	for p in pieces.size():
		var first := pieces[p][0]
		if p != main and vel[first] == Vector2.ZERO:
			_push_off(p)
	changed.emit()


func _flood(start: int, id: int) -> PackedInt32Array:
	var out := PackedInt32Array([start])
	piece_of[start] = id
	var k := 0
	while k < out.size():
		var a := out[k]
		k += 1
		for b in _near[a]:
			if alive[b] and piece_of[b] < 0 and xf[b].is_equal_approx(xf[a]):
				piece_of[b] = id
				out.append(b)
	return out


## At home first, then has a bridge, then biggest.
func _pick_main() -> int:
	var best := -1
	var best_k := -1
	for p in pieces.size():
		var home := xf[pieces[p][0]].is_equal_approx(Transform2D.IDENTITY)
		var k := int(home) * 100000 + int(has_bridge(p)) * 10000 + pieces[p].size()
		if k > best_k:
			best = p
			best_k = k
	return best


func _push_off(p: int) -> void:
	var from := center(pieces[main]) if main >= 0 else Vector2.ZERO
	var dir := (world(pieces[p][0]) - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	var s := randf_range(-SPIN, SPIN)
	for i in pieces[p]:
		vel[i] = dir * DRIFT
		spin[i] = s


func has_bridge(p: int) -> bool:
	for i in pieces[p]:
		if design.modules[i].category == "command":
			return true
	return false


## Joined to a bridge: the module gets power.
func powered(i: int) -> bool:
	return piece_of[i] >= 0 and has_bridge(piece_of[i])


func drifting(i: int) -> bool:
	return piece_of[i] >= 0 and piece_of[i] != main


## Built centre of module i in ship-local metres.
func home(i: int) -> Vector2:
	var r := design.rect(i)
	return (Vector2(r.position) + Vector2(r.size) * 0.5) * ShipView.CELL


## Where module i's centre is now, after drifting.
func world(i: int) -> Vector2:
	return xf[i] * home(i)


func center(mods: PackedInt32Array) -> Vector2:
	var sum := Vector2.ZERO
	for i in mods:
		sum += world(i)
	return sum / maxf(mods.size(), 1)


func tick(delta: float) -> void:
	for p in pieces.size():
		var mods := pieces[p]
		var f := mods[0]
		if p == main or vel[f] == Vector2.ZERO:
			continue
		var w := center(mods)
		var a := spin[f] * delta
		var step := Transform2D(a, w - w.rotated(a) + vel[f] * delta)
		var k := exp(-DAMP * delta)
		for i in mods:
			xf[i] = step * xf[i]
			vel[i] *= k
			spin[i] *= k


## Tows module i's piece toward its built spot; true once it's there.
func tow(i: int, delta: float) -> bool:
	var mods := pieces[piece_of[i]]
	var t := xf[i]
	var d := t.origin.length() + absf(t.get_rotation()) * 4.0
	var done := d <= TOW * delta
	t = Transform2D.IDENTITY if done else t.interpolate_with(Transform2D.IDENTITY, TOW * delta / d)
	for m in mods:
		xf[m] = t
		vel[m] = Vector2.ZERO
	return done


## Destroyed modules to rebuild so module i joins the ship again: the
## shortest run of wrecked modules between its piece and the ship.
## Empty if it already touches the ship, null if nothing leads there.
func gap(i: int) -> Variant:
	if main < 0 or piece_of[i] == main:
		return null
	var start := pieces[piece_of[i]] if piece_of[i] >= 0 else PackedInt32Array([i])
	var back := {}
	var todo: Array[int] = []
	for s in start:
		back[s] = -1
		todo.append(s)
	var k := 0
	while k < todo.size():
		var a := todo[k]
		k += 1
		if piece_of[a] == main:
			return _trace(back, back[a])
		for b in _near[a]:
			if not back.has(b) and (not alive[b] or piece_of[b] == main):
				back[b] = a
				todo.append(b)
	return null


func _trace(back: Dictionary, at: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	while at >= 0:
		if not alive[at]:
			out.append(at)
		at = back[at]
	return out


## Ship-local 3D transform of module i's drift, for drawing.
static func to_3d(t: Transform2D) -> Transform3D:
	var b := Basis(Vector3(t.x.x, 0, t.x.y), Vector3.UP, Vector3(t.y.x, 0, t.y.y))
	return Transform3D(b, Vector3(t.origin.x, 0, t.origin.y))
