class_name ResultScreens
extends RefCounted
## Pause, failure and completion screens. They sit on the themed backdrop with the playfield hidden,
## so nothing ghosts through the text, and the failure screen explains which colour met which.

signal action_requested(action: String)

var layer: Control
var run: RunState
var calm: bool = false
var badge: String = ""


func show_overlay(kind: String) -> void:
	match kind:
		"complete":
			_complete()
		"pause":
			_pause()
		_:
			_failed()


func _complete() -> void:
	var stars: int = run.stars()
	var headline: String = ["Cleared.\nKeep tuning.", "Beautiful\nfrequency.", "Perfect\nresonance."][stars - 1]
	RushSkin.label(layer, "ROUTE %02d / COMPLETE" % run.level.id, Rect2(32, 92, 416, 26), 16, RushSkin.accent)
	RushSkin.heading(layer, headline, Rect2(32, 126, 416, 130), 48)
	for index: int in range(3):
		var earned: bool = index < stars
		var star: Glyph = Glyph.new("star", RushSkin.GOLD if earned else RushSkin.MUTED, earned, 76.0)
		star.glow = true
		star.position = Vector2(32 + index * 88, 282)
		layer.add_child(star)
		if earned and not calm:
			_pop(star, 0.3 + index * 0.22)
	if not badge.is_empty():
		_badge(badge, Rect2(288, 306, 160, 34))
	_tile(0, "TIME", "%.1fs" % run.elapsed)
	_tile(1, "SCORE", str(run.score()))
	_tile(2, "TAPS", str(run.taps))
	var summary: String = "%d RETRIES   ·   PAR %.0fs" % [run.deaths, float(run.level.par)]
	RushSkin.label(layer, summary, Rect2(32, 500, 416, 24), 16, RushSkin.MUTED)
	var note: String = "A clean clear under par earns three stars."
	if run.mode != "standard":
		note = "%s result saved separately from standard records." % run.mode.capitalize()
	if run.mode == "assisted":
		note += " Next continues in practice."
	var note_label: Label = RushSkin.label(layer, note, Rect2(32, 540, 416, 80), 19)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var next_text: String = "NEXT ROUTE  →" if int(run.level.id) < 100 else "VIEW ACHIEVEMENTS  →"
	if run.mode == "assisted" and int(run.level.id) < 100:
		next_text = "NEXT IN PRACTICE  →"
	RushSkin.button(layer, next_text, Rect2(32, 700, 416, 68), func() -> void: action_requested.emit("next"), true)
	RushSkin.button(layer, "Replay", Rect2(32, 785, 200, 64), func() -> void: action_requested.emit("restart"))
	RushSkin.button(layer, "Worlds", Rect2(248, 785, 200, 64), func() -> void: action_requested.emit("worlds"))


func _failed() -> void:
	RushSkin.label(layer, "A MOMENT, THEN AGAIN", Rect2(32, 92, 416, 26), 16, RushSkin.COLORS[1])
	RushSkin.heading(layer, "Find the\nopening.", Rect2(32, 126, 416, 150), 52)
	_panel(Rect2(32, 308, 416, 168))
	_swatch("YOUR ORB", run.color, Vector2(54, 326))
	if run.fail_open and run.fail_color >= 0:
		_swatch("THE GATE SHOWED", run.fail_color, Vector2(246, 326))
	else:
		RushSkin.label(layer, "THE GATE WAS", Rect2(246, 326, 190, 20), 13, RushSkin.MUTED)
		var closed: Glyph = Glyph.new("pulse", RushSkin.MUTED, true, 36.0)
		closed.position = Vector2(246, 352)
		layer.add_child(closed)
		RushSkin.heading(layer, "CLOSED", Rect2(290, 352, 150, 30), 19)
	var reason: String = "Wait on the perch until your color sits under the marker, then launch a beat early."
	if not run.fail_open:
		reason = "The pulse was closed. Watch for your color and an open window."
	var item: Label = RushSkin.label(layer, reason, Rect2(54, 404, 372, 66), 17, RushSkin.MUTED)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RushSkin.label(layer, "CHECKPOINT / GATE %d" % (run.checkpoint + 1), Rect2(32, 506, 416, 28), 18)
	_progress(550.0)
	RushSkin.button(
		layer, "TRY AGAIN  →", Rect2(32, 662, 416, 68), func() -> void: action_requested.emit("retry"), true
	)
	RushSkin.button(
		layer, "Practice this route", Rect2(32, 751, 416, 64), func() -> void: action_requested.emit("practice")
	)


