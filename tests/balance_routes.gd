extends SceneTree

const Sim = preload("res://tests/balance_simulation.gd")
var simulation: Sim = Sim.new()
var failures: Array[String] = []
var levels: Array[Dictionary] = []


func _initialize() -> void:
	var started: int = Time.get_ticks_msec()
	var registry := LevelRegistry.new()
	var audit: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/route_audit.json"))
	if not registry.errors.is_empty() or not audit is Dictionary:
		printerr("A valid registry and completed route audit are required")
		quit(1)
		return
	for index: int in range(registry.levels.size()):
		levels.append(_measure(registry.levels[index], audit.levels[index]))
	var report: Dictionary = _report(registry)
	report["runtime_ms"] = Time.get_ticks_msec() - started
	report["search_candidates"] = simulation.candidates
	var file: FileAccess = FileAccess.open("res://docs/evidence/balance_routes.json", FileAccess.WRITE)
	if file == null:
		printerr("Could not write balance report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print(JSON.stringify(report.summary))
	print("Balance report runtime: %d ms" % report.runtime_ms)
	quit(1 if not failures.is_empty() else 0)


func _measure(level: Dictionary, route: Dictionary) -> Dictionary:
	var schedule: Array[float] = _times(route.tap_schedule)
	var deadline: float = float(route.seconds) + 2.0
	var baseline: RunState = simulation.replay(level, schedule, deadline)
	if baseline.status != "complete":
		failures.append("Baseline level %d no longer completes" % int(level.id))
	var row: Dictionary = {
		"id": int(level.id),
		"world": int(level.world),
		"name": level.name,
		"stages": level.stages.size(),
		"par_seconds": level.par,
		"baseline_seconds": baseline.elapsed,
		"baseline_stars": baseline.stars(),
		"par_slack_seconds": float(level.par) - baseline.elapsed
	}
	var jitter: Dictionary = {}
	for milliseconds: int in [25, 50, 100]:
		jitter[str(milliseconds)] = _jitter(level, schedule, deadline, milliseconds / 1000.0)
	row["jitter"] = jitter
	var missed: Array[float] = schedule.duplicate()
	missed.remove_at(missed.size() / 2)
	var dropped: RunState = simulation.replay(level, missed, deadline)
	row["missed_middle_tap"] = {
		"status": dropped.status,
		"checkpoint": dropped.checkpoint,
		"stage": dropped.stage_index,
		"recovery": simulation.recover(dropped)
	}
	var robust: Dictionary = simulation.solve(RunState.new(level), 0.1)
	row["centered_100ms_launch_route"] = robust
	return row


func _jitter(level: Dictionary, schedule: Array[float], deadline: float, amplitude: float) -> Dictionary:
	var result: Dictionary = {
		"global_shift_passes": 0,
		"global_shift_trials": 2,
		"independent_passes": 0,
		"independent_trials": 10,
		"alternating_passes": 0,
		"alternating_trials": 2
	}
	for sign_value: float in [-1.0, 1.0]:
		var shifted: Array[float] = []
		var alternating: Array[float] = []
		for index: int in range(schedule.size()):
			shifted.append(maxf(0.0, schedule[index] + amplitude * sign_value))
			alternating.append(maxf(0.0, schedule[index] + amplitude * sign_value * (-1.0 if index % 2 else 1.0)))
		shifted.sort()
		alternating.sort()
		result.global_shift_passes += _completes(level, shifted, deadline)
		result.alternating_passes += _completes(level, alternating, deadline)
	for seed_value: int in range(10):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(level.id) * 1000 + seed_value
		var times: Array[float] = []
		for time: float in schedule:
			times.append(maxf(0.0, time + rng.randf_range(-amplitude, amplitude)))
		times.sort()
		result.independent_passes += _completes(level, times, deadline)
	return result


func _completes(level: Dictionary, schedule: Array[float], deadline: float) -> int:
	return 1 if simulation.replay(level, schedule, deadline).status == "complete" else 0


func _times(raw: Array) -> Array[float]:
	var result: Array[float] = []
	for value: Variant in raw:
		result.append(float(value))
	return result


func _report(registry: LevelRegistry) -> Dictionary:
	var jitter: Dictionary = {}
	for milliseconds: String in ["25", "50", "100"]:
		var total: Dictionary = {
			"global_shift_passes": 0,
			"global_shift_trials": 0,
			"independent_passes": 0,
			"independent_trials": 0,
			"alternating_passes": 0,
			"alternating_trials": 0
		}
		for row: Dictionary in levels:
			for key: String in total:
				total[key] += int(row.jitter[milliseconds][key])
		jitter[milliseconds] = total
	var centered: int = 0
	var recovered: int = 0
	var preserved: int = 0
	for row: Dictionary in levels:
		centered += 1 if row.centered_100ms_launch_route.complete else 0
		recovered += 1 if row.missed_middle_tap.recovery.complete else 0
		preserved += 1 if row.missed_middle_tap.recovery.preserved else 0
	return {
		"date": "2026-11-05",
		"engine": Engine.get_version_info().string,
		"method": "Actual production RunState; exact timestamped input perturbations; fixed 120 Hz steps",
		"caution": "Earliest-success schedules hug boundaries; global schedule perturbation is not human difficulty",
		"summary":
		{
			"levels": levels.size(),
			"baseline_failures": failures.size(),
			"jitter": jitter,
			"centered_100ms_launch_routes": centered,
			"checkpoint_recoveries": recovered,
			"checkpoint_statistics_preserved": preserved
		},
		"worlds": _worlds(registry),
		"levels": levels,
		"failures": failures
	}


func _worlds(registry: LevelRegistry) -> Array[Dictionary]:
	var worlds: Array[Dictionary] = []
	for world: Dictionary in registry.worlds:
		var row: Dictionary = {
			"id": world.id,
			"name": world.name,
			"mean_stages": 0.0,
			"mean_par_seconds": 0.0,
			"mean_searched_seconds": 0.0,
			"mean_par_slack_seconds": 0.0,
			"centered_100ms_routes": 0,
			"three_star_baselines": 0
		}
		for level: Dictionary in levels:
			if int(level.world) != int(world.id):
				continue
			row.mean_stages += float(level.stages) / 10.0
			row.mean_par_seconds += float(level.par_seconds) / 10.0
			row.mean_searched_seconds += float(level.baseline_seconds) / 10.0
			row.mean_par_slack_seconds += float(level.par_slack_seconds) / 10.0
			row.centered_100ms_routes += 1 if level.centered_100ms_launch_route.complete else 0
			row.three_star_baselines += 1 if level.baseline_stars == 3 else 0
		worlds.append(row)
	return worlds
