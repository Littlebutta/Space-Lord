class_name CrewMember
extends RefCounted
## One crew member: where they are, what they're doing and how much
## they want each job type (1 = first choice ... 4 = last, 0 = never).

const DEFAULT := {&"operate": 2, &"haul": 3, &"repair": 2, &"eva": 3}

var name := ""
var species: CrewSpecies
var pos := Vector2.ZERO  # ship-local metres (x, z)
var y := 0.0  # deck height under them, eased for drawing
var path := PackedVector2Array()
var job: CrewJob
var stage := 0  # step within the job
var timer := 0.0
var cargo := 0.0  # haul: units in hand
var source := -1  # haul: storage module loaded from
var eva := false  # outside the hull; pos is in the ship's frame
var hidden := false  # riding in a breaching pod: not drawn, not in the way
var air := 0.0  # seconds of air left in their suit while outside
var alt := 0.0  # outside: metres above the deck (see CrewEva.fly)
var face := Vector2.UP  # outside: which way they last flew, ship frame
var order := false  # following a player order; the job board leaves them be
var selected := false
var strand := -1.0  # aboard a cut-off piece: seconds until they bail out
var priority := {}


func _init(n: String, sp: CrewSpecies = null) -> void:
	name = n
	species = sp if sp else CrewSpecies.by_id(&"human")
	for t in CrewJob.TYPES:
		priority[t] = DEFAULT.get(t, 3)


## How much they want job type t; 0 if their species can't do it.
func pref(t: StringName) -> int:
	return priority.get(t, 0) if species.can(t) else 0


## Cycles a priority 1 -> 2 -> 3 -> 4 -> off -> 1.
static func next_pref(p: int) -> int:
	return (p + 1) % 5


func status() -> String:
	var s := job.label if job else ("Stranded" if strand >= 0.0 else "Idle")
	return s + (" · air %ds" % ceili(air) if eva else "")


## At the end of their route (or never given one).
func arrived() -> bool:
	return path.is_empty()
