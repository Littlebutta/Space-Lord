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
@export var firepower := 0.0  # damage per second, needs ammo upkeep
@export var storage := {}  # resource id -> capacity it adds
@export var upkeep := {}  # resource id -> units used per game hour
## Side thrust leaves from when unturned, e.g. (0, 1) = out the back.
## Thrusters need a clear lane there; see ShipRules.
@export var exhaust := Vector2i.ZERO
@export var needs_near := {}  # module id or category -> max cell gap
@export var salvage := {}  # raw materials recovered when scrapped
@export_group("Crew access")
## Areas crew can't walk through (tanks, engines, guns), as rects in
## cell units of the unturned footprint. Every theme's model must keep
## its equipment inside them so nobody walks through anything.
@export var blocked: Array[Rect2] = []
## Spots crew stand at to work this part, in the same cell units. Empty
## means anywhere near the middle.
@export var access := PackedVector2Array()
@export var model: PackedScene  # Blender .glb scene, optional
