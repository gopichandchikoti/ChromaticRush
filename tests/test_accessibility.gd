extends SceneTree

const App = preload("res://src/app.gd")
var app: App
var checks: int = 0
var failures: Array[String] = []
var fixture: String
var captures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	fixture = "user://accessibility-tests-%s" % Time.get_ticks_usec()
	app = App.new()
	app.save_root = fixture
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	app.set_process(false)
	app.sound.suspend(true)
	app.sound.enabled = false
	await _frames()
	_check(_button("SET").accessibility_name == "Settings", "Abbreviated settings action has a full accessible name")
	await _press("SET")
	_button("Large text").button_pressed = true
	await _frames()
	_check(app.save.settings().large_text, "Actual native toggle saves large text preference")
	_check(app.layer.has_node("LargeText"), "Large text uses the reflowed native interface")
	await _check_reader("settings")
	await _press("How to play")
	await _check_reader("help")
	await _press("←")
	await _press("Records + achievements")
	await _check_reader("achievements")
	app._show("home")
	await _frames()
	await _check_reader("home")
	await _press("Worlds")
	_check(_button("02").disabled, "Large text preserves world locking")
	await _press("01")
	_check(_button("02").disabled, "Large text preserves standard level locking")
	await _check_reader("levels")
	await _press("01")
	await _check_reader("detail")
	await _press("START ROUTE")
	await _check_game()
	await _earned_completion()
	await _check_overlays()
	await _check_layouts()
	app._show("settings")
	await _frames()
	_button("Large text").button_pressed = false
	await _frames()
	_check(
		not app.save.settings().large_text and not app.layer.has_node("LargeText"),
		"Large text can be disabled from its operational toggle"
	)
	var reopened: RushSave = RushSave.new(fixture)
	_check(
		reopened.load_save() == OK and not reopened.settings().large_text, "Text preference survives real file reload"
	)
	_check_contrast()
	app.sound.suspend(true)
	await create_timer(0.15).timeout
	app.queue_free()
	await _frames()
	for filename: String in DirAccess.get_files_at(fixture):
		DirAccess.remove_absolute(fixture.path_join(filename))
	DirAccess.remove_absolute(fixture)
	print(
		JSON.stringify(
			{
				"suite": "native accessibility and large text",
				"checks": checks,
				"failures": failures,
				"captures": captures
			}
		)
	)
	quit(1 if not failures.is_empty() else 0)


func _check_reader(screen: String) -> void:
	var reader: Node = app.layer.get_node_or_null("LargeText")
	_check(reader != null, "%s reflows in large text mode" % screen)
	if reader == null:
		return
	var scroll: ScrollContainer = reader.get_node("ReaderScroll")
	_check(
		scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"%s needs no horizontal scrolling" % screen
	)
	for node: Node in reader.find_children("*", "Label", true, false):
		if node is Label:
			_check(node.get_theme_font_size("font_size") >= 26, "%s has doubled readable text" % screen)
			_check(
				node.size.x <= 416.0 and node.get_line_count() > 0, "%s text wraps inside the content width" % screen
			)
	for button: Button in _buttons():
		_check(not button.accessibility_name.is_empty(), "%s action has a screen-reader name" % screen)
		if not button.disabled:
			_check(not button.focus_next.is_empty(), "%s keyboard flow is explicit" % screen)
	await _capture("large-" + screen)


func _check_game() -> void:
	_check(app.layer.has_node("LargeHud"), "Gameplay uses the enlarged scrolling native HUD")
	_check(app.canvas.large_text, "Small drawn captions are replaced by enlarged HUD information")
	_check(_button("PAUSE").get_theme_font_size("font_size") == 42, "Pause text is doubled")
	_check(_button("TAP TO PROPEL").get_theme_font_size("font_size") == 42, "Propel text is doubled")
	var taps: int = app.run.taps
	await _press("TAP TO PROPEL")
	_check(app.run.taps == taps + 1, "Enlarged native Propel applies the production impulse")
	await _press("PAUSE")
	_check(app.run.status == "paused", "Enlarged native Pause reaches the production pause flow")
	await _check_reader("pause")
	await _press("RESUME")
	_check(app.run.status == "playing", "Enlarged Resume continues the same run")
	await _capture("large-game")


