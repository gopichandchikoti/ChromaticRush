class_name LevelRegistry
extends RefCounted

var worlds: Array[Dictionary] = []
var levels: Array[Dictionary] = []
var errors: Array[String] = []


func _init() -> void:
	var files: PackedStringArray = DirAccess.get_files_at("res://data/worlds")
	files.sort()
	for filename: String in files:
		if not filename.ends_with(".json"):
			continue
		var path: String = "res://data/worlds/" + filename
		if not FileAccess.file_exists(path):
			errors.append("Missing world " + filename)
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or not parsed.get("levels") is Array:
			errors.append("Invalid world " + filename)
			continue
		worlds.append(parsed)
		for definition: Variant in parsed.levels:
			if definition is Dictionary:
				levels.append(definition)
	_validate()


func get_level(id: int) -> Dictionary:
	if id < 1 or id > levels.size():
		return {}
	return levels[id - 1]


func get_world(id: int) -> Dictionary:
	return worlds[clampi(id - 1, 0, worlds.size() - 1)]


func _validate() -> void:
	if worlds.size() != 10 or levels.size() != 100:
		errors.append("Expected ten worlds and one hundred levels")
	var signatures: Dictionary = {}
	for index: int in range(levels.size()):
		var definition: Dictionary = levels[index]
		if int(definition.get("id", 0)) != index + 1:
			errors.append("Nonsequential ID at %d" % index)
		_validate_level(definition)
		var signature: String = JSON.stringify(definition.get("stages", []))
		if signatures.has(signature):
			errors.append("Duplicate route %d" % (index + 1))
		signatures[signature] = true


func _validate_level(definition: Dictionary) -> void:
	if not definition.get("stages") is Array or definition.get("stages", []).is_empty():
		errors.append("Empty route")
		return
	for barrier: Variant in definition.stages:
		if not barrier is Dictionary or not GateRules.KINDS.has(str(barrier.get("kind", ""))):
			errors.append("Unknown mechanic")
			continue
		if float(barrier.get("gap", 0)) < 100.0 or float(barrier.get("gap", 0)) > 250.0:
			errors.append("Unsafe stage gap")
		if float(barrier.get("speed", 0)) <= 0.0 or float(barrier.get("speed", 0)) > 3.0:
			errors.append("Unsafe gate speed")
