extends SceneTree

const App = preload("res://src/app.gd")
const STEP: float = 1.0 / 120.0
const Capture = preload("res://tests/ui_capture.gd")
const HelpChecks = preload("res://tests/ui_help_checks.gd")

var _app: App
var _root_path: String
var _checks: int = 0
var _failures: Array[String] = []
var _captures: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_root_path = "user://ui-tests-%s" % Time.get_ticks_usec()
	_app = App.new()
	_app.save_root = _root_path
	_app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_app)
	_app.set_process(false)
	_app.sound.suspend(true)
	await _frames()
	_check(_app.screen == "home", "First launch opens the actual game menu")
	_check(_app.save.totals().completed == 0, "Isolated fixture begins with no fabricated progress")
	await _test_navigation()
	await _test_settings_and_help()
	await _test_input_and_checkpoint()
	await _test_retry_keyboard()
	await _test_real_completion()
	await _test_practice_worlds()
	await _test_save_warning()
	await _test_layouts()
	if "--capture" in OS.get_cmdline_user_args():
		var capture: Capture = Capture.new()
		capture.app = _app
		capture.tree = self
		capture.press = _press
		capture.replay = _replay_first_route
		capture.key = _key
		capture.check = _check
		_captures = await capture.capture_views()
	_app.sound.suspend(true)
	await create_timer(0.15).timeout
	_app.queue_free()
	await _frames()
	_cleanup()
	print(
		JSON.stringify(
			{
				"suite": "native UI integration",
				"checks": _checks,
				"failures": _failures,
				"screenshots": _captures.size()
			}
		)
	)
	quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr(message)


func _frames() -> void:
	await process_frame
	await process_frame


func _buttons() -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in _app.layer.find_children("*", "Button", true, false):
		if node is Button and node.is_visible_in_tree():
			result.append(node)
	return result


func _button(prefix: String) -> Button:
	for button: Button in _buttons():
		if button.text.begins_with(prefix):
			return button
	return null


func _press(prefix: String) -> void:
	var button: Button = _button(prefix)
	_check(button != null, "Native button exists: %s" % prefix)
	if button != null:
		_check(not button.disabled, "Native button enabled: %s" % prefix)
		if not button.disabled:
			button.pressed.emit()
	await _frames()


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	_app._input(event)


func _home() -> void:
	_app._show("home")
	await _frames()


func _test_navigation() -> void:
	await _press("Worlds")
	_check(_app.screen == "worlds", "Worlds button navigates to world selection")
	_check(_buttons().size() == 11, "Ten worlds and Back render")
	_check(not _button("01").disabled and _button("02").disabled, "Only first world standard-unlocked initially")
	await _press("01")
	_check(_app.screen == "levels", "World button opens authored levels")
	_check(_buttons().size() == 11, "Ten level buttons render")
	_check(not _button("01").disabled and _button("02").disabled, "Standard level graph prevents skipping")
	await _press("01")
	_check(_app.screen == "detail", "Level button opens details")
	await _press("START ROUTE")
	_check(_app.screen == "game" and _app.run.level.id == 1, "Start action opens actual level one")


func _test_settings_and_help() -> void:
	await _home()
	await _press("SET")
	_check(_app.screen == "settings", "Settings opens from the real control")
	var sound_toggle: CheckButton = _button("Sound effects") as CheckButton
	_check(sound_toggle != null, "Sound setting uses a native toggle")
	if sound_toggle != null:
		sound_toggle.button_pressed = false
		_check(not _app.save.settings().sound and not _app.sound.enabled, "Toggle changes persisted sound adapter")
	var motion_toggle: CheckButton = _button("Reduce decorative motion") as CheckButton
	if motion_toggle != null:
		motion_toggle.button_pressed = true
		_check(_app.canvas.reduced_motion, "Reduced motion toggle reaches renderer")
	var reloaded := RushSave.new(_root_path)
	_check(reloaded.load_save() == OK and not reloaded.settings().sound, "UI setting survives real disk reload")
	for button: Button in _buttons():
		_check(button.size.y >= 64, "Settings native touch control retains minimum height")
	await _press("How to play")
	_check(_app.screen == "help", "How-to native action navigates")
	HelpChecks.verify(_app.layer, _check)
	_key(KEY_ESCAPE)
	await _frames()
	_check(_app.screen == "settings", "Escape respects menu navigation history")


