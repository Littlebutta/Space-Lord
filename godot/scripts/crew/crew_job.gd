class_name CrewJob
extends RefCounted
## One thing the ship needs a crew member for. A new job type goes in
## TYPES (the priority panel picks it up), JobBoard and CrewSim._work.

const TYPES: Array[StringName] = [&"operate", &"haul", &"repair", &"eva", &"mine"]
const COLORS := {
	&"operate": Color(0.35, 0.65, 1.0),
	&"haul": Color(1.0, 0.75, 0.25),
	&"repair": Color(0.45, 1.0, 0.45),
	&"eva": Color(1.0, 0.45, 0.85),
	&"mine": Color(1.0, 0.55, 0.15),
	&"salvage": Color(0.6, 0.9, 1.0),  # player orders only, not in TYPES
	&"": Color(0.8, 0.8, 0.8),
}

var key := ""  # unique id on the JobBoard
var type: StringName
var module := -1  # module the job is for (eva: the airlock to use)
var target := -1  # eva: module to bring back; mine: ore chunk id; salvage: wreck module
var wreck: ShipBody  # salvage: the derelict to strip
var res := ""  # haul: what to bring
var slot := 0  # operate: which seat
var label := ""  # shown in the crew panel
var worker: CrewMember
var done := false  # cancelled; the worker should drop it
