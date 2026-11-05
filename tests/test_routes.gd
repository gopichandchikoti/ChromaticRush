extends SceneTree

const Registry = preload("res://src/domain/level_registry.gd")
const Run = preload("res://src/domain/run_state.gd")
const STEP: float = 1.0 / 120.0
const MAX_WAIT_TICKS: int = 600
const TRIAL_TICKS: int = 240
const TAP_INTERVAL: float = 0.22
const STATE_FIELDS: Array[String] = [
	"stage_index",
	"contact",
	"color",
	"altitude",
	"velocity",
	"elapsed",
	"taps",
	"deaths",
	"checkpoint",
	"checkpoint_color",
	"status",
	"mode",
	"slow_time",
	"last_event",
	"_accumulator",
	"_tap_cooldown"
]
var checks: int = 0
var failures: Array[String] = []
var candidate_count: int = 0


func _initialize() -> void:
	var started: int = Time.get_ticks_msec()
	var registry: LevelRegistry = Registry.new()
	_check(registry.errors.is_empty(), "Registry: %s" % str(registry.errors))
	_check(registry.levels.size() == 100, "Exactly one hundred definitions")
	var routes: Array[Dictionary] = []
	for level: Dictionary in registry.levels:
		var result: Dictionary = _solve(level)
		routes.append(result)
		if bool(result.complete):
			_verify_replay(level, result)
	var report: Dictionary = {
		"engine": Engine.get_version_info().string,
		"method": "Actual RunState input search from the real ready state; 120Hz; wait 0–20s; tap every 0.22s",
		"input_replay": "Timestamped tap events split render frames at 30, 60 and 120 FPS",
		"levels": routes,
		"checks": checks,
		"candidates": candidate_count,
		"failures": failures,
		"runtime_ms": Time.get_ticks_msec() - started
	}
	_write_report(report)
	print(
		JSON.stringify(
			{
				"suite": "runtime routes",
				"levels": routes.size(),
				"checks": checks,
				"candidates": candidate_count,
				"failures": failures.size(),
				"runtime_ms": report.runtime_ms
			}
		)
	)
	quit(1 if not failures.is_empty() else 0)


func _solve(level: Dictionary) -> Dictionary:
	var run: RunState = Run.new(level)  # real initial state: "ready", clock already running
	var launches: Array[Dictionary] = []
	var schedule: Array[float] = []
	for stage_number: int in range(level.stages.size()):
		var attempt: Dictionary = _search_stage(run)
		if attempt.is_empty():
			_check(false, "Level %d stage %d has no searched route" % [int(level.id), stage_number + 1])
			return {"id": int(level.id), "complete": false, "failed_stage": stage_number + 1}
		run = attempt.run
		launches.append(
			{
				"stage": stage_number + 1,
				"wait_seconds": attempt.wait,
				"tap_times": attempt.tap_times,
				"end_seconds": snappedf(run.elapsed, 0.000001)
			}
		)
		for tap_time: float in attempt.tap_times:
			schedule.append(tap_time)
		_check(run.stage_index == stage_number + 1, "Stage advances by one matching route")
	_check(run.status == "complete", "Level %d completes" % int(level.id))
	_check(run.deaths == 0 and run.taps > 0, "Route uses taps with zero collision bypasses")
	return {
		"id": int(level.id),
		"name": str(level.name),
		"complete": run.status == "complete",
		"seconds": snappedf(run.elapsed, 0.000001),
		"stars": run.stars(),
		"taps": run.taps,
		"launches": launches,
		"tap_schedule": schedule
	}


func _search_stage(source: RunState) -> Dictionary:
	for wait_tick: int in range(MAX_WAIT_TICKS + 1):
		candidate_count += 1
		var candidate: RunState = _clone(source)
		var wait_seconds: float = wait_tick / 30.0
		for _tick: int in range(wait_tick * 4):
			candidate.advance(STEP)
		var taps: Array[float] = _launch_candidate(candidate, source.stage_index)
		if candidate.stage_index > source.stage_index:
			return {"run": candidate, "wait": wait_seconds, "tap_times": taps}
	return {}


func _launch_candidate(candidate: RunState, start_stage: int) -> Array[float]:
	var taps: Array[float] = []
	var next_tap: float = 0.0
	for trial_tick: int in range(TRIAL_TICKS):
		var trial_time: float = trial_tick * STEP
		if trial_time + 0.000001 >= next_tap:
			if candidate.tap():
				taps.append(candidate.elapsed)
			next_tap = trial_time + TAP_INTERVAL
		candidate.advance(STEP)
		if candidate.status == "failed" or candidate.stage_index > start_stage:
			break
	return taps


func _clone(source: RunState) -> RunState:
	var candidate: RunState = Run.new(source.level)
	for field: String in STATE_FIELDS:
		candidate.set(field, source.get(field))
	return candidate


func _verify_replay(level: Dictionary, result: Dictionary) -> void:
	for fps: int in [30, 60, 120]:
		var replay: RunState = Run.new(level)
		var schedule: Array = result.tap_schedule
		var input_index: int = 0
		var clock: float = 0.0
		var deadline: float = float(result.seconds) + 1.0
		while clock < deadline and replay.is_live():
			var frame_end: float = clock + 1.0 / fps
			while input_index < schedule.size() and float(schedule[input_index]) < frame_end + 0.0000001:
				var input_time: float = float(schedule[input_index])
				replay.advance(maxf(0.0, input_time - clock))
				clock = input_time
				replay.tap()
				input_index += 1
			replay.advance(maxf(0.0, frame_end - clock))
			clock = frame_end
		_check(replay.status == "complete", "Level %d input replay at %d FPS" % [int(level.id), fps])
		_check(replay.deaths == 0, "No wrong-color bypass at %d FPS" % fps)
		_check(replay.taps == int(result.taps), "Replay preserves input count at %d FPS" % fps)


func _write_report(report: Dictionary) -> void:
	var path: String = "res://docs/evidence/route_audit.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "Could not write route audit: %s" % str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr(message)
