class_name GatePainter
extends RefCounted
## Draws gates onto a CanvasItem. Geometry follows GateRules exactly, so the segment that lights up
## at the contact notch is the segment the simulation will test. Reverse fields are drawn by mapping
## coordinates (not flipping the canvas) so shape markers stay upright.

const CENTER_X: float = 240.0
const SEGMENT: float = 65.0
const FLIP_AXIS: float = 1030.0
const RING_RADIUS: float = 90.0

var canvas: CanvasItem
var time: float = 0.0
var contact: int = 0
var orb_color: int = 0
var alpha: float = 1.0
var clock: float = 0.0
var labels: bool = true
var calm: bool = false
var flip: bool = false


func map(point: Vector2) -> Vector2:
	return Vector2(point.x, FLIP_AXIS - point.y) if flip else point


func gate(stage: Dictionary, y: float) -> void:
	match str(stage.kind):
		"ring", "reverse":
			_ring(stage, y)
		"pendulum":
			_pendulum(stage, y)
		"pulse":
			_pulse(stage, y)
		"chain":
			_band(stage, y, 0, contact > 0)
			_band(stage, y - 54.0, 1, false)
		_:
			_band(stage, y, 0, false)
	if str(stage.kind) == "switch":
		_switch_marker(int(stage.color), y)


## Standalone decorative ring (home screen hero).
func hero(center: Vector2, spin: float) -> void:
	for index: int in range(4):
		var start: float = spin + index * PI / 2.0
		var tint: Color = RushSkin.COLORS[index]
		_arc(center, Vector2(111.0, 32.0), Vector2(start + 0.05, start + PI / 2.0 - 0.05), Color(tint, 0.1))
		_arc(center, Vector2(111.0, 22.0), Vector2(start + 0.05, start + PI / 2.0 - 0.05), tint)
		_arc(center, Vector2(106.0, 2.0), Vector2(start + 0.12, start + PI / 2.0 - 0.12), Color(1, 1, 1, 0.28))
		_marker(center + Vector2.from_angle(start + PI / 4.0) * 111.0, index, RushSkin.BG)


func notch(point: Vector2, lit: bool, tint: Color) -> void:
	var base: Vector2 = point + Vector2(0, 22)
	var color: Color = tint if lit else RushSkin.MUTED
	var triangle: PackedVector2Array = PackedVector2Array(
		[map(base), map(base + Vector2(-6, 9)), map(base + Vector2(6, 9))]
	)
	canvas.draw_colored_polygon(triangle, Color(color, color.a * alpha))
	if lit and not calm:
		var pulse: float = 0.5 + 0.5 * sin(clock * 8.0)
		_ring_at(point, 15.0 + 4.0 * pulse, Color(tint, 0.5 * alpha), 2.0)


func _ring(stage: Dictionary, y: float) -> void:
	var center: Vector2 = Vector2(CENTER_X, y - RING_RADIUS)
	var angle: float = time * float(stage.speed) + float(stage.phase)
	var live: int = GateRules.sample(stage, time, contact)
	var locked: bool = live == orb_color
	_arc(center, Vector2(RING_RADIUS + 20.0, 1.5), Vector2(0.0, TAU), Color(RushSkin.LINE, 0.9))
	for tick: int in range(24):
		var a: float = angle + tick * TAU / 24.0
		var from: Vector2 = center + Vector2.from_angle(a) * (RING_RADIUS + 20.0)
		var to: Vector2 = center + Vector2.from_angle(a) * (RING_RADIUS + (27.0 if tick % 6 == 0 else 23.0))
		_line(from, to, Color(RushSkin.MUTED, 0.35), 1.5)
	for index: int in range(4):
		var start: float = angle + index * PI / 2.0
		var color_index: int = posmod(index + int(stage.offset), 4)
		var tint: Color = RushSkin.COLORS[color_index]
		var span_a: float = start + 0.035
		var span_b: float = start + PI / 2.0 - 0.035
		_arc(center, Vector2(RING_RADIUS, 38.0), Vector2(span_a, span_b), Color(tint, 0.12))
		_arc(center, Vector2(RING_RADIUS, 28.0), Vector2(span_a, span_b), Color(tint, 0.22))
		_arc(center, Vector2(RING_RADIUS, 18.0), Vector2(span_a, span_b), tint)
		_arc(center, Vector2(RING_RADIUS - 3.0, 2.0), Vector2(span_a + 0.05, span_b - 0.05), Color(1, 1, 1, 0.22))
		_marker(center + Vector2.from_angle(start + PI / 4.0) * RING_RADIUS, color_index, RushSkin.BG)
		if color_index == live:
			_arc(center, Vector2(RING_RADIUS, 20.0), Vector2(span_a, span_b), Color(1, 1, 1, 0.5 if locked else 0.18))
	_core(center, live)
	notch(Vector2(CENTER_X, y), locked, RushSkin.COLORS[orb_color])


func _core(center: Vector2, live: int) -> void:
	var tint: Color = RushSkin.COLORS[live]
	_circle(center, 20.0, Color(tint, 0.08))
	_circle(center, 9.0, Color(tint, 0.2))
	_marker(center, live, Color(tint, 0.9))


