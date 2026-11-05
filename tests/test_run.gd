extends SceneTree

const Run = preload("res://src/domain/run_state.gd")
const STEP: float = 1.0 / 120.0
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_test_input_and_pause()
	_test_waiting_clock()
	_test_fixed_steps()
	_test_wrong_color_frames()
	_test_checkpoint_retry()
	_test_chain_contacts()
	_test_reverse()
	_test_scoring()
	print(JSON.stringify({"suite": "run simulation", "checks": checks, "failures": failures}))
	quit(1 if failures else 0)


func _barrier(kind: String = "ring", offset: int = 0, phase: float = 0.0, speed: float = 0.6) -> Dictionary:
	return {
		"kind": kind,
		"gap": 145,
		"speed": speed,
		"phase": phase,
		"offset": offset,
		"color": 0,
		"checkpoint": false,
		"width": 0.42,
		"drift": 42
	}


func _level(stages: Array[Dictionary], color: int = 0, par: float = 5.0) -> Dictionary:
	return {"id": 1, "name": "Synthetic unit-test fixture", "stages": stages, "start_color": color, "par": par}


func _test_input_and_pause() -> void:
	var run: RunState = Run.new(_level([_barrier()]))
	run.advance(0.5)
	_check(run.status == "ready" and run.altitude == 0.0, "Ready run keeps the orb on the perch")
	_check(is_equal_approx(run.elapsed, 0.5), "Ready run lets the gate keep moving so a window can be awaited")
	_check(run.tap(), "First tap starts the run")
	_check(run.velocity == Run.IMPULSE and run.taps == 1, "Tap immediately applies impulse")
	_check(not run.tap() and run.taps == 1, "Duplicate input respects cooldown")
	run.advance(0.099)
	_check(not run.tap(), "Tap before 100ms cooldown is rejected")
	run.advance(0.001)
	_check(run.tap(), "Tap exactly at 100ms is accepted")
	run.status = "paused"
	var before: float = run.elapsed
	var altitude: float = run.altitude
	run.advance(0.5)
	_check(run.elapsed == before and run.altitude == altitude, "Pause freezes physics and clock")
	_check(not run.tap(), "Pause rejects gameplay input")
	for state: String in ["failed", "complete"]:
		run.status = state
		_check(not run.tap(), "%s run rejects taps" % state)
		run.advance(0.5)
		_check(run.elapsed == before, "%s run does not advance" % state)


func _test_waiting_clock() -> void:
	# Orb starts on a colour that the ring does not show at t=0, so an immediate launch must fail ...
	var impatient: RunState = Run.new(_level([_barrier()], 3))
	impatient.tap()
	impatient.advance(0.5)
	_check(impatient.status == "failed", "Launching at once into the wrong colour fails")
	_check(impatient.fail_color != 3 and impatient.fail_open, "Failure records the colour the gate actually showed")
	# ... but waiting on the perch for the matching window (the clock runs in "ready") then launching clears it.
	var patient: RunState = Run.new(_level([_barrier()], 3))
	var wait: float = GateRules.next_window(patient.stage(), 0.0, patient.color, 0)
	_check(wait > 0.0, "The fixture really needs a wait before its colour arrives")
	for _frame: int in range(int((wait + 0.5) / 0.05) + 1):  # advance() caps a single step at 0.5s
		patient.advance(0.05)
	_check(patient.status == "ready" and patient.deaths == 0, "Waiting on the perch is safe")
	patient.tap()
	patient.advance(1.0)
	_check(patient.status == "complete" and patient.deaths == 0, "A launch timed from the perch clears the gate")
	_check(patient.cleared_color == 3 and str(patient.cleared_stage.kind) == "ring", "Clear is recorded for the UI")
	var retried: RunState = Run.new(_level([_barrier()], 3))
	retried.tap()
	retried.advance(0.5)
	retried.retry()
	var resumed_at: float = retried.elapsed
	retried.advance(0.25)
	_check(
		retried.status == "ready" and is_equal_approx(retried.elapsed, resumed_at + 0.25),
		"After Try Again the gate keeps moving while the orb waits"
	)


func _test_fixed_steps() -> void:
	var whole: RunState = Run.new(_level([_barrier()], 1))
	var split: RunState = Run.new(_level([_barrier()], 1))
	whole.status = "playing"
	split.status = "playing"
	whole.advance(0.5)
	for _tick: int in range(60):
		split.advance(STEP)
	_check(is_equal_approx(whole.elapsed, split.elapsed), "Whole and split delta preserve simulation time")
	_check(is_equal_approx(whole.elapsed, 0.5), "Sixty fixed ticks equal half a second")
	_check(whole.altitude == 0.0 and whole.velocity == 0.0, "Waiting orb rests on its safety perch")
	var fractional: RunState = Run.new(_level([_barrier()], 1))
	fractional.status = "playing"
	for _tick: int in range(60):
		fractional.advance(STEP * 0.37)
		fractional.advance(STEP * 0.63)
	_check(is_equal_approx(fractional.elapsed, whole.elapsed), "Sub-tick deltas accumulate without lost boundaries")
	var capped: RunState = Run.new(_level([_barrier()], 1))
	capped.status = "playing"
	capped.advance(4.0)
	_check(is_equal_approx(capped.elapsed, 0.5), "Long frame is bounded to prevent unbounded catch-up")
	var slow: RunState = Run.new(_level([_barrier()], 1), "practice")
	slow.status = "playing"
	slow.slow_time = true
	slow.advance(0.5)
	_check(is_equal_approx(slow.elapsed, 0.35), "Slow assist advances simulation at seventy percent")
	_check(slow.mode == "practice", "Practice mode remains explicit")


