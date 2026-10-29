class_name Sfx
extends RefCounted
## Positional sound effects. Clips live in res://assets/audio (built and
## loudness-matched by art/tools/build_sounds.py); each is played by a
## short-lived AudioStreamPlayer3D so distance from the camera sets how
## loud it is.

const DIR := "res://assets/audio/"

static var _cache := {}


static func stream(clip: StringName, loop := false) -> AudioStream:
	var key := String(clip) + ("~" if loop else "")
	if not _cache.has(key):
		var path := DIR + String(clip) + ".ogg"
		var s := load(path) as AudioStreamOggVorbis if ResourceLoader.exists(path) else null
		if s and loop:
			s = s.duplicate()
			s.loop = true
		_cache[key] = s
	return _cache[key]


## Plays `clip` once at world point `at`, a little varied in pitch.
static func play(parent: Node, clip: StringName, at: Vector3, db := 0.0,
		reach := 60.0) -> void:
	var p := player(clip, db, reach)
	if p == null:
		return
	p.pitch_scale = randf_range(0.92, 1.08)
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.global_position = at
	p.play()


## A 3D player for `clip`, not yet in the tree; loops when asked.
static func player(clip: StringName, db := 0.0, reach := 60.0,
		loop := false) -> AudioStreamPlayer3D:
	var s := stream(clip, loop)
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = db
	p.unit_size = 8.0
	p.max_distance = reach
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	return p


## Plays `clip` once, not placed in the world (menus, the builder, orders).
static func flat(clip: StringName, db := 0.0) -> void:
	var s := stream(clip)
	var tree := Engine.get_main_loop() as SceneTree
	if s == null or tree == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = randf_range(0.95, 1.05)
	p.finished.connect(p.queue_free)
	tree.root.add_child(p)
	p.play()
