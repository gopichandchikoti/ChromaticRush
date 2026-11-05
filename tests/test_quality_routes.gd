extends SceneTree

const Registry = preload("res://src/domain/level_registry.gd")
const Run = preload("res://src/domain/run_state.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	var registry: Registry = Registry.new()
	var audit: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/route_audit.json"))
	_check(registry.errors.is_empty(), "Complete production registry parses")
	_check(audit is Dictionary and audit.get("levels", []).size() == 100, "One hundred searched schedules exist")
	if not failures.is_empty():
		_finish()
		return
	for index: int in range(100):
		var route: Dictionary = audit.levels[index]
		var definition: Dictionary = registry.get_level(index + 1)
		var run: Run = Run.new(definition)
		var clock: float = 0.0
		for time: float in route.tap_schedule:
			_check(time >= clock, "Level %d input timestamps increase" % (index + 1))
			while clock < time - 0.0000001:
				var delta: float = minf(1.0 / 60.0, time - clock)
				run.advance(delta)
				clock += delta
			_check(run.tap(), "Level %d scheduled input is accepted" % (index + 1))
		for _tick: int in range(120):
			run.advance(1.0 / 120.0)
			if run.status in ["failed", "complete"]:
				break
		_check(run.status == "complete", "Level %d completes without bypassing production collision" % (index + 1))
		_check(run.stage_index == definition.stages.size(), "Every stage must be cleared")
		_check(run.deaths == 0, "Searched successful route has no wrong contacts")
	_finish()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr(message)


func _finish() -> void:
	print(JSON.stringify({"suite": "all-level input replay", "checks": checks, "failures": failures}))
	quit(1 if not failures.is_empty() else 0)
