class_name RushApp
extends Control

var registry: LevelRegistry
var save: RushSave
var run: RunState
var canvas: GameCanvas
var backdrop: Backdrop
var sound: SoundBank
var menus: MenuScreens
var run_ui: RunScreens
var frame: Control
var layer: Control
var screen: String = "home"
var world_id: int = 1
var save_root: String = "user://"
var _history: Array[Dictionary] = []
var _pause_status: String = "ready"
var _last_stage: int = 0
var _recorded: bool = false
var _pending_overlay: String = ""
var _overlay_delay: float = 0.0
var _quitting: bool = false


func _ready() -> void:
	registry = LevelRegistry.new()
	save = RushSave.new(save_root)
	save.load_save()
	backdrop = Backdrop.new()
	add_child(backdrop)
	frame = Control.new()
	frame.size = Vector2(480, 900)
	add_child(frame)
	canvas = GameCanvas.new()
	frame.add_child(canvas)
	layer = Control.new()
	layer.size = Vector2(480, 900)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(layer)
	sound = SoundBank.new()
	add_child(sound)
	menus = MenuScreens.new()
	menus.layer = layer
	menus.registry = registry
	menus.save = save
	menus.navigate.connect(_navigate)
	menus.play.connect(start_level)
	menus.setting_changed.connect(_setting_changed)
	menus.reset_requested.connect(_confirm_reset)
	run_ui = RunScreens.new()
	run_ui.layer = layer
	run_ui.action_requested.connect(_run_action)
	resized.connect(_layout)
	_layout()
	_apply_settings()
	_show("home")


func _layout() -> void:
	if frame == null:
		return
	var factor: float = minf(size.x / 480.0, size.y / 900.0)
	frame.scale = Vector2.ONE * factor
	frame.position = (size - Vector2(480, 900) * factor) / 2.0


func _process(delta: float) -> void:
	_tick_overlay(delta)
	if screen != "game" or run == null:
		return
	run.advance(delta)
	run_ui.tick()
	RushAccessibility.update_status(layer, run)
	if run.last_event == "contact":
		sound.play("contact")
		canvas.on_contact()
	if run.stage_index != _last_stage:
		_last_stage = run.stage_index
		sound.play("clear", run.stage_index)
		canvas.on_clear()
		_persist_checkpoint()
	if run.status in ["failed", "complete"] and not _recorded:
		_recorded = true
		_finish_run()


## The failure/complete screens wait a beat so the shatter or the final pass-through is actually seen.
func _tick_overlay(delta: float) -> void:
	if _pending_overlay.is_empty():
		return
	_overlay_delay -= delta
	if _overlay_delay > 0.0:
		return
	var kind: String = _pending_overlay
	_pending_overlay = ""
	_open_overlay(kind)


func _input(event: InputEvent) -> void:
	if _quitting:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_P]:
			_back_or_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE and screen == "game" and run != null and run.status in ["ready", "playing"]:
			_run_action("tap")
			get_viewport().set_input_as_handled()
	if screen != "game" or run == null or run.status not in ["ready", "playing"]:
		return
	var touch: bool = event is InputEventScreenTouch and event.pressed
	var mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if touch or mouse:
		var local_point: Vector2 = frame.get_local_mouse_position()
		if touch:
			var local_touch: InputEventScreenTouch = frame.make_input_local(event) as InputEventScreenTouch
			local_point = local_touch.position
		var top: float = 360.0 if bool(save.settings().large_text) else 270.0
		if Rect2(0, top, 480, 785 - top).has_point(local_point):
			_run_action("tap")
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "game" and run != null:
		_run_action("pause")
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and sound != null:
		sound.suspend(true)
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and sound != null and not _quitting:
		sound.suspend(false)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# quit_on_go_back is disabled so Back can pause/navigate; only the root screen exits.
		if screen == "home":
			_quit_cleanly()
		else:
			_back_or_pause()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_cleanly()


