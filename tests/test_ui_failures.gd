extends SceneTree

const App = preload("res://src/app.gd")
const STEP: float = 1.0 / 120.0

var _app: App
var _root_path: String
var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_root_path = "user://ui-failure-tests-%s" % Time.get_ticks_usec()
	_app = App.new()
	_app.save_root = _root_path
	_app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_app)
	_app.set_process(false)
	_app.sound.suspend(true)
	await _frames()
	await _checkpoint_failure_and_recovery()
	await _assisted_result_labels()
	_app.sound.suspend(true)
	await create_timer(0.15).timeout
	_app.queue_free()
	await _frames()
	_cleanup(_root_path)
	print(JSON.stringify({"suite": "native UI failure paths", "checks": _checks, "failures": _failures}))
	quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr(message)


func _frames() -> void:
	await process_frame
	await process_frame


func _checkpoint_failure_and_recovery() -> void:
	var blocker: String = _root_path.path_join("storage-blocker")
	DirAccess.make_dir_recursive_absolute(_root_path)
	var file: FileAccess = FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("Isolated storage-failure fixture, not player data.")
	file.close()
	var store := RushSave.new(blocker.path_join("nested"))
	_app.save = store
	_app.menus.save = store
	_app.start_level(1)
	await _frames()
	var route: Dictionary = (
		JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/route_audit.json")).levels[0]
	)
	var index: int = 0
	var clock: float = 0.0
	while _app.run.checkpoint == 0 and clock < float(route.seconds) + 0.5:
		if index < route.tap_schedule.size() and float(route.tap_schedule[index]) <= clock + 0.0000001:
			_app._run_action("tap")
			index += 1
		var before: int = _app.run.stage_index
		_app._process(STEP)
		clock += STEP
		if _app.run.stage_index > before:
			_check(_app.layer.has_node("SaveWarning"), "Checkpoint write failure appears in the same application tick")
		if _app.run.status == "failed":
			break
	_check(_app.run.checkpoint > 0, "Actual input replay earns a real authored checkpoint")
	_check(not store.warning.is_empty(), "Failed checkpoint write retains a storage warning")
	_check(store.data.resume == _app.run.snapshot(), "Failed write retains the exact cumulative checkpoint in memory")
	DirAccess.remove_absolute(blocker)
	await _press("Retry")
	_check(
		store.warning.is_empty() and not _app.layer.has_node("SaveWarning"),
		"Retry after storage recovery clears warning"
	)
	var reloaded := RushSave.new(blocker.path_join("nested"))
	_check(reloaded.load_save() == OK, "Recovered checkpoint is readable from actual disk")
	var expected: Dictionary = _app.run.snapshot()
	var actual: Dictionary = reloaded.data.resume
	_check(is_equal_approx(float(actual.elapsed), float(expected.elapsed)), "Retry preserves elapsed time precision")
	for field: String in ["level", "stage", "color", "taps", "deaths"]:
		_check(int(actual[field]) == int(expected[field]), "Retry preserves integer checkpoint field: " + field)
	_check(str(actual.mode) == str(expected.mode), "Retry preserves checkpoint mode")


func _assisted_result_labels() -> void:
	_app.save.data.resume = {}
	_app.start_level(1)
	_app.run.mode = "assisted"
	_app._open_overlay("complete")
	await _frames()
	_check(_button("NEXT IN PRACTICE") != null, "Assisted completion explicitly labels next mode")
	_check(_label_contains("Next continues in practice."), "Assisted completion explains the transition")
	_check(_label_contains("Assisted result saved separately"), "Assisted result does not claim standard record")
	await _press("NEXT IN PRACTICE")
	_check(_app.run.level.id == 2 and _app.run.mode == "practice", "Explicit assisted next action opens practice")
	_app.save.data.resume = {}
	_app.start_level(100, true)
	_app._open_overlay("complete")
	await _frames()
	_check(_button("VIEW ACHIEVEMENTS") != null, "Final practice route offers a neutral records action")
	_check(_button("ALL WORLDS CLEARED") == null, "Final practice route cannot claim all standard worlds cleared")
	_check(_label_contains("Practice result saved separately"), "Practice result remains clearly labeled")
	_check(_app.save.totals().completed == 0, "Presentation-only result fixtures award no production records")


func _button(prefix: String) -> Button:
	for node: Node in _app.layer.find_children("*", "Button", true, false):
		if node is Button and node.is_visible_in_tree() and node.text.begins_with(prefix):
			return node
	return null


func _label_contains(fragment: String) -> bool:
	for node: Node in _app.layer.find_children("*", "Label", true, false):
		if node is Label and node.is_visible_in_tree() and node.text.contains(fragment):
			return true
	return false


func _press(prefix: String) -> void:
	var button: Button = _button(prefix)
	_check(button != null and not button.disabled, "Actual native action is available: " + prefix)
	if button != null and not button.disabled:
		button.pressed.emit()
	await _frames()


func _cleanup(folder: String) -> void:
	for child: String in DirAccess.get_directories_at(folder):
		_cleanup(folder.path_join(child))
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
