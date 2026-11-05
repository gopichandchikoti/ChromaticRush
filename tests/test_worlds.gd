extends SceneTree

const App = preload("res://src/app.gd")
const STEP: float = 1.0 / 120.0
var app: App
var checks: int = 0
var failures: Array[String] = []
var fixture: String
var captures: Array[String] = []
var focus_resumes: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	fixture = "user://world-smoke-%s" % Time.get_ticks_usec()
	app = App.new()
	app.save_root = fixture
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	app.set_process(false)
	app.sound.enabled = false
	app.sound.music_enabled = false
	app.sound.suspend(true)
	await process_frame
	var audit: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/route_audit.json"))
	_check(audit is Dictionary and audit.get("levels", []).size() == 100, "All-level route evidence is available")
	if failures.is_empty():
		for world: int in range(1, 11):
			await _play_world(world, audit.levels[(world - 1) * 10])
	_check(app.save.totals().completed == 0, "Representative practice clears award no standard progress")
	_check(app.save.data.practice.size() == 10, "All ten actual practice results persist separately")
	var manifest := {
		"method": "Native App input replay, first authored route in each world; isolated practice saves",
		"checks": checks,
		"failures": failures,
		"captures": captures
	}
	manifest["focus_resumes"] = focus_resumes
	var file: FileAccess = FileAccess.open("res://docs/evidence/world_smoke.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest, "\t") + "\n")
		file.close()
	app.queue_free()
	await process_frame
	await process_frame
	for filename: String in DirAccess.get_files_at(fixture):
		DirAccess.remove_absolute(fixture.path_join(filename))
	DirAccess.remove_absolute(fixture)
	print(
		JSON.stringify(
			{"suite": "native world journeys", "checks": checks, "failures": failures, "screenshots": captures.size()}
		)
	)
	quit(1 if not failures.is_empty() else 0)


func _play_world(world: int, route: Dictionary) -> void:
	var id: int = (world - 1) * 10 + 1
	app.save.data.resume = {}
	app.start_level(id, true)
	_check(app.run.level.id == id and app.world_id == world, "World %d starts its authored route" % world)
	_check(RushSkin.world == world, "World %d applies the correct visual identity" % world)
	await _capture(world, "play")
	var clock: float = 0.0
	for time: float in route.tap_schedule:
		while clock < time - 0.0000001:
			var delta: float = minf(STEP, time - clock)
			app._process(delta)
			app.canvas._process(delta)
			clock += delta
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		event.pressed = true
		app._input(event)
	for _tick: int in range(120):
		app._process(STEP)
		app.canvas._process(STEP)
		if app.run.status in ["complete", "failed"]:
			break
	_check(
		app.run.status == "complete",
		(
			"World %d completes (status=%s, gate=%d, seconds=%.3f)"
			% [world, app.run.status, app.run.stage_index + 1, app.run.elapsed]
		)
	)
	_check(app.save.data.practice.has(str(id)), "World %d writes its earned result" % world)
	app._process(1.0)
	await _capture(world, "result")


func _capture(world: int, state: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	if DisplayServer.get_name() == "headless":
		_check(false, "World captures require a rendering display")
		return
	await process_frame
	await process_frame
	await create_timer(1.0).timeout
	if state == "play" and app.run.status == "paused":
		app._run_action("resume")
		focus_resumes += 1
		await process_frame
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://docs/evidence/world-%02d-%s.png" % [world, state]
	var result: Error = root.get_texture().get_image().save_png(path)
	_check(result == OK, "World %d %s screenshot exists" % [world, state])
	captures.append(path)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr(message)