func _quit_cleanly() -> void:
	if _quitting:
		return
	_quitting = true
	set_process(false)
	_persist_checkpoint()
	sound.suspend(true)
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()


func _navigate(destination: String, next_world: int = 1) -> void:
	if destination == "back":
		if _history.is_empty():
			_show("home")
			return
		var previous: Dictionary = _history.pop_back()
		world_id = previous.world
		_show(previous.screen)
		return
	_history.append({"screen": screen, "world": world_id})
	world_id = next_world
	_show(destination)


func _clear_layer() -> void:
	for child: Node in layer.get_children():
		layer.remove_child(child)
		child.queue_free()


func _show(destination: String) -> void:
	screen = destination
	_pending_overlay = ""
	_clear_layer()
	var next_number: int = menus.next_level()
	var themed: int = world_id if screen in ["levels", "detail", "game"] else int(registry.get_level(next_number).world)
	RushSkin.set_world(themed)
	backdrop.set_world(themed)
	backdrop.dim = 0.0
	canvas.menu_number = next_number
	if screen == "game":
		canvas.present("play", run)
	else:
		canvas.present("home" if screen == "home" else "plain")
	if screen == "game":
		run_ui.run = run
		run_ui.hud(registry.get_world(world_id).name)
	else:
		menus.render(screen, world_id)
	_show_save_warning()
	RushAccessibility.prepare(layer, screen, run, bool(save.settings().large_text))
	_focus_first.call_deferred()


func _focus_first() -> void:
	var first: Button = null
	for child: Node in layer.find_children("*", "Button", true, false):
		if (
			child is Button
			and child.is_visible_in_tree()
			and not child.disabled
			and child.focus_mode != Control.FOCUS_NONE
		):
			if bool(child.get_meta("primary", false)):
				child.grab_focus()
				return
			if first == null:
				first = child
	if first != null:
		first.grab_focus()


func start_level(id: int, practice: bool = false) -> void:
	if not practice and not save.unlocked(id):
		return
	var mode: String = "practice" if practice else "standard"
	if not practice and (save.settings().guide or save.settings().slow_time):
		mode = "assisted"
	run = RunState.new(registry.get_level(id), mode)
	run.slow_time = bool(save.settings().slow_time)
	var resume: Dictionary = save.data.resume
	if not resume.is_empty() and int(resume.level) == id and str(resume.mode) == mode:
		run.checkpoint = mini(int(resume.stage), run.level.stages.size() - 1)
		run.checkpoint_color = int(resume.color)
		run.retry()
		run.elapsed = float(resume.get("elapsed", 0.0))
		run.taps = int(resume.get("taps", 0))
		run.deaths = int(resume.get("deaths", 0))
	world_id = int(run.level.world)
	sound.world = world_id
	_last_stage = run.stage_index
	_recorded = false
	_history.clear()
	_show("game")


func _run_action(action: String) -> void:
	if _quitting:
		return
	match action:
		"tap":
			if run.tap():
				sound.play("tap")
				canvas.on_launch()
		"pause":
			if run.status not in ["ready", "playing"]:
				return
			_pause_status = run.status
			run.status = "paused"
			_persist_checkpoint()
			_open_overlay("pause")
		"resume":
			run.status = _pause_status
			_show("game")
		"retry":
			run.retry()
			_last_stage = run.stage_index
			_recorded = false
			_show("game")
		"restart":
			save.data.resume = {}
			start_level(int(run.level.id), run.mode == "practice")
		"practice":
			save.data.resume = {}
			start_level(int(run.level.id), true)
		"next":
			save.data.resume = {}
			if int(run.level.id) < 100:
				start_level(int(run.level.id) + 1, run.mode == "practice" or run.mode == "assisted")
			else:
				_show("achievements")
		"worlds":
			_persist_checkpoint()
			menus.practice = run.mode != "standard"
			_show("worlds")