func _test_input_and_checkpoint() -> void:
	await _home()
	await _press("CONTINUE RUN")
	_check(_app.run.status == "ready", "Run waits for a gameplay input")
	_key(KEY_SPACE)
	_check(_app.run.taps == 1 and _app.run.velocity > 0.0, "Space immediately propels the real run")
	_app._process(0.1)
	var elapsed: float = _app.run.elapsed
	_key(KEY_ESCAPE)
	await _frames()
	_check(_app.run.status == "paused", "Escape pauses active gameplay")
	_check(
		_app.save.data.resume.elapsed == elapsed and _app.save.data.resume.taps == 1,
		"Pause durably stores cumulative run statistics"
	)
	var focus: Control = root.gui_get_focus_owner()
	_check(focus != null and focus.is_visible_in_tree(), "Pause focus belongs to a visible overlay control")
	if focus is Button:
		_check(focus.text.begins_with("RESUME"), "Resume receives initial overlay focus")
	_app._process(0.25)
	_check(_app.run.elapsed == elapsed, "Paused application process leaves clock frozen")
	await _gui_space()
	_check(_app.run.status == "playing", "Native focused Resume accepts Space and restores active run")
	_app.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(_app.run.status == "paused", "Application focus loss pauses game")
	_check(not ProjectSettings.get_setting("application/config/quit_on_go_back", true), "Back is handled by the app")
	for expected: String in ["playing", "paused"]:
		_app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		_check(_app.run.status == expected and _app.screen == "game", "Android Back toggles pause: " + expected)
	_key(KEY_ESCAPE)
	await _frames()
	_check(_app.run.status == "playing", "Escape resumes paused game")
	_key(KEY_ESCAPE)
	await _frames()
	await _press("Back to worlds")
	await _home()
	await _press("CONTINUE RUN")
	_check(is_equal_approx(_app.run.elapsed, elapsed) and _app.run.taps == 1, "Continue restores elapsed time and taps")


func _test_real_completion() -> void:
	_app.save.data.resume = {}
	_app.start_level(1)
	await _frames()
	_replay_first_route()
	await _frames()
	_check(_app.run.status == "complete", "Timestamped actual inputs finish authored level one")
	_check(_app.save.data.records.has("1") and _app.save.unlocked(2), "Actual completion saves and unlocks next level")
	_check(_app.save.data.resume.is_empty(), "Completion clears checkpoint resume")
	var focus: Control = root.gui_get_focus_owner()
	_check(
		focus is Button and focus.is_visible_in_tree() and focus.text.begins_with("NEXT"),
		"Completion focuses visible next action"
	)
	await _press("NEXT ROUTE")
	_check(_app.run.level.id == 2 and _app.run.mode == "standard", "Next starts unlocked standard route")


func _gui_space() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	Input.parse_input_event(event)
	await _frames()


func _test_retry_keyboard() -> void:
	var id: int = 0
	for level: Dictionary in _app.registry.levels:
		var candidate := RunState.new(level)
		candidate.tap()
		candidate.advance(0.5)
		if candidate.status == "failed":
			id = int(level.id)
			break
	_check(id > 0, "An authored route supplies a real wrong-timing collision")
	_app.save.data.resume = {}
	_app.start_level(id, true)
	_key(KEY_SPACE)
	_app._process(0.5)
	await _frames()
	_check(_app.run.status == "failed", "Wrong-timing input produces native failure overlay")
	await _gui_space()
	_check(
		_app.run.status == "ready" and _app.run.deaths == 1,
		"Focused Try Again accepts Space and retains the real collision count"
	)


func _replay_first_route() -> void:
	var parser := JSON.new()
	var result: Error = parser.parse(FileAccess.get_file_as_string("res://docs/evidence/route_audit.json"))
	_check(result == OK, "Real route audit is available to replay")
	if result != OK:
		return
	var route: Dictionary = parser.data.levels[0]
	var clock: float = 0.0
	for time: float in route.tap_schedule:
		while clock < time - 0.0000001:
			var delta: float = minf(STEP, time - clock)
			_app._process(delta)
			clock += delta
		_key(KEY_SPACE)
	for _tick: int in range(120):
		_app._process(STEP)
		if _app.run.status in ["complete", "failed"]:
			break


