extends RefCounted

const Run = preload("res://src/domain/run_state.gd")
const STEP: float = 1.0 / 120.0
const FIELDS: Array[String] = [
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
var candidates: int = 0


func replay(level: Dictionary, schedule: Array[float], deadline: float) -> RunState:
	var run: RunState = Run.new(level)
	var clock: float = 0.0
	for target: float in schedule:
		while clock < target - 0.0000001 and run.is_live():
			var delta: float = minf(STEP, target - clock)
			run.advance(delta)
			clock += delta
		if not run.is_live():
			return run
		run.tap()
	while clock < deadline and run.is_live():
		run.advance(STEP)
		clock += STEP
	return run


func recover(run: RunState) -> Dictionary:
	var prior_elapsed: float = run.elapsed
	var prior_taps: int = run.taps
	var prior_deaths: int = run.deaths
	var checkpoint: int = run.checkpoint
	var checkpoint_color: int = run.checkpoint_color
	run.retry()
	var preserved: bool = run.stage_index == checkpoint and run.color == checkpoint_color
	preserved = preserved and run.elapsed == prior_elapsed and run.taps == prior_taps and run.deaths == prior_deaths
	var result: Dictionary = solve(run, 0.0)
	return {
		"preserved": preserved,
		"complete": result.complete,
		"checkpoint": checkpoint,
		"deaths": prior_deaths,
		"seconds": result.seconds,
		"stars": result.stars
	}


func solve(source: RunState, tolerance: float) -> Dictionary:
	var run: RunState = source
	var schedule: Array[float] = []
	var stages: Array[Dictionary] = []
	while run.stage_index < run.level.stages.size():
		var result: Dictionary = _find(run, tolerance)
		if result.is_empty():
			return {
				"complete": false,
				"stage": run.stage_index + 1,
				"kind": run.stage().kind,
				"seconds": run.elapsed,
				"stars": run.stars(),
				"schedule": schedule,
				"stages": stages
			}
		stages.append({"stage": run.stage_index + 1, "kind": run.stage().kind, "wait": result.wait})
		run = result.run
		for time: float in result.times:
			schedule.append(time)
	return {
		"complete": run.status == "complete",
		"seconds": run.elapsed,
		"stars": run.stars(),
		"schedule": schedule,
		"stages": stages
	}


func _find(source: RunState, tolerance: float) -> Dictionary:
	for tick: int in range(int(ceil(tolerance * 30.0)), 601):
		var wait: float = tick / 30.0
		var center: Dictionary = _trial(source, wait)
		if center.run.stage_index <= source.stage_index:
			continue
		var safe: bool = true
		if tolerance > 0.0:
			for offset: int in [-4, -3, -2, -1, 1, 2, 3, 4]:
				var nearby: Dictionary = _trial(source, wait + offset * tolerance / 4.0)
				if nearby.run.stage_index <= source.stage_index:
					safe = false
					break
		if safe:
			center.wait = wait
			return center
	return {}


func _trial(source: RunState, wait: float) -> Dictionary:
	candidates += 1
	var run: RunState = Run.new(source.level)
	for key: String in FIELDS:
		run.set(key, source.get(key))
	for _tick: int in range(int(round(wait / STEP))):
		run.advance(STEP)
	var times: Array[float] = []
	for tick: int in range(240):
		if tick % 27 == 0 and run.tap():
			times.append(run.elapsed)
		run.advance(STEP)
		if run.status == "failed" or run.stage_index > source.stage_index:
			break
	return {"run": run, "times": times}
