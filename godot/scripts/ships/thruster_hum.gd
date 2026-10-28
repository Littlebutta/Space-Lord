class_name ThrusterHum
extends AudioStreamPlayer3D
## Placeholder engine sound: a low rumble of filtered noise whose volume
## and pitch follow the ship's thrusters as they spool up and down.
## Add as a child of a ShipBody.

const RATE := 22050.0
const QUIET := -40.0  # dB when idle
const LOUD := -8.0  # dB at full burn

var _gen: AudioStreamGeneratorPlayback
var _low := 0.0  # filter state: smooths white noise into a rumble
var _level := 0.0


func _ready() -> void:
	var s := AudioStreamGenerator.new()
	s.mix_rate = RATE
	s.buffer_length = 0.15
	stream = s
	unit_size = 30.0
	volume_db = QUIET
	play()
	_gen = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	var b := get_parent() as ShipBody
	if b == null or b.helm == null or _gen == null:
		return
	var sum := 0.0
	for k in b.helm.throttle.values():
		sum += k
	_level = clampf(sum / 2.0, 0.0, 1.0)  # two engines at full = full roar
	volume_db = lerpf(QUIET, LOUD, sqrt(_level))
	pitch_scale = 0.8 + 0.4 * _level
	var cut := 0.04 + 0.06 * _level  # brighter as it opens up
	for k in _gen.get_frames_available():
		_low += (randf_range(-1.0, 1.0) - _low) * cut
		_gen.push_frame(Vector2(_low, _low) * 3.0)
