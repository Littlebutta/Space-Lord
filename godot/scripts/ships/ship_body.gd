class_name ShipBody
extends Node3D
## A ship flying in space: its crew (CrewSim), its pieces (HulkView), its
## effects (ShipFx) and RTS flight. It turns and burns toward `goal` with
## whichever thrusters face the right way (see ShipHelm) while the bridge
## is manned. Loose pieces
## and crew outside stay put in space as it moves, and get shoved aside.

const TOP := 9.0  # top cruising speed, m/s
const BRAKE := 0.6  # m/s^2 the approach plans to slow down with
const TURN_RATE := 0.6  # top spin, radians per second
const HOP := 15.0  # closer goals are reached without turning to face them
const ARRIVE := 1.5  # metres from the goal counts as there
const DRAG := 0.03  # a little drag so drifting ships do settle

var sim: CrewSim
var hulk: HulkView
var bumps: PieceBumps
var helm: ShipHelm
var fx: ShipFx
var at := Transform2D.IDENTITY  # ship-local (x, z) -> world (x, z)
var vel := Vector2.ZERO  # world metres per second
var spin := 0.0  # radians per second
var goal: Variant = null  # world point to fly to, or null


func setup(d: ShipDesign, crew: int) -> void:
	sim = CrewSim.new()
	add_child(sim)
	sim.setup(d, crew)
	hulk = HulkView.new()
	add_child(hulk)
	hulk.bind(sim.state.pieces)
	bumps = PieceBumps.new(sim.state.pieces)
	helm = ShipHelm.new(sim.state)
	helm.weigh()
	sim.state.pieces.changed.connect(helm.weigh)
	sim.died.connect(_corpse)
	fx = ShipFx.new()
	add_child(fx)
	fx.bind(hulk, sim.state)
	fx.helm = helm
	fx.sim = sim
	transform = ShipPieces.to_3d(at)


func _physics_process(delta: float) -> void:
	if sim == null:
		return
	var old := at
	_fly(delta)
	bumps.carry(at.affine_inverse() * old, sim.crew)
	bumps.collide(at.basis_xform_inv(vel))
	transform = ShipPieces.to_3d(at)


## Centre of mass of the ship's own piece, ship-local.
func pivot() -> Vector2:
	return helm.com


## World point of a ship-local one.
func world(local: Vector2) -> Vector2:
	return at * local


## Plans a velocity toward the goal, then points the nose where the
## thrusters can deliver the change: at the goal, or (lacking thrusters
## that way) along the burn needed, e.g. flipping round to brake.
func _fly(delta: float) -> void:
	var want := Vector2.ZERO
	var face := -at.y  # the bow points up the grid (-z)
	if goal != null:
		var to: Vector2 = goal - at * helm.com
		if to.length() < ARRIVE and vel.length() < 0.5:
			goal = null
		else:
			want = to.normalized() * minf(TOP, sqrt(2.0 * BRAKE * to.length()))
			face = to if to.length() > HOP else face
	var dv := want - vel
	if dv.length() > 0.3 and not helm.can_push(at.basis_xform_inv(dv)):
		face = dv
	var w_want := clampf((-at.y).angle_to(face) * 1.5, -TURN_RATE, TURN_RATE)
	var turn := clampf((w_want - spin) * 4.0, -1.0, 1.0)
	var out := helm.steer(at.basis_xform_inv(dv), turn, delta)
	vel += at.basis_xform(out[0] / helm.mass) * delta
	spin += out[1] / helm.inertia * delta
	vel *= 1.0 - DRAG * delta
	spin *= 1.0 - DRAG * 4.0 * delta
	var c := helm.com
	var a := spin * delta
	at = at * Transform2D(a, c - c.rotated(a))
	at.origin += vel * delta


## A crew member died: leave their body tumbling in space.
func _corpse(local: Vector3, fling: Vector3, shirt: Color) -> void:
	if get_parent():
		var t := global_transform
		var drift := Vector3(vel.x, 0.0, vel.y)
		CrewCorpse.spawn(get_parent(), t * local, t.basis * fling + drift, shirt)
