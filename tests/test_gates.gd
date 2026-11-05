extends SceneTree

const Rules = preload("res://src/domain/gate_rules.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	for kind: String in Rules.KINDS:
		_test_gate(kind)
	for fps: int in [30, 60, 120]:
		var delta: float = 1.0 / fps
		var crossing: float = Rules.crossing_time(120.0, 180.0, 150.0, 2.0, delta)
		check(is_equal_approx(crossing, 2.0 - delta / 2.0), "Interpolated %d FPS contact" % fps)
	check(Rules.crossing_time(0.0, 800.0, 150.0, 0.5, 0.5) < 0.1, "Large swept movement")
	print(JSON.stringify({"suite": "gate rules", "checks": checks, "failures": failures}))
	quit(1 if failures else 0)


func _test_gate(kind: String) -> void:
	var barrier: Dictionary = {"kind": kind, "gap": 170, "speed": 1.1, "phase": 0.3, "offset": 1}
	var observed: Dictionary = {}
	for tick: int in range(2400):
		var time: float = tick / 120.0
		var color: int = Rules.sample(barrier, time)
		observed[color] = true
		check(color >= 0 and color <= 3, "%s valid color" % kind)
		if Rules.is_open(barrier, time):
			check(Rules.matches(barrier, time, color), "%s matching contact" % kind)
			check(not Rules.matches(barrier, time, (color + 1) % 4), "%s wrong-color rejection" % kind)
	check(observed.size() == 4, "%s cycles all colors" % kind)
	check(Rules.next_window(barrier, 0.0, 3) >= 0.0, "%s has reachable window" % kind)
	check(Rules.contacts(barrier) == (2 if kind == "chain" else 1), "%s contact count" % kind)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(message)