func _check_overlays() -> void:
	app.run.status = "failed"
	app._open_overlay("failed")
	await _frames()
	await _check_reader("failure")
	await _press("TRY AGAIN")
	_check(app.run.status == "ready", "Enlarged retry uses the actual checkpoint reset")
	app.run.status = "complete"
	app._open_overlay("complete")
	await _frames()
	await _check_reader("completion")
	var completed: int = app.save.totals().completed
	await _press("NEXT ROUTE")
	_check(app.save.totals().completed == completed, "Presentation fixtures cannot award standard records")


func _earned_completion() -> void:
	app.save.data.resume = {}
	app.start_level(1)
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/route_audit.json"))
	var clock: float = 0.0
	for time: float in audit.levels[0].tap_schedule:
		while clock < time - 0.0000001:
			var delta: float = minf(1.0 / 120.0, time - clock)
			app._process(delta)
			clock += delta
		var event: InputEventKey = InputEventKey.new()
		event.keycode = KEY_SPACE
		event.pressed = true
		app._input(event)
	for _tick: int in range(120):
		app._process(1.0 / 120.0)
		if app.run.status in ["complete", "failed"]:
			break
	app._process(1.0)
	await _frames()
	_check(app.run.status == "complete" and app.save.unlocked(2), "Large-text game earns a real level clear and unlock")
	await _press("NEXT ROUTE")
	_check(app.run.level.id == 2 and app.run.mode == "standard", "Large-text Next starts the earned unlocked route")


func _check_layouts() -> void:
	for dimensions: Vector2i in [Vector2i(320, 600), Vector2i(480, 900), Vector2i(900, 480)]:
		root.size = dimensions
		app._show("home")
		await _frames()
		var reader: Control = app.layer.get_node("LargeText")
		_check(reader.size == Vector2(480, 900), "Reader keeps the logical portrait dimensions")
		for button: Button in _buttons():
			_check(
				button.size.x <= 416 and button.size.y >= 106, "Two-hundred-percent action wraps and keeps touch target"
			)
		var first: Button = _buttons()[0]
		_check(
			str(first.get_meta("reader_source")).begins_with("CONTINUE"),
			"Primary game action precedes secondary navigation"
		)
		await _capture("large-home-%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(480, 900)
	await _frames()


func _check_contrast() -> void:
	for color: Color in [RushSkin.TEXT, RushSkin.MUTED] + RushSkin.COLORS:
		_check(_contrast(color, RushSkin.SURFACE) >= 4.5, "Text palette exceeds 4.5:1 on native surfaces")
		for world: int in range(1, 11):
			var theme: Dictionary = RushSkin.theme_of(world)
			_check(
				_contrast(color, theme.top) >= 4.5 and _contrast(color, theme.bottom) >= 4.5,
				"Text palette exceeds 4.5:1 on world %d base gradient tokens" % world
			)
	_check(RushAccessibility.prefers_reduced_motion(true), "Explicit reduced motion always wins over OS preference")


func _contrast(a: Color, b: Color) -> float:
	var first: float = _luminance(a)
	var second: float = _luminance(b)
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)


func _luminance(color: Color) -> float:
	var linear: Color = color.srgb_to_linear()
	return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722


func _buttons() -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in app.layer.find_children("*", "Button", true, false):
		if node is Button and node.is_visible_in_tree():
			result.append(node)
	return result


func _button(prefix: String) -> Button:
	for button: Button in _buttons():
		if str(button.get_meta("reader_source", button.text)).begins_with(prefix):
			return button
	return null


func _press(prefix: String) -> void:
	var button: Button = _button(prefix)
	_check(button != null and not button.disabled, "Operational action exists: " + prefix)
	if button != null and not button.disabled:
		button.pressed.emit()
	await _frames()


func _frames() -> void:
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr(message)


func _capture(view: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path: String = "res://docs/evidence/%s.png" % view
	_check(root.get_texture().get_image().save_png(path) == OK, "Native 200% screenshot saved: " + view)
	captures.append(path)