func _test_practice_worlds() -> void:
	await _home()
	await _press("Practice")
	_check(_app.screen == "worlds" and _app.menus.practice, "Practice is explicitly marked")
	for id: int in range(1, 11):
		var button: Button = _button("%02d" % id)
		_check(button != null and not button.disabled, "Practice makes world %d available" % id)
		await _press("%02d" % id)
		_check(_app.screen == "levels" and _buttons().size() == 11, "World %d renders ten actual levels" % id)
		for row: Button in _buttons():
			_check(not row.disabled, "Every practice level remains available")
		await _press("←")
	await _press("10")
	await _press("100")
	await _press("PRACTICE ROUTE")
	_check(_app.run.level.id == 100 and _app.run.mode == "practice", "Practice starts final authored level")
	_check(_app.save.totals().completed == 1, "Browsing and starting practice creates no standard completions")


func _test_save_warning() -> void:
	await _home()
	var original: RushSave = _app.save
	var blocker: String = _root_path.path_join("ui-test-file-blocker")
	var file: FileAccess = FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("Isolated storage-failure test fixture; not player progress.")
	file.close()
	var failing := RushSave.new(blocker.path_join("nested"))
	_app.save = failing
	_app.menus.save = failing
	await _press("SET")
	var toggle: CheckButton = _button("Sound effects") as CheckButton
	if toggle != null:
		toggle.button_pressed = false
	await _frames()
	var warning_label: Label = null
	var banner: Node = _app.layer.get_node_or_null("SaveWarning")
	if banner != null:
		for node: Node in banner.find_children("*", "Label", true, false):
			if node is Label:
				warning_label = node
				break
	_check(warning_label != null and warning_label.is_visible_in_tree(), "Recoverable storage warning is visible")
	_check(
		warning_label != null and warning_label.autowrap_mode != TextServer.AUTOWRAP_OFF,
		"Save warning wraps within the viewport"
	)
	if warning_label != null:
		_check(
			warning_label.position.x + warning_label.size.x <= 350,
			"Storage warning text leaves room for native retry action"
		)
	await _press("Retry")
	_check(
		not failing.warning.is_empty() and _app.layer.get_node_or_null("SaveWarning") != null,
		"Retry preserves visible failure while storage remains blocked"
	)
	_app.save = original
	_app.menus.save = original
	_app._apply_settings()
	await _home()
	_check(_app.layer.get_node_or_null("SaveWarning") == null, "Resolved save warning is removed")


func _test_layouts() -> void:
	for dimensions: Vector2i in [Vector2i(480, 900), Vector2i(320, 600), Vector2i(900, 480)]:
		root.size = dimensions
		await _frames()
		await _home()
		var rect: Rect2 = _app.frame.get_global_rect()
		_check(rect.position.x >= -0.1 and rect.position.y >= -0.1, "Portrait frame starts within resized viewport")
		_check(
			rect.end.x <= _app.size.x + 0.1 and rect.end.y <= _app.size.y + 0.1,
			"Portrait frame fits at %s" % str(dimensions)
		)
		for button: Button in _buttons():
			_check(
				button.position.x >= 32 and button.position.x + button.size.x <= 448.1,
				(
					"Home action %s respects logical margins at %s: %s"
					% [button.text, str(dimensions), str(button.get_rect())]
				)
			)
			if button.text.begins_with("CONTINUE"):
				var surface: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
				_check(
					_contrast(button.get_theme_color("font_focus_color"), surface.bg_color) >= 4.5,
					"Focused primary action keeps readable contrast"
				)
		_app.save.data.resume = {}
		_app.start_level(1)
		_touch(Vector2(240, 220))
		_check(_app.run.taps == 0, "Touching HUD does not propel at %s" % str(dimensions))
		_touch(Vector2(-50, 500))
		_check(_app.run.taps == 0, "Touching outside portrait frame does not propel at %s" % str(dimensions))
		_touch(Vector2(240, 600))
		_check(_app.run.taps == 1, "Transformed arena touch propels at %s" % str(dimensions))
	root.size = Vector2i(480, 900)
	await _frames()


func _touch(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = _app.frame.get_global_transform_with_canvas() * point
	_app._input(event)


func _contrast(first: Color, second: Color) -> float:
	var foreground: Color = first.srgb_to_linear()
	var background: Color = second.srgb_to_linear()
	var first_luma: float = foreground.r * 0.2126 + foreground.g * 0.7152 + foreground.b * 0.0722
	var second_luma: float = background.r * 0.2126 + background.g * 0.7152 + background.b * 0.0722
	return (maxf(first_luma, second_luma) + 0.05) / (minf(first_luma, second_luma) + 0.05)


func _cleanup() -> void:
	for file: String in DirAccess.get_files_at(_root_path):
		DirAccess.remove_absolute(_root_path.path_join(file))
	DirAccess.remove_absolute(_root_path)
