extends SceneTree

const Sim = preload("res://tests/balance_simulation.gd")


func _initialize() -> void:
	var simulation: Sim = Sim.new()
	var registry := LevelRegistry.new()
	var results: Array[Dictionary] = []
	for id: int in [97, 100]:
		var routes: Dictionary = {}
		for milliseconds: int in [100, 75, 50, 25]:
			var result: Dictionary = simulation.solve(RunState.new(registry.get_level(id)), milliseconds / 1000.0)
			routes[str(milliseconds)] = {
				"complete": result.complete,
				"seconds": result.seconds,
				"stage": result.get("stage", -1),
				"kind": result.get("kind", ""),
				"stars": result.stars
			}
		results.append({"id": id, "routes": routes})
	var report: Dictionary = {
		"date": "2026-11-05",
		"method": "Production RunState centered per-stage launch search at signed tolerance and quarter steps",
		"levels": results,
		"search_candidates": simulation.candidates
	}
	var file: FileAccess = FileAccess.open("res://docs/evidence/balance_precision.json", FileAccess.WRITE)
	if file == null:
		printerr("Could not write precision report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print(JSON.stringify(report))
	quit(0)
