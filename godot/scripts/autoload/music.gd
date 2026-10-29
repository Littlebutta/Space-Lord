extends Node
## Background music now and then: a random track from res://assets/music
## (any .ogg/.mp3/.wav dropped there), then a long stretch of silence so
## space stays quiet between songs.

const DIR := "res://assets/music/"
const DB := -14.0
const GAP := Vector2(90.0, 240.0)  # seconds of silence between tracks
const FIRST := Vector2(20.0, 60.0)  # before the first one

var _player := AudioStreamPlayer.new()
var _tracks: PackedStringArray = []
var _last := ""


func _ready() -> void:
	for f in ResourceLoader.list_directory(DIR):
		if f.get_extension().to_lower() in ["ogg", "mp3", "wav"]:
			_tracks.append(DIR + f)
	if _tracks.is_empty():
		return
	_player.volume_db = DB
	add_child(_player)
	_player.finished.connect(_wait.bind(GAP))
	_wait(FIRST)


func _wait(span: Vector2) -> void:
	get_tree().create_timer(randf_range(span.x, span.y)).timeout.connect(_next)


func _next() -> void:
	var pick := _tracks[randi() % _tracks.size()]
	if _tracks.size() > 1 and pick == _last:
		pick = _tracks[(_tracks.find(pick) + 1) % _tracks.size()]
	_last = pick
	var s := load(pick) as AudioStream
	if s == null:
		_wait(GAP)
		return
	if "loop" in s:
		s.set("loop", false)
	_player.stream = s
	_player.play()