func _pause() -> void:
	RushSkin.label(layer, "TAKE A BREATH", Rect2(32, 150, 416, 28), 16, RushSkin.accent)
	RushSkin.heading(layer, "Stay in\nyour rhythm.", Rect2(32, 190, 416, 150), 49)
	_panel(Rect2(32, 370, 416, 130))
	var stage_count: int = run.level.stages.size()
	var gate: String = "GATE %d / %d" % [mini(run.stage_index + 1, stage_count), stage_count]
	RushSkin.heading(layer, gate, Rect2(54, 388, 200, 34), 24)
	RushSkin.label(
		layer, "%.1f SECONDS  ·  %d TAPS" % [run.elapsed, run.taps], Rect2(54, 426, 380, 26), 17, RushSkin.MUTED
	)
	RushSkin.label(layer, "Your checkpoint is ready when you return.", Rect2(54, 458, 380, 26), 16, RushSkin.MUTED)
	RushSkin.button(layer, "RESUME  →", Rect2(32, 566, 416, 68), func() -> void: action_requested.emit("resume"), true)
	RushSkin.button(layer, "Restart route", Rect2(32, 655, 416, 64), func() -> void: action_requested.emit("restart"))
	RushSkin.button(layer, "Back to worlds", Rect2(32, 739, 416, 64), func() -> void: action_requested.emit("worlds"))


## One capsule per gate: cleared (accent), where Try Again resumes (bright), still ahead (dim).
func _progress(y: float) -> void:
	var count: int = run.level.stages.size()
	var width: float = minf(46.0, (416.0 - 6.0 * (count - 1)) / count)
	for index: int in range(count):
		var pip: ColorRect = ColorRect.new()
		pip.color = (
			RushSkin.accent if index < run.checkpoint else (RushSkin.TEXT if index == run.checkpoint else RushSkin.LINE)
		)
		pip.position = Vector2(32 + index * (width + 6.0), y)
		pip.size = Vector2(width, 8)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(pip)


func _swatch(caption: String, color_index: int, at: Vector2) -> void:
	RushSkin.label(layer, caption, Rect2(at.x, at.y, 190, 20), 13, RushSkin.MUTED)
	var orb: Glyph = Glyph.new("orb", RushSkin.COLORS[color_index], true, 40.0)
	orb.slot = color_index
	orb.position = at + Vector2(0, 28)
	layer.add_child(orb)
	RushSkin.heading(layer, RushSkin.NAMES[color_index], Rect2(at.x + 48, at.y + 30, 140, 30), 19)


func _tile(column: int, caption: String, value: String) -> void:
	var origin: Vector2 = Vector2(32 + column * 142, 388)
	_panel(Rect2(origin, Vector2(132, 88)))
	RushSkin.label(layer, caption, Rect2(origin.x + 14, origin.y + 12, 110, 20), 13, RushSkin.MUTED)
	RushSkin.heading(layer, value, Rect2(origin.x + 14, origin.y + 38, 118, 40), 26)


func _panel(rect: Rect2) -> void:
	var panel: Panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", RushSkin.style(Color(RushSkin.SURFACE, 0.92), RushSkin.LINE, 16))
	layer.add_child(panel)


func _badge(text: String, rect: Rect2) -> void:
	var panel: Panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", RushSkin.style(Color(RushSkin.GOLD, 0.16), RushSkin.GOLD, 17))
	layer.add_child(panel)
	var label: Label = RushSkin.heading(layer, text, rect, 16)
	label.add_theme_color_override("font_color", RushSkin.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _pop(item: Control, delay: float) -> void:
	item.pivot_offset = item.size / 2.0
	item.scale = Vector2.ZERO
	var tween: Tween = item.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(item, "scale", Vector2.ONE * 1.2, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_property(item, "scale", Vector2.ONE, 0.12)
