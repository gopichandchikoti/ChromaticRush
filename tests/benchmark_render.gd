extends SceneTree

const App = preload("res://src/app.gd")
var app: App
var fixture: String
var worlds: Array[Dictionary] = []
var focus_resumes: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This benchmark requires actual native rendering; omit --headless")
		quit(1)
		return
	root.size = Vector2i(480, 900)
	fixture = "user://render-benchmark-%s" % Time.get_ticks_usec()
	app = App.new()
	app.save_root = fixture
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	app.sound.enabled = false
	app.sound.music_enabled = false
	app.sound.suspend(true)
	for world: int in range(1, 11):
		app.save.data.resume = {}
		app.start_level((world - 1) * 10 + 1, true)
		await create_timer(0.35).timeout
		worlds.append(await _sample(world, 2.0))
	var report: Dictionary = _report()
	var file: FileAccess = FileAccess.open("res://docs/evidence/balance_render_benchmark.json", FileAccess.WRITE)
	if file == null:
		printerr("Could not write native render benchmark")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	app.sound.suspend(true)
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	await process_frame
	for name: String in DirAccess.get_files_at(fixture):
		DirAccess.remove_absolute(fixture.path_join(name))
	DirAccess.remove_absolute(fixture)
	print(JSON.stringify(report.summary))
	quit(0)


func _sample(world: int, seconds: float) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	var next_tap: int = started
	var samples: Array[float] = []
	var draw_calls: int = 0
	var peak_sparks: int = 0
	var peak_shards: int = 0
	var low_quality_frames: int = 0
	while Time.get_ticks_usec() - started < seconds * 1_000_000.0:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
		draw_calls = maxi(draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if now >= next_tap:
			_drive()
			next_tap = now + 225_000
		if "--stress" in OS.get_cmdline_user_args():
			_stress()
		peak_sparks = maxi(peak_sparks, app.canvas.fx._sparks.size())
		peak_shards = maxi(peak_shards, app.canvas.fx._shards.size())
		low_quality_frames += 1 if app.canvas.fx.low_quality else 0
	var wall: float = (previous - started) / 1_000_000.0
	samples.sort()
	return {
		"world": world,
		"frames": samples.size(),
		"wall_seconds": wall,
		"rendered_fps": samples.size() / wall,
		"frame_ms_p50": _percentile(samples, 0.5),
		"frame_ms_p95": _percentile(samples, 0.95),
		"frame_ms_max": samples.back(),
		"max_draw_calls": draw_calls,
		"peak_sparks": peak_sparks,
		"peak_shards": peak_shards,
		"low_quality_frames": low_quality_frames
	}


func _drive() -> void:
	if app.run.status == "paused":
		app._run_action("resume")
		focus_resumes += 1
	if app.run.status == "failed":
		app._run_action("retry")
	elif app.run.status == "complete":
		app.save.data.resume = {}
		app.start_level(int(app.run.level.id), true)
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	app._input(event)


func _stress() -> void:
	var fx: Effects = app.canvas.fx
	fx.burst(Vector2(240, 500), RushSkin.COLORS[app.run.color], 22, 180.0)
	fx.ring(Vector2(240, 500), RushSkin.accent)
	fx.shatter(Vector2(240, 500), RushSkin.COLORS[app.run.color])


func _percentile(samples: Array[float], fraction: float) -> float:
	return samples[clampi(int(ceil(samples.size() * fraction)) - 1, 0, samples.size() - 1)]


func _report() -> Dictionary:
	var frames: int = 0
	var seconds: float = 0.0
	var worst: float = 0.0
	for world: Dictionary in worlds:
		frames += int(world.frames)
		seconds += float(world.wall_seconds)
		worst = maxf(worst, float(world.frame_ms_p95))
	return {
		"date": "2026-11-05",
		"engine": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"driver": DisplayServer.get_name(),
		"platform": OS.get_name(),
		"viewport": [480, 900],
		"stress": "--stress" in OS.get_cmdline_user_args(),
		"warmup_seconds_per_world": 0.35,
		"scope": "Native desktop App, timed inputs; optional synthetic capped feedback; not phone performance",
		"summary":
		{
			"worlds": worlds.size(),
			"frames": frames,
			"measured_wall_seconds": seconds,
			"aggregate_rendered_fps": frames / seconds,
			"worst_world_p95_frame_ms": worst,
			"focus_resumes": focus_resumes
		},
		"worlds": worlds
	}
