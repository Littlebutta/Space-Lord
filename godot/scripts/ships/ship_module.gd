class_name ShipModule
extends Resource
## One placeable ship part (Cosmoteer style). Stats live in .tres files
## under res://data/modules so new parts need no code.

@export var id: StringName
@export var display_name := ""
@export var category := "hull"  # palette group: hull, command, engine...
@export var size := Vector2i.ONE  # footprint in grid cells
@export var color := Color(0.6, 0.62, 0.66)  # placeholder until art
@export var mass := 1.0
@export var hp := 100.0
@export var crew := 0  # crew needed to operate it
@export var berths := 0  # crew it can house
@export var thrust := 0.0  # engine push, needs fuel upkeep
@export var firepower := 0.0  # damage per second, needs ammo upkeep
@export var storage := {}  # resource id -> capacity it adds
@export var upkeep := {}  # resource id -> units used per game hour
@export var salvage := {}  # raw materials recovered when scrapped
@export var model: PackedScene  # Blender .glb scene, optional
