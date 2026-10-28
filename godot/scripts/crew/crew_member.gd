class_name CrewMember
extends RefCounted
## One crew member: where they are, what they're doing and how much
## they want each job type (1 = first choice ... 4 = last, 0 = never).

const DEFAULT := {&"operate": 2, &"haul": 3, &"repair": 2, &"eva": 3}

var name := ""
var pos := Vector2.ZERO  # ship-local metres (x, z)
var y := 0.0  # deck height under them, eased for drawing
var path := PackedVector2Array()
var job: CrewJob
var stage := 0  # step within the job
var timer := 0.0
var cargo := 0.0  # haul: units in hand
var source := -1  # haul: storage module loaded from
var eva := false  # outside the hull; pos is in the ship's frame
var priority := {}


func _init(n: String) -> void:
	name = n
	for t in CrewJob.TYPES:
		priority[t] = DEFAULT.get(t, 3)


func pref(t: StringName) -> int:
	return priority.get(t, 0)


## Cycles a priority 1 -> 2 -> 3 -> 4 -> off -> 1.
static func next_pref(p: int) -> int:
	return (p + 1) % 5


func status() -> String:
	return job.label if job else "Idle"


## At the end of their route (or never given one).
func arrived() -> bool:
	return path.is_empty()
