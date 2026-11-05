class_name GameCanvas
extends Control
## The playfield. Purely presentational: it reads RunState and never changes it, so the simulation
## that the route audit proves is exactly what the player sees.

const PERCH_Y: float = 657.0
const PASS_SECONDS: float = 0.38
const PASS_DROP: float = 120.0

var run: RunState
var mode: String = "plain"
var reduced_motion: bool = false
var color_labels: bool = true
var guide: bool = false
var large_text: bool = false
var menu_number: int = 1
var fx: Effects = Effects.new()
var _painter: GatePainter = GatePainter.new()
var _clock: float = 0.0
var _pass: Dictionary = {}
var _orb_hidden: bool = false


func _ready() -> void:
	size = Vector2(480, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painter.canvas = self


func _process(delta: float) -> void:
	fx.calm = reduced_motion
	fx.observe_frame(delta)
	if not reduced_motion:
		_clock += delta
	fx.update(delta)
	position = fx.offset()
	if not _pass.is_empty():
		_pass.t = float(_pass.t) + delta
		if float(_pass.t) >= PASS_SECONDS:
			_pass = {}
	if mode == "play" and run != null:
		fx.follow(_orb_point(), run.status == "playing" and run.altitude > 2.0)
	if mode != "plain" or not _pass.is_empty():
		queue_redraw()


func present(new_mode: String, new_run: RunState = null) -> void:
	mode = new_mode
	run = new_run
	fx.clear()
	_pass = {}
	_orb_hidden = false
	queue_redraw()


func on_launch() -> void:
	if run != null:
		fx.ring(_orb_point() + Vector2(0, 8), Color(RushSkin.COLORS[run.color], 0.8), 34.0, 0.28)


func on_contact() -> void:
	var gate_y: float = PERCH_Y - float(run.stage().gap)
	fx.ring(_map(Vector2(240, gate_y)), RushSkin.COLORS[run.color], 70.0, 0.4)


func on_clear() -> void:
	var stage: Dictionary = run.cleared_stage
	if stage.is_empty():
		return
	var tint: Color = RushSkin.COLORS[run.cleared_color]
	var top: int = GateRules.contacts(stage) - 1
	var height: float = GateRules.contact_height(stage, top)
	_painter.flip = str(stage.kind) == "reverse"
	var point: Vector2 = _painter.map(Vector2(240, PERCH_Y - height - GateRules.ORB_RADIUS))
	fx.burst(point, tint, 22, 190.0)
	fx.ring(point, tint, 120.0, 0.55)
	if reduced_motion:
		return
	_pass = {
		"stage": stage,
		"time": run.cleared_time,
		"color": run.cleared_color,
		"contacts": top + 1,
		"flip": str(stage.kind) == "reverse",
		"rise": height,
		"t": 0.0
	}


func on_fail() -> void:
	var tint: Color = RushSkin.COLORS[run.color]
	var point: Vector2 = _orb_point()
	fx.shatter(point, tint)
	fx.ring(point, RushSkin.COLORS[maxi(run.fail_color, 0)] if run.fail_open else RushSkin.MUTED, 95.0, 0.5)
	fx.shake(0.9)
	_orb_hidden = not reduced_motion


func on_complete() -> void:
	for index: int in range(4):
		fx.burst(Vector2(110 + index * 87, 360 + (index % 2) * 90), RushSkin.COLORS[index], 22, 230.0)
	fx.ring(Vector2(240, 420), RushSkin.GOLD, 220.0, 0.9)


func _draw() -> void:
	match mode:
		"home":
			_home()
		"play":
			if run != null:
				_playfield()
	fx.draw(self)


func _home() -> void:
	var center: Vector2 = Vector2(240, 410 + sin(_clock * 1.1) * 3.0)
	_painter.alpha = 1.0
	_painter.labels = color_labels
	_painter.flip = false
	_painter.hero(center, 0.18 + _clock * 0.22)
	draw_arc(center, 137.0, 0, TAU, 100, RushSkin.LINE, 1.0, true)
	draw_arc(center, 155.0, -0.65, 0.6, 32, Color(RushSkin.accent, 0.5), 1.5, true)
	draw_arc(center, 155.0, PI - 0.65, PI + 0.6, 32, Color(RushSkin.accent, 0.5), 1.5, true)
	var tint: Color = RushSkin.accent
	var pulse: float = 0.5 + 0.5 * sin(_clock * 2.0)
	draw_circle(center, 30.0 + 3.0 * pulse, Color(tint, 0.08))
	draw_circle(center, 21.0, Color(tint, 0.16))
	draw_circle(center, 13.0, tint)
	draw_circle(center + Vector2(-4, -4), 3.0, Color(1, 1, 1, 0.75))
	draw_line(center + Vector2(0, 40), center + Vector2(0, 78), Color(tint, 0.6), 1.5, true)
	draw_circle(center + Vector2(0, 88), 2.0, tint)
	var number: String = "%02d" % menu_number
	var width: float = RushSkin.font().get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 45).x
	_text(number, Vector2(240 - width / 2.0, center.y - 55.0), 45, RushSkin.TEXT)
	var caption: String = "FIND YOUR FREQUENCY"
	var cap_width: float = RushSkin.font().get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(caption, Vector2(240 - cap_width / 2.0, 576), 15, RushSkin.MUTED)