func _finish_run() -> void:
	if run.status == "complete":
		save.data.resume = {}
		var result: Dictionary = {"stars": run.stars(), "score": run.score(), "seconds": run.elapsed}
		run_ui.badge = _badge_for(result)
		save.record_result(int(run.level.id), result, run.mode != "standard")
		sound.play("complete")
		canvas.on_complete()
	else:
		_persist_checkpoint()
		sound.play("fail")
		canvas.on_fail()
	_pending_overlay = "complete" if run.status == "complete" else "failed"
	_overlay_delay = 0.0 if canvas.reduced_motion else (0.95 if run.status == "complete" else 0.7)
	if _overlay_delay <= 0.0:
		_tick_overlay(0.0)


func _open_overlay(kind: String) -> void:
	canvas.mode = "result"
	backdrop.dim = 0.3
	run_ui.overlay(kind)
	_show_save_warning()
	RushAccessibility.prepare(layer, "overlay", run, bool(save.settings().large_text))
	_focus_first.call_deferred()


## "FIRST CLEAR" / "NEW BEST" badge, judged against the record this result is about to replace.
func _badge_for(result: Dictionary) -> String:
	var records: Dictionary = save.data.practice if run.mode != "standard" else save.data.records
	var previous: Dictionary = records.get(str(int(run.level.id)), {})
	if previous.is_empty():
		return "FIRST CLEAR"
	if int(result.score) > int(previous.score) or int(result.stars) > int(previous.stars):
		return "NEW BEST"
	return ""


func _persist_checkpoint() -> void:
	if screen == "game" and run != null and run.status != "complete":
		save.data.resume = run.snapshot()
		if save.save() != OK or layer.has_node("SaveWarning"):
			_show_save_warning()


func _back_or_pause() -> void:
	if screen != "game":
		_navigate("back")
	elif run.status == "paused":
		_run_action("resume")
	elif run.status in ["failed", "complete"]:
		_run_action("worlds")
	else:
		_run_action("pause")


func _setting_changed(key: String, value: bool) -> void:
	save.set_setting(key, value)
	_apply_settings()
	_show_save_warning()
	if key == "large_text":
		_show(screen)


func _apply_settings() -> void:
	canvas.reduced_motion = RushAccessibility.prefers_reduced_motion(bool(save.settings().reduced_motion))
	RushSkin.calm = canvas.reduced_motion
	canvas.large_text = bool(save.settings().large_text)
	layer.set_meta("guide", bool(save.settings().guide))
	canvas.fx.calm = canvas.reduced_motion
	backdrop.calm = canvas.reduced_motion
	run_ui.calm = canvas.reduced_motion
	canvas.color_labels = bool(save.settings().color_labels)
	canvas.guide = bool(save.settings().guide)
	sound.enabled = bool(save.settings().sound)
	sound.music_enabled = bool(save.settings().music)
	sound.haptics = bool(save.settings().haptics)


func _show_save_warning() -> void:
	var previous: Node = layer.get_node_or_null("SaveWarning")
	if previous != null:
		layer.remove_child(previous)
		previous.queue_free()
	if not save.warning.is_empty():
		var banner: ColorRect = ColorRect.new()
		banner.name = "SaveWarning"
		banner.color = RushSkin.SURFACE
		banner.size = Vector2(480, 118)
		layer.add_child(banner)
		var warning_label: Label = RushSkin.label(banner, save.warning, Rect2(32, 10, 300, 98), 17, RushSkin.COLORS[1])
		warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		RushSkin.button(banner, "Retry", Rect2(350, 24, 98, 66), _retry_save)
	ReaderView.refresh(layer)


func _retry_save() -> void:
	save.save()
	_show_save_warning()


func _confirm_reset() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Reset local progress?"
	dialog.dialog_text = "All clears, stars and checkpoints on this device will be removed. Settings stay."
	dialog.ok_button_text = "Reset progress"
	dialog.confirmed.connect(
		func() -> void:
			save.reset_progress()
			_show("settings")
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(410, 180))
