class_name Effects
extends RefCounted
## Transient visual feedback: sparks, shockwaves, shatter shards, the orb trail and screen shake.
## Everything is capped so a burst can never cost more than a bounded number of draw calls.

const MAX_SPARKS: int = 90
const MAX_RINGS: int = 6
const MAX_SHARDS: int = 28
const TRAIL_LENGTH: int = 14
const LOW_SPARKS: int = 30
const LOW_SHARDS: int = 14
const LOW_RINGS: int = 3
const LOW_TRAIL: int = 8
const SLOW_FRAMES: int = 30
const RECOVERY_FRAMES: int = 120

var low_quality: bool = false
var calm: bool = false:
	set(value):
		calm = value
		if value:
			clear()
var _sparks: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _shards: Array[Dictionary] = []
var _trail: Array[Vector2] = []
var _shake: float = 0.0
var _shake_clock: float = 0.0
var _slow_frames: int = 0
var _fast_frames: int = 0


func observe_frame(delta: float) -> void:
	_slow_frames = _slow_frames + 1 if delta > 0.022 else 0
	_fast_frames = _fast_frames + 1 if delta < 0.020 else 0
	if not low_quality and _slow_frames >= SLOW_FRAMES:
		low_quality = true
		_trim()
	elif low_quality and _fast_frames >= RECOVERY_FRAMES:
		low_quality = false


func clear() -> void:
	_sparks.clear()
	_rings.clear()
	_shards.clear()
	_trail.clear()
	_shake = 0.0


func update(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 2.6)
	_shake_clock += delta
	_age(_sparks, delta, true)
	_age(_shards, delta, true)
	_age(_rings, delta, false)
	_trim()


func offset() -> Vector2:
	if _shake <= 0.001 or calm:
		return Vector2.ZERO
	var strength: float = _shake * _shake * 9.0
	return Vector2(sin(_shake_clock * 83.0), cos(_shake_clock * 67.0)) * strength


func shake(amount: float) -> void:
	if calm:
		return
	_shake = maxf(_shake, clampf(amount, 0.0, 1.0))


func burst(point: Vector2, tint: Color, count: int = 18, speed: float = 150.0) -> void:
	if calm:
		return
	for index: int in range(count):
		var angle: float = TAU * index / count + sin(index * 12.9898) * 0.35
		var scale: float = 0.45 + 0.55 * absf(sin(index * 78.233))
		_sparks.append(
			{
				"p": point,
				"v": Vector2.from_angle(angle) * speed * scale,
				"life": 0.55 + 0.25 * scale,
				"max": 0.8,
				"c": tint,
				"s": 1.6 + 1.8 * scale
			}
		)
	var limit: int = LOW_SPARKS if low_quality else MAX_SPARKS
	if _sparks.size() > limit:
		_sparks = _sparks.slice(_sparks.size() - limit)


func ring(point: Vector2, tint: Color, reach: float = 90.0, seconds: float = 0.5) -> void:
	if calm:
		return
	_rings.append({"p": point, "life": seconds, "max": seconds, "c": tint, "r": reach})
	if _rings.size() > (LOW_RINGS if low_quality else MAX_RINGS):
		_rings.pop_front()


func shatter(point: Vector2, tint: Color) -> void:
	if calm:
		return
	for index: int in range(14):
		var angle: float = TAU * index / 14.0 + 0.3
		var power: float = 90.0 + 130.0 * absf(sin(index * 37.719))
		_shards.append(
			{
				"p": point,
				"v": Vector2.from_angle(angle) * power,
				"life": 0.9,
				"max": 0.9,
				"c": tint,
				"s": 4.5 + 4.0 * absf(sin(index * 5.1)),
				"a": angle,
				"w": (index % 2 * 2 - 1) * 7.0
			}
		)
	var limit: int = LOW_SHARDS if low_quality else MAX_SHARDS
	if _shards.size() > limit:
		_shards = _shards.slice(_shards.size() - limit)


func follow(point: Vector2, flying: bool) -> void:
	if calm or not flying:
		if _trail.size() > 0:
			_trail = _trail.slice(1)
		return
	_trail.append(point)
	if _trail.size() > (LOW_TRAIL if low_quality else TRAIL_LENGTH):
		_trail.pop_front()


func _trim() -> void:
	var sparks: int = LOW_SPARKS if low_quality else MAX_SPARKS
	var shards: int = LOW_SHARDS if low_quality else MAX_SHARDS
	var rings: int = LOW_RINGS if low_quality else MAX_RINGS
	var trail: int = LOW_TRAIL if low_quality else TRAIL_LENGTH
	if _sparks.size() > sparks:
		_sparks = _sparks.slice(_sparks.size() - sparks)
	if _shards.size() > shards:
		_shards = _shards.slice(_shards.size() - shards)
	if _rings.size() > rings:
		_rings = _rings.slice(_rings.size() - rings)
	if _trail.size() > trail:
		_trail = _trail.slice(_trail.size() - trail)


func draw(canvas: CanvasItem) -> void:
	for index: int in range(_trail.size() - 1):
		var fade: float = float(index) / TRAIL_LENGTH
		canvas.draw_line(_trail[index], _trail[index + 1], Color(1, 1, 1, 0.34 * fade), 2.0 + 7.0 * fade, true)
	for item: Dictionary in _rings:
		var t: float = 1.0 - float(item.life) / float(item.max)
		var ease_out: float = 1.0 - pow(1.0 - t, 3.0)
		var tint: Color = item.c
		canvas.draw_arc(
			item.p,
			float(item.r) * ease_out + 6.0,
			0,
			TAU,
			40,
			Color(tint, 0.7 * (1.0 - t)),
			4.0 * (1.0 - t) + 1.0,
			true
		)
	for item: Dictionary in _sparks:
		var fade: float = clampf(float(item.life) / float(item.max), 0.0, 1.0)
		var tint: Color = item.c
		var tail: Vector2 = item.p - item.v * 0.035
		canvas.draw_line(tail, item.p, Color(tint, fade), float(item.s) * (0.4 + fade * 0.6), true)
	for item: Dictionary in _shards:
		var fade: float = clampf(float(item.life) / float(item.max), 0.0, 1.0)
		var tint: Color = item.c
		var size: float = float(item.s)
		var turn: float = float(item.a)
		var tri: PackedVector2Array = PackedVector2Array()
		for corner: int in range(3):
			tri.append(item.p + Vector2.from_angle(turn + corner * TAU / 3.0) * size)
		canvas.draw_colored_polygon(tri, Color(tint, fade))


func _age(items: Array[Dictionary], delta: float, moving: bool) -> void:
	var index: int = items.size() - 1
	while index >= 0:
		var item: Dictionary = items[index]
		item.life = float(item.life) - delta
		if float(item.life) <= 0.0:
			items.remove_at(index)
		elif moving:
			item.v = item.v * (1.0 - minf(delta * 2.2, 0.9))
			item.p = item.p + item.v * delta
			if item.has("a"):
				item.a = float(item.a) + float(item.w) * delta
		index -= 1
