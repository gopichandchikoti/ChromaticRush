class_name AccessibleHud
extends Control

var run: RunState
var guide: bool = false
var _orb: Label
var _gate: Label
var _timer: Label
var _contact: Label


static func build(layer: Control, current_run: RunState, show_guide: bool = false) -> void:
	var pause: Button = null
	var propel: Button = null
	for control: Node in layer.find_children("*", "BaseButton", true, false):
		if control is Button and control.text == "Ⅱ":
			pause = control
		if control is Button and control.text.begins_with("TAP TO PROPEL"):
			propel = control
	if pause == null or propel == null:
		return
	for child: Node in layer.get_children():
		if child is Control:
			child.hide()
	var hud: AccessibleHud = AccessibleHud.new()
	hud.name = "LargeHud"
	hud.run = current_run
	hud.guide = show_guide
	layer.add_child(hud)
	hud._build(pause, propel)


func _build(pause: Button, propel: Button) -> void:
	size = Vector2(480, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "HudScroll"
	scroll.position = Vector2(32, 12)
	scroll.size = Vector2(416, 234)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 12)
	scroll.add_child(rows)
	_orb = _line(rows, "", 34)
	_gate = _line(rows, "", 28)
	_timer = _line(rows, "", 48)
	_contact = _line(rows, "", 34)
	_line(rows, "%02d  %s" % [run.level.id, run.level.name], 52)
	RushSkin.button(self, "PAUSE", Rect2(32, 258, 416, 88), pause.pressed.emit).add_theme_font_size_override(
		"font_size", 42
	)
	var tap: Button = RushSkin.button(self, "PROPEL  ↑", Rect2(32, 790, 416, 98), propel.pressed.emit, true)
	tap.set_meta("reader_source", "TAP TO PROPEL")
	tap.add_theme_font_size_override("font_size", 42)
	RushAccessibility.label_control(tap, "TAP TO PROPEL")
	_tick()


func _line(rows: VBoxContainer, text: String, font_size: int) -> Label:
	var label: Label = RushSkin.label(rows, text, Rect2(0, 0, 416, 60), font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.y = 64
	return label


func _process(_delta: float) -> void:
	_tick()


func _tick() -> void:
	if _orb == null:
		return
	_orb.text = "%s · %s" % [RushSkin.NAMES[run.color], str(run.stage().kind).to_upper()]
	_gate.text = (
		"GATE %d / %d  ·  %s"
		% [mini(run.stage_index + 1, run.level.stages.size()), run.level.stages.size(), run.mode.to_upper()]
	)
	_timer.text = "%.1f SECONDS" % run.elapsed
	var tint: Color = RushSkin.COLORS[GateRules.sample(run.stage(), run.elapsed, run.contact)]
	_contact.text = "CONTACT %s" % RushSkin.NAMES[GateRules.sample(run.stage(), run.elapsed, run.contact)]
	if not GateRules.is_open(run.stage(), run.elapsed):
		_contact.text = "PULSE CLOSED — WAIT"
	if guide:
		var wait: float = GateRules.next_window(run.stage(), run.elapsed, run.color, run.contact)
		_contact.text += "\n" + ("MATCH NOW" if wait < 0.02 else "NEXT MATCH IN %.1fs" % wait)
	_contact.add_theme_color_override("font_color", tint)
	_orb.add_theme_color_override("font_color", RushSkin.COLORS[run.color])
