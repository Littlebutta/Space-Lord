class_name ShipBody
extends Node3D
## A ship flying in space: its crew (CrewSim), its pieces (HulkView) and
## RTS flight. It turns and burns toward `goal` with whatever engines are
## running (crewed and fuelled) while the bridge is manned. Loose pieces
## and crew outside stay put in space as it moves, and get shoved aside.

const ACCEL := 1.5  # scales running thrust / mass into m/s^2
const TOP := 5.0  # seconds of full burn to reach top speed
const TURN := 0.8  # radians per second with good engines
const ARRIVE := 1.5  # metres from the goal counts as there

var sim: CrewSim
var hulk: HulkView
var bumps: PieceBumps
var at := Transform2D.IDENTITY  # ship-local (x, z) -> world (x, z)
var vel := Vector2.ZERO  # world metres per second
var goal: Variant = null  # world point to fly to, or null


func setup(d: ShipDesign, crew: int) -> void:
	sim = CrewSim.new()
	add_child(sim)
	sim.setup(d, crew)
	hulk = HulkView.new()
	add_child(hulk)
	hulk.bind(sim.state.pieces)
	bumps = PieceBumps.new(sim.state.pieces)
	transform = ShipPieces.to_3d(at)


func _physics_process(delta: float) -> void:
	if sim == null:
		return
	var old := at
	_fly(delta)
	bumps.carry(at.affine_inverse() * old, sim.crew)
	bumps.collide(at.basis_xform_inv(vel))
	transform = ShipPieces.to_3d(at)


## Middle of the ship's own piece, ship-local.
func pivot() -> Vector2:
	var p := sim.state.pieces
	return p.center(p.pieces[p.main]) if p.main >= 0 else Vector2.ZERO


## World point of a ship-local one.
func world(local: Vector2) -> Vector2:
	return at * local


## Acceleration the running engines give, 0 if the bridge isn't manned.
func power() -> float:
	var s := sim.state
	var p := s.pieces
	if p.main < 0:
		return 0.0
	var thrust := 0.0
	var mass := 0.0
	var command := false
	for i in p.pieces[p.main]:
		mass += s.module(i).mass
		if s.is_running(i):
			thrust += s.module(i).thrust
			command = command or s.module(i).category == "command"
	return thrust / mass * ACCEL if command and mass > 0.0 else 0.0


func _fly(delta: float) -> void:
	var a := power()
	var want := Vector2.ZERO
	if goal != null and a > 0.0:
		var c := pivot()
		var to: Vector2 = goal - at * c
		if to.length() < ARRIVE:
			goal = null
		else:
			var fwd := -at.y.normalized()  # the bow points up the grid (-z)
			var ang := fwd.angle_to(to)
			var turn := clampf(ang, -1.0, 1.0) * TURN * minf(a, 1.0) * delta
			at = at * Transform2D(turn, c - c.rotated(turn))
			var speed := minf(a * TOP, sqrt(2.0 * a * to.length()))
			want = fwd * speed * maxf(cos(ang), 0.0)
	if a > 0.0:
		vel = vel.move_toward(want, a * delta)
	at.origin += vel * delta