func _test_wrong_color_frames() -> void:
	for fps: int in [30, 60, 120]:
		var run: RunState = Run.new(_level([_barrier()], 1))
		run.tap()
		for _frame: int in range(fps):
			run.advance(1.0 / fps)
		_check(run.status == "failed" and run.deaths == 1, "Wrong color fails at %d FPS" % fps)
		_check(run.stage_index == 0, "Wrong color never advances a stage at %d FPS" % fps)
		_check(run.elapsed < 0.5, "Swept failure occurs on first contact at %d FPS" % fps)
	var large: RunState = Run.new(_level([_barrier()], 1))
	large.tap()
	large.advance(0.5)
	_check(large.status == "failed" and large.stage_index == 0, "Large frame cannot tunnel through wrong color")


func _test_checkpoint_retry() -> void:
	var switch_gate: Dictionary = _barrier("switch", 3)
	switch_gate.color = 2
	switch_gate.checkpoint = true
	var run: RunState = Run.new(_level([switch_gate, _barrier("ring", 2), _barrier()]))
	_fly(run, 2.0)
	_check(run.status == "failed" and run.stage_index == 2, "Run matches switch and second stage before failing third")
	_check(run.color == 2, "Matched switch changes the orb identity")
	_check(run.checkpoint == 1 and run.checkpoint_color == 2, "Checkpoint captures post-switch identity")
	var before: float = run.elapsed
	var tap_count: int = run.taps
	var snapshot: Dictionary = run.snapshot()
	_check(
		(
			snapshot
			== {
				"level": 1,
				"stage": 1,
				"color": 2,
				"mode": "standard",
				"elapsed": before,
				"taps": tap_count,
				"deaths": 1
			}
		),
		"Snapshot stores checkpoint rather than unearned stage progress"
	)
	run.retry()
	_check(run.status == "ready" and run.stage_index == 1, "Retry returns to last earned checkpoint")
	_check(run.altitude == 0.0 and run.velocity == 0.0 and run.contact == 0, "Retry clears transient flight state")
	_check(run.color == 2 and run.deaths == 1, "Retry retains checkpoint color and death count")
	_check(run.elapsed == before and run.taps == tap_count, "Retry cannot erase time or taps")
	_check(run.tap(), "Retry resets input cooldown")
	_check(run.stars() == 2, "A death cannot award a perfect three-star run")


func _test_chain_contacts() -> void:
	var good: RunState = Run.new(_level([_barrier("chain", 0, 0.2)]))
	good.tap()
	var saw_first: bool = false
	for tick: int in range(120):
		if tick > 0 and tick % 27 == 0:
			good.tap()
		good.advance(STEP)
		if good.contact == 1 and not saw_first:
			saw_first = true
			_check(
				good.stage_index == 0 and good.status == "playing", "First chain contact does not complete the stage"
			)
		if good.status == "complete":
			break
	_check(saw_first and good.status == "complete", "Both matched chain contacts complete the route")
	var bad: RunState = Run.new(_level([_barrier("chain", 0, 0.85, 1.5)]))
	_fly(bad, 1.0)
	_check(bad.status == "failed" and bad.contact == 1, "Second chain contact independently rejects a wrong color")
	_check(bad.stage_index == 0, "Failed second contact cannot award completion")


func _test_reverse() -> void:
	var run: RunState = Run.new(_level([_barrier("reverse"), _barrier()]))
	_check(run.direction() == -1.0, "Reverse stage advertises descending world direction")
	run.tap()
	run.advance(0.1)
	_check(
		run.altitude > 0.0 and run.altitude * run.direction() < 0.0,
		"Tap propels toward the descending exit in mirrored world coordinates"
	)
	_fly(run, 1.0)
	_check(run.stage_index >= 1 and run.direction() == 1.0, "Leaving reverse stage restores upward direction")


func _test_scoring() -> void:
	var run: RunState = Run.new(_level([_barrier()], 0, 5.0))
	run.elapsed = 5.0
	_check(run.stars() == 3, "Zero deaths at exact par earns three stars")
	var perfect_score: int = run.score()
	run.elapsed = 5.001
	_check(run.stars() == 2 and run.score() < perfect_score, "Over-par completion earns two stars")
	run.deaths = 2
	_check(run.stars() == 2, "Two deaths retain two stars")
	run.deaths = 3
	_check(run.stars() == 1, "Three deaths earn one star")
	run.elapsed = 100000.0
	run.deaths = 1000
	_check(run.score() == 100, "Score remains bounded above zero on long retry runs")


func _fly(run: RunState, seconds: float) -> void:
	for tick: int in range(ceili(seconds / STEP)):
		if tick % 27 == 0:
			run.tap()
		run.advance(STEP)
		if run.status in ["complete", "failed"]:
			break


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(message)
