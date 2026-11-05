class_name SettingsScreens
extends ScreenBase
## Settings, how-to-play and achievements.

signal setting_changed(key: String, value: bool)
signal reset_requested


func settings() -> void:
	header("Make it yours", "Saved on this device. No account needed.")
	var rows: VBoxContainer = column()
	var options: Dictionary = {
		"sound": "Sound effects",
		"music": "World soundtrack",
		"haptics": "Haptics (Android)",
		"reduced_motion": "Reduce decorative motion",
		"color_labels": "Shape + number color cues",
		"large_text": "Large text (200%)",
		"guide": "Assist: show matching windows",
		"slow_time": "Assist: slower time (70%)"
	}
	for key: String in options:
		var toggle: CheckButton = CheckButton.new()
		toggle.text = options[key]
		toggle.custom_minimum_size = Vector2(400, 66)
		toggle.add_theme_font_override("font", RushSkin.font())
		toggle.add_theme_font_size_override("font_size", 21)
		toggle.button_pressed = bool(save.settings()[key])
		RushSkin.style_toggle(toggle)
		toggle.toggled.connect(func(value: bool) -> void: setting_changed.emit(key, value))
		rows.add_child(toggle)
	RushSkin.button(rows, "How to play", Rect2(0, 0, 400, 64), func() -> void: navigate.emit("help", 1))
	RushSkin.button(
		rows, "Records + achievements", Rect2(0, 0, 400, 64), func() -> void: navigate.emit("achievements", 1)
	)
	var reset: Button = RushSkin.button(
		rows, "Reset local progress…", Rect2(0, 0, 400, 64), func() -> void: reset_requested.emit()
	)
	reset.custom_minimum_size.y = 64
	RushSkin.label(rows, "v1.0.0 · Fully offline · No tracking", Rect2(0, 0, 400, 32), 17, RushSkin.MUTED)


func achievements() -> void:
	header("Your resonance", "Standard clears only. Assisted records stay separate.")
	var rows: VBoxContainer = column()
	for entry: Dictionary in save.achievements():
		var done: bool = bool(entry.unlocked)
		var holder: Control = Control.new()
		holder.custom_minimum_size = Vector2(405, 92)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(holder)
		panel(holder, Rect2(0, 0, 405, 92), RushSkin.SURFACE_HI if done else RushSkin.SURFACE)
		var star: Glyph = Glyph.new("star", RushSkin.GOLD if done else RushSkin.MUTED, done, 34.0)
		star.glow = true
		star.position = Vector2(18, 29)
		holder.add_child(star)
		var tint: Color = RushSkin.GOLD if done else RushSkin.TEXT
		RushSkin.label(holder, "%s" % entry.name, Rect2(66, 14, 320, 30), 21, tint)
		RushSkin.label(holder, "%d / %d" % [entry.current, entry.target], Rect2(66, 44, 120, 22), 15, RushSkin.MUTED)
		bar(holder, Rect2(66, 72, 320, 5), float(entry.current) / maxf(float(entry.target), 1.0), tint)


func help() -> void:
	header("Find your flow", "Timing first. Speed will follow.")
	var blocks: Array = [
		["TAP / SPACE", "Propel the orb toward the gate. Tap again in the air."],
		[
			"MATCH AT CONTACT",
			"Your orb must match the segment under the marker. Numbers 1–4 and shapes name each color."
		],
		[
			"WAIT ON THE PERCH",
			"The line below your orb is safe and the gate keeps moving. Watch it, then launch a beat early."
		],
		[
			"FOLLOW THE DIRECTION",
			"Inverse gates reverse gravity and route direction. Tap still propels toward the exit."
		],
		[
			"MAKE IT YOURS",
			"Practice opens all 100 routes. Assists save separately. Standard stars reward clean, quick runs."
		]
	]
	var y: float = 196.0
	for block: Array in blocks:
		var title: Label = RushSkin.label(layer, block[0], Rect2(32, y, 416, 26), 17, RushSkin.accent)
		title.add_theme_font_override("font", RushSkin.font(true))
		var body: Label = RushSkin.label(layer, block[1], Rect2(32, y + 28, 416, 64), 19)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		y += 128.0
