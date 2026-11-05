class_name RunScreens
extends RefCounted
## In-run HUD. Overlays (pause / failed / complete) live in ResultScreens.

signal action_requested(action: String)

var layer: Control
var run: RunState
var calm: bool = false
var badge: String = ""
var title_label: Label
var timer_label: Label
var gate_label: Label
var orb_label: Label
var view: HudView
var _results: ResultScreens = ResultScreens.new()


func _init() -> void:
	_results.action_requested.connect(_forward_action)


func _forward_action(action: String) -> void:
	action_requested.emit(action)


func hud(world_name: String) -> void:
	RushSkin.label(
		layer,
		"WORLD %02d  /  %s" % [run.level.world, world_name.to_upper()],
		Rect2(32, 28, 330, 22),
		14,
		RushSkin.accent
	)
	title_label = RushSkin.heading(layer, "%02d  %s" % [run.level.id, run.level.name], Rect2(32, 50, 336, 60), 26)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view = HudView.new()
	view.run = run
	view.calm = calm
	layer.add_child(view)
	RushSkin.button(layer, "Ⅱ", Rect2(384, 30, 64, 64), func() -> void: action_requested.emit("pause"))
	timer_label = RushSkin.label(layer, "000.0s", Rect2(272, 98, 176, 32), 24)
	timer_label.add_theme_font_override("font", RushSkin.font(true))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gate_label = RushSkin.label(layer, "GATE 1", Rect2(32, 136, 220, 22), 14, RushSkin.MUTED)
	var par: Label = RushSkin.label(
		layer, "PAR %.0fs" % float(run.level.par), Rect2(272, 132, 176, 22), 14, RushSkin.MUTED
	)
	par.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	orb_label = RushSkin.label(layer, "", Rect2(76, 170, 214, 26), 17, RushSkin.COLORS[run.color])
	var tap_button: Button = RushSkin.button(
		layer, "TAP TO PROPEL   ↑", Rect2(32, 800, 416, 68), func() -> void: action_requested.emit("tap"), true
	)
	tap_button.focus_mode = Control.FOCUS_NONE
	RushSkin.recolor(tap_button, RushSkin.TEXT)
	tick()


func tick() -> void:
	if not is_instance_valid(timer_label):
		return
	timer_label.text = "%05.1fs" % run.elapsed
	var stage_count: int = run.level.stages.size()
	gate_label.text = "GATE %d / %d" % [mini(run.stage_index + 1, stage_count), stage_count]
	if run.mode != "standard":
		gate_label.text += "  ·  " + run.mode.to_upper()
	orb_label.text = "%s  ·  %s" % [RushSkin.NAMES[run.color], str(run.stage().kind).to_upper()]
	orb_label.add_theme_color_override("font_color", RushSkin.COLORS[run.color])


func overlay(kind: String) -> void:
	for child: Node in layer.get_children():
		if child is Control:
			child.hide()
	_results.layer = layer
	_results.run = run
	_results.calm = calm
	_results.badge = badge
	_results.show_overlay(kind)