func _band(stage: Dictionary, y: float, which: int, done: bool) -> void:
	var angle: float = time * float(stage.speed) + float(stage.phase)
	var units: float = _units(stage, angle, which)
	var live: int = posmod(int(floor(units)) + int(stage.offset), 4)
	var locked: bool = which == contact and live == orb_color
	for index: int in range(int(floor(units)) - 4, int(floor(units)) + 5):
		var color_index: int = posmod(index + int(stage.offset), 4)
		var x: float = CENTER_X + (index + 0.5 - units) * SEGMENT
		var depth: float = clampf(1.2 - absf(x - CENTER_X) / 235.0, 0.18, 1.0)
		var tint: Color = RushSkin.COLORS[color_index]
		var weight: float = depth * (0.22 if done else 1.0)
		var a: Vector2 = Vector2(x - 29.0, y)
		var b: Vector2 = Vector2(x + 29.0, y)
		_line(a, b, Color(tint, 0.12 * weight), 34.0)
		_line(a, b, Color(tint, 0.2 * weight), 25.0)
		_capsule(a, b, Color(tint, weight), 16.0)
		_line(a + Vector2(3, -4), b + Vector2(-3, -4), Color(1, 1, 1, 0.22 * weight), 1.6)
		_marker(Vector2(x, y), color_index, Color(RushSkin.BG, weight))
		if index == int(floor(units)) and not done:
			_capsule(a, b, Color(1, 1, 1, 0.5 if locked else 0.16), 18.0)
	if which == 0:
		notch(Vector2(CENTER_X, y), locked, RushSkin.COLORS[orb_color])


func _pendulum(stage: Dictionary, y: float) -> void:
	var angle: float = time * float(stage.speed) + float(stage.phase)
	var anchor: float = CENTER_X + (2.5 - _units(stage, angle, 0)) * SEGMENT
	var pivot: Vector2 = Vector2(CENTER_X, y - 200.0)
	_line(pivot, Vector2(anchor, y - 9.0), Color(RushSkin.MUTED, 0.5), 1.5)
	_circle(pivot, 5.0, Color(RushSkin.MUTED, 0.8))
	_circle(Vector2(anchor, y - 9.0), 4.0, Color(RushSkin.TEXT, 0.9))
	_band(stage, y, 0, false)


func _pulse(stage: Dictionary, y: float) -> void:
	var live: int = GateRules.sample(stage, time)
	var open: bool = GateRules.is_open(stage, time)
	var locked: bool = open and live == orb_color
	var tint: Color = RushSkin.COLORS[live]
	var left: Vector2 = Vector2(60, y)
	var right: Vector2 = Vector2(420, y)
	if open:
		_line(left, right, Color(tint, 0.12), 36.0)
		_line(left, right, Color(tint, 0.22), 26.0)
		_capsule(left, right, tint, 16.0)
		_line(left + Vector2(6, -4), right + Vector2(-6, -4), Color(1, 1, 1, 0.24), 1.6)
		if locked:
			_capsule(left, right, Color(1, 1, 1, 0.34), 18.0)
	else:
		for dash: int in range(14):
			var x: float = 60.0 + dash * 27.0
			_line(Vector2(x, y), Vector2(x + 14.0, y), Color(RushSkin.MUTED, 0.5), 5.0)
		_circle(Vector2(CENTER_X, y), 5.0, Color(RushSkin.MUTED, 0.6))
	_marker(Vector2(CENTER_X, y), live, Color(RushSkin.BG, 1.0 if open else 0.0))
	notch(Vector2(CENTER_X, y), locked, RushSkin.COLORS[orb_color])


func _switch_marker(next_color: int, y: float) -> void:
	var tint: Color = RushSkin.COLORS[next_color]
	var center: Vector2 = Vector2(CENTER_X, y - 52.0)
	_circle(center, 24.0, Color(tint, 0.1))
	var points: PackedVector2Array = PackedVector2Array(
		[
			map(center + Vector2(0, -17)),
			map(center + Vector2(13, 0)),
			map(center + Vector2(0, 17)),
			map(center + Vector2(-13, 0))
		]
	)
	canvas.draw_colored_polygon(points, Color(tint, alpha))
	_marker(center, next_color, Color(RushSkin.BG, alpha))


func _units(stage: Dictionary, angle: float, which: int) -> float:
	match str(stage.kind):
		"pendulum":
			return 2.0 + sin(angle) * float(stage.get("drift", 42.0)) / 20.0
		"chain":
			return (angle + which * 0.26) / (PI / 2.0)
	return 2.0 - sin(angle) * 2.4


func _capsule(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	_line(a, b, color, width)
	_circle(a, width / 2.0, color)
	_circle(b, width / 2.0, color)


func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(map(a), map(b), Color(color, color.a * alpha), width, true)


func _circle(point: Vector2, radius: float, color: Color) -> void:
	canvas.draw_circle(map(point), radius, Color(color, color.a * alpha))


func _ring_at(point: Vector2, radius: float, color: Color, width: float) -> void:
	canvas.draw_arc(map(point), radius, 0.0, TAU, 28, color, width, true)


## shape = (radius, stroke width); span = (start angle, end angle).
func _arc(center: Vector2, shape: Vector2, span: Vector2, color: Color) -> void:
	var steps: int = maxi(8, int(absf(span.y - span.x) / 0.1))
	var tint: Color = Color(color, color.a * alpha)
	if flip:
		canvas.draw_arc(map(center), shape.x, -span.y, -span.x, steps, tint, shape.y, true)
	else:
		canvas.draw_arc(center, shape.x, span.x, span.y, steps, tint, shape.y, true)


func _marker(point: Vector2, index: int, ink: Color) -> void:
	if labels:
		RushSkin.marker(canvas, map(point), index, Color(ink, ink.a * alpha))
