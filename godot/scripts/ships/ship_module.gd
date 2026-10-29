class_name ShipModule
extends Resource
## One placeable ship part (Cosmoteer style). Stats live in .tres files
## under res://data/modules so new parts need no code.

@export var id: StringName
@export var display_name := ""
@export var category := "hull"  # palette group: hull, command, engine...
@export var size := Vector2i.ONE  # footprint in grid cells
## Footprint shape in cell units (0..size), e.g. a triangle for slopes.
## Empty means the full rectangle.
@export var outline := PackedVector2Array()
@export var color := Color(0.6, 0.62, 0.66)  # placeholder until art
@export var mass := 1.0
@export var hp := 100.0
@export var crew := 0  # crew needed to operate it
@export var berths := 0  # crew it can house
@export var thrust := 0.0  # engine push, needs fuel upkeep
## Ion drive: power used per second while firing instead of fuel.
@export var drive_power := 0.0
## Seconds an engine can fire with nobody at it before crew must take over.
@export var auto_time := 0.0
@export var firepower := 0.0  # damage per second, needs ammo upkeep
@export var reach := 0.0  # gun range in metres; 0 = ShipGuns.RANGE
## Ore a mining laser cuts loose per second from a targeted asteroid.
@export var mining := 0.0
## Top-mounted turret: its model's Head swings round to aim anywhere.
@export var swivel := false
@export_group("Power")
@export var power_out := 0.0  # power made per second while running
@export var power_cap := 0.0  # power it can store (capacitors, buffers)
## Power each shot draws from the grid (lasers); 0 means it uses ammo.
@export var shot_power := 0.0
@export_group("")
@export var storage := {}  # resource id -> capacity it adds
@export var upkeep := {}  # resource id -> units used per game hour
## Side thrust leaves from when unturned, e.g. (0, 1) = out the back.
## Thrusters need a clear lane there; see ShipRules.
@export var exhaust := Vector2i.ZERO
@export var needs_near := {}  # module id or category -> max cell gap
@export var salvage := {}  # raw materials recovered when scrapped
## What it's built from: iron, copper, silicon, gold (see Materials).
@export var materials := {}
## Resources to rebuild it from wreckage in the field; empty means its
## mass in parts. See ShipState.rebuild_cost.
@export var rebuild := {}
@export var airlock := false  # crew can go outside (EVA) from here
## Onboard shipyard: lets the ship refit and do major repairs in space.
@export var shipdock := false
## Repair bay: crew fix modules from inside twice as fast, using parts,
## and can do major repairs without a shipyard.
@export var workshop := false
## Bolted on outside the hull (wings, fins, antennas): no deck under it,
## not walkable (set `blocked` to the whole footprint), no hull shell.
@export var exterior := false
@export var height := 0.0  # placeholder height override; 0 = by category
@export var taper := 0.0  # placeholder top shrink, e.g. for fins
@export_group("Crew access")
## Areas crew can't walk through (tanks, engines, guns), as rects in
## cell units of the unturned footprint. Every theme's model must keep
## its equipment inside them so nobody walks through anything.
@export var blocked: Array[Rect2] = []
## Spots crew stand at to work this part, in the same cell units. Empty
## means anywhere near the middle.
@export var access := PackedVector2Array()
@export var model: PackedScene  # Blender .glb scene, optional
## Bigger tiers borrow a smaller part's model, scaled to fit, until
## they get their own: the id of the part to borrow.
@export var look := &""
## Shows in the builder's parts list (cosmetic bits are placed by code).
@export var buildable := true
## Cargo hold: lets crew bring loose ore and salvage aboard.
@export var hold := false
## Teleporter pad: crew hop between pads, even onto drifted pieces.
@export var teleporter := false
## Breaching pod bay: crew it launches in a pod to board a dead ship.
@export var breach := 0