func _playfield() -> void:
	var stage: Dictionary = run.stage()
	var inverted: bool = run.direction() < 0.0
	var e: float = _pass_ease()
	var slide: float = 0.0
	if not _pass.is_empty() and bool(_pass.flip) == inverted:
		slide = -float(_pass.rise) * (1.0 - e)
	_setup_painter(inverted)
	_painter.time = run.elapsed
	_painter.contact = run.contact
	_painter.orb_color = run.color
	_painter.alpha = 1.0 if _pass.is_empty() else clampf(e * 1.8, 0.0, 1.0)
	var gate_y: float = PERCH_Y - float(stage.gap)
	_beam(gate_y + slide, slide)
	_painter.gate(stage, gate_y + slide)
	_perch(slide)
	if not _pass.is_empty():
		_leaving_gate(e)
	if not _orb_hidden:
		_orb(_orb_point(slide))
	_captions(stage)


func _setup_painter(inverted: bool) -> void:
	_painter.canvas = self
	_painter.flip = inverted
	_painter.labels = color_labels
	_painter.calm = reduced_motion
	_painter.clock = _clock


func _leaving_gate(e: float) -> void:
	var old: Dictionary = _pass.stage
	var keep_flip: bool = _painter.flip
	_painter.flip = bool(_pass.flip)
	_painter.time = float(_pass.time) + float(_pass.t)
	_painter.contact = int(_pass.contacts)
	_painter.orb_color = int(_pass.color)
	_painter.alpha = 1.0 - e
	var old_y: float = PERCH_Y - float(old.gap)
	var drop: float = (float(_pass.rise) + PASS_DROP) * e
	_painter.gate(old, old_y + drop)
	_painter.flip = keep_flip


func _beam(top: float, slide: float) -> void:
	var tint: Color = RushSkin.COLORS[run.color]
	var from: Vector2 = _painter.map(Vector2(240, top + 18.0))
	var to: Vector2 = _painter.map(Vector2(240, PERCH_Y - 14.0 + slide))
	draw_line(from, to, Color(tint, 0.07), 2.0, true)


func _perch(slide: float) -> void:
	var tint: Color = RushSkin.COLORS[run.color]
	var y: float = PERCH_Y + 17.0 + slide
	var a: Vector2 = _painter.map(Vector2(176, y))
	var b: Vector2 = _painter.map(Vector2(304, y))
	draw_line(a, b, Color(tint, 0.12), 14.0, true)
	draw_line(a, b, Color(tint, 0.65), 2.5, true)
	draw_line(
		_painter.map(Vector2(212, y + 7)), _painter.map(Vector2(268, y + 7)), Color(RushSkin.LINE, 1.0), 1.5, true
	)
	if run.altitude > 1.0:
		return
	var step: float = 0.0 if reduced_motion else fposmod(_clock * 1.1, 1.0)
	var back: float = 5.0 if run.direction() > 0.0 else -5.0
	for index: int in range(3):
		var rise: float = fposmod(index * 0.33 + step, 1.0)
		var point: Vector2 = _painter.map(Vector2(240, PERCH_Y - 26.0 - rise * 70.0 + slide))
		var fade: float = sin(rise * PI)
		draw_polyline(
			PackedVector2Array([point + Vector2(-5, back), point, point + Vector2(5, back)]),
			Color(tint, 0.65 * fade),
			1.8,
			true
		)


func _orb(point: Vector2) -> void:
	var tint: Color = RushSkin.COLORS[run.color]
	var stretch: float = clampf(absf(run.velocity) / 1700.0, 0.0, 0.3)
	var glow: float = 1.0 if reduced_motion else 0.5 + 0.5 * sin(_clock * 3.0)
	draw_circle(point, 31.0, Color(tint, 0.04 + 0.03 * glow))
	draw_circle(point, 23.0, Color(tint, 0.1))
	draw_circle(point, 17.0, Color(tint, 0.18))
	draw_set_transform(point, 0.0, Vector2(1.0 - stretch * 0.5, 1.0 + stretch))
	draw_circle(Vector2.ZERO, 12.0, tint)
	draw_arc(Vector2.ZERO, 11.4, 0.0, TAU, 28, Color(1, 1, 1, 0.28), 1.3, true)
	draw_circle(Vector2(-3.5, -4.5), 3.0, Color(1, 1, 1, 0.78))
	draw_set_transform(Vector2.ZERO)
	if color_labels:
		_text(str(run.color + 1), point + Vector2(-4.5, 5.5), 15, RushSkin.BG)


func _captions(stage: Dictionary) -> void:
	if large_text:
		return
	var current: int = GateRules.sample(stage, run.elapsed, run.contact)
	var open: bool = GateRules.is_open(stage, run.elapsed)
	var caption: String = "CONTACT  %s" % RushSkin.NAMES[current] if open else "PULSE CLOSED — WAIT"
	_centered(caption, 748.0, 17, RushSkin.COLORS[current] if open else RushSkin.MUTED)
	if guide:
		var wait: float = GateRules.next_window(stage, run.elapsed, run.color, run.contact)
		var line: String = "MATCH NOW" if wait < 0.02 else "NEXT MATCH IN %.1fs" % wait
		_centered(line, 774.0, 17, RushSkin.COLORS[run.color])


func _pass_ease() -> float:
	if _pass.is_empty():
		return 1.0
	return 1.0 - pow(1.0 - clampf(float(_pass.t) / PASS_SECONDS, 0.0, 1.0), 3.0)


func _orb_point(slide: float = 0.0) -> Vector2:
	if run == null:
		return Vector2(240, PERCH_Y)
	return _map(Vector2(240, PERCH_Y - run.altitude + slide))


## Logical (unmirrored) playfield point to screen point for the current stage.
func _map(logical: Vector2) -> Vector2:
	_painter.flip = run != null and run.direction() < 0.0
	return _painter.map(logical)


func _centered(text: String, y: float, font_size: int, tint: Color) -> void:
	var width: float = RushSkin.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(text, Vector2(240.0 - width / 2.0, y), font_size, tint)


func _text(text: String, point: Vector2, font_size: int, tint: Color) -> void:
	draw_string(RushSkin.font(), point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
