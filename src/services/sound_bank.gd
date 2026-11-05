class_name SoundBank
extends Node
## Original synthesized audio. Everything is rendered once (effects at startup, music notes when the
## world changes) so no synthesis happens while playing; a note is just a cached stream.

const RATE: int = 22050
const SCALE: Array[float] = [1.0, 1.125, 1.25, 1.5, 1.6667, 2.0, 2.25, 2.5]
const PHRASE: Array[float] = [1.0, 1.5, 2.0, 1.25, 1.0, 1.875, 1.5, 1.25]
const BRIGHT: Array = [[1.0, 1.0], [2.0, 0.35], [3.0, 0.15]]
const SOFT: Array = [[1.0, 1.0], [2.0, 0.12]]

var enabled: bool = true:
	set(value):
		enabled = value
		if not value:
			_stop_voices(0, 4)
var music_enabled: bool = true:
	set(value):
		music_enabled = value
		if not value:
			_stop_voices(4, 6)
var haptics: bool = true
var suspended: bool = false
var world: int = 1:
	set(value):
		world = value
		if is_inside_tree():
			_warm_music()
var _voices: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}
var _notes: Dictionary = {}
var _note_time: float = 0.0
var _note_index: int = 0
var _sfx_turn: int = 0
var _music_turn: int = 0


func _ready() -> void:
	for index: int in range(6):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_sounds["tap"] = _stream(_samples(430.0, SOFT, 0.075, 0.55), 0.7)
	_sounds["contact"] = _stream(_samples(700.0, BRIGHT, 0.12, 0.0), 0.75)
	_sounds["fail"] = _stream(_samples(200.0, [[1.0, 1.0], [0.5, 0.7], [2.0, 0.25]], 0.34, -0.62), 0.9)
	for step: int in range(SCALE.size()):
		_sounds["clear%d" % step] = _stream(_chime(392.0 * SCALE[step]), 0.8)
	_sounds["complete"] = _stream(_fanfare(), 0.85)
	_warm_music()


func _process(delta: float) -> void:
	if not music_enabled or suspended:
		return
	_note_time -= delta
	if _note_time > 0.0:
		return
	_note_time = 0.6 + world * 0.035
	var voice: AudioStreamPlayer = _voices[4 + _music_turn % 2]
	_music_turn += 1
	voice.stream = _note(_note_index % PHRASE.size())
	voice.volume_db = -26.0
	voice.play()
	_note_index += 1


func play(cue: String, step: int = 0) -> void:
	if suspended:
		return
	var key: String = "clear%d" % (step % SCALE.size()) if cue == "clear" else cue
	if enabled and _sounds.has(key):
		var voice: AudioStreamPlayer = _voices[_sfx_turn % 4]
		_sfx_turn += 1
		voice.stream = _sounds[key]
		voice.volume_db = -9.0 if cue in ["fail", "complete"] else -12.0
		voice.play()
	if haptics and OS.has_feature("android"):
		Input.vibrate_handheld({"tap": 14, "contact": 20, "clear": 30, "fail": 70, "complete": 90}.get(cue, 25))


func suspend(value: bool) -> void:
	suspended = value
	if value:
		_stop_voices(0, _voices.size())


func _stop_voices(first: int, end: int) -> void:
	for index: int in range(first, mini(end, _voices.size())):
		_voices[index].stop()
		_voices[index].stream = null


func _exit_tree() -> void:
	suspend(true)
	_sounds.clear()
	_notes.clear()
	_voices.clear()


func _warm_music() -> void:
	for step: int in range(PHRASE.size()):
		_note(step)


func _note(step: int) -> AudioStreamWAV:
	var pitch: float = (110.0 + world * 6.0) * PHRASE[step]
	var key: int = int(pitch * 10.0)
	if not _notes.has(key):
		var body: PackedFloat32Array = _samples(pitch, [[1.0, 1.0], [0.5, 0.45], [2.0, 0.12]], 0.9, 0.0)
		_notes[key] = _stream(body, 0.5)
	return _notes[key]


func _chime(frequency: float) -> PackedFloat32Array:
	var low: PackedFloat32Array = _samples(frequency, BRIGHT, 0.26, 0.0)
	var high: PackedFloat32Array = _samples(frequency * 1.5, SOFT, 0.2, 0.0)
	return _mix(low, high, 0.32, int(RATE * 0.045))


func _fanfare() -> PackedFloat32Array:
	var track: PackedFloat32Array = PackedFloat32Array()
	var tones: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	for index: int in range(tones.size()):
		track = _mix(track, _samples(tones[index], BRIGHT, 0.5, 0.0), 1.0, int(RATE * 0.11 * index))
	return track


## Additive synthesis: `partials` is [[harmonic ratio, amplitude], ...]; `sweep` bends pitch by that fraction.
func _samples(freq: float, partials: Array, duration: float, sweep: float) -> PackedFloat32Array:
	var attack: float = clampf(duration * 0.13, 0.005, 0.12)
	var count: int = int(RATE * duration)
	var data: PackedFloat32Array = PackedFloat32Array()
	data.resize(count)
	var phase: float = 0.0
	for index: int in range(count):
		var t: float = float(index) / RATE
		phase += TAU * freq * (1.0 + sweep * t / duration) / RATE
		var envelope: float = minf(t / attack, 1.0) * pow(1.0 - t / duration, 2.2)
		var value: float = 0.0
		for partial: Array in partials:
			value += sin(phase * float(partial[0])) * float(partial[1])
		data[index] = value * envelope
	return data


func _mix(base: PackedFloat32Array, extra: PackedFloat32Array, gain: float, offset: int) -> PackedFloat32Array:
	var length: int = maxi(base.size(), extra.size() + offset)
	var result: PackedFloat32Array = base.duplicate()
	result.resize(length)
	for index: int in range(extra.size()):
		result[index + offset] += extra[index] * gain
	return result


## Normalise to `ceiling` of full scale (never clips) and wrap as 16-bit mono PCM.
func _stream(data: PackedFloat32Array, ceiling: float) -> AudioStreamWAV:
	var peak: float = 0.0001
	for value: float in data:
		peak = maxf(peak, absf(value))
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(data.size() * 2)
	for index: int in range(data.size()):
		bytes.encode_s16(index * 2, int(clampf(data[index] / peak * ceiling, -1.0, 1.0) * 32767.0))
	var sound: AudioStreamWAV = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.data = bytes
	return sound
