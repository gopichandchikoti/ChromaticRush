class_name RushSave
extends RefCounted

const MAX_BYTES := 1_048_576
const FILE_NAME := "progress.json"
const DEFAULT_SETTINGS := {
	"sound": true,
	"music": true,
	"haptics": true,
	"reduced_motion": false,
	"color_labels": true,
	"large_text": false,
	"guide": false,
	"slow_time": false,
	"light_theme": false,
}
const DOCUMENT_KEYS := ["version", "settings", "records", "practice", "resume", "updated_at"]
const RECORD_KEYS := ["stars", "score", "seconds", "completions", "legacy"]
const RESUME_KEYS := ["level", "stage", "color", "checkpoint", "mode", "elapsed", "taps", "deaths"]

var data: Dictionary
var warning: String = ""
var _root: String
var _reset_pending: bool = false


func _init(root_path: String = "user://") -> void:
	_root = root_path
	data = _defaults()


func load_save() -> Error:
	warning = ""
	data = _defaults()
	var primary: Dictionary = _read(_path())
	if not primary.is_empty():
		data = primary
		return OK
	var backup: Dictionary = _read(_path() + ".bak")
	if not backup.is_empty():
		data = backup
		warning = "Save recovered from the previous backup. Latest progress may be missing."
		return OK
	if FileAccess.file_exists(_path()) or FileAccess.file_exists(_path() + ".bak"):
		return _fail(ERR_FILE_CORRUPT, "Save could not be read. A new local session is available.")
	return OK


func save() -> Error:
	var normalized: Dictionary = _normalize(data)
	if normalized.is_empty():
		return _fail(ERR_INVALID_DATA, "Progress contains invalid data and was not written.")
	if FileAccess.file_exists(_root) or FileAccess.file_exists(_root.get_base_dir()):
		return _fail(ERR_CANT_CREATE, "Progress is in memory. The save folder is unavailable.")
	var folder_error: Error = DirAccess.make_dir_recursive_absolute(_root)
	if folder_error != OK:
		return _fail(folder_error, "Progress is in memory. The save folder is unavailable.")
	normalized.updated_at = Time.get_datetime_string_from_system(true) + "Z"
	var result: Error = _write_temp(normalized)
	if result == OK:
		result = _backup_current()
	if result == OK:
		result = DirAccess.rename_absolute(_path() + ".tmp", _path())
	if result == OK and _reset_pending:
		result = _backup_current()
	if result != OK:
		return _fail(result, "Progress is in memory. Local saving failed; retry when storage is available.")
	data = normalized
	_reset_pending = false
	warning = ""
	return OK


func settings() -> Dictionary:
	return data.settings


func set_setting(key: String, value: Variant) -> Error:
	if not DEFAULT_SETTINGS.has(key) or not value is bool:
		return ERR_INVALID_PARAMETER
	data.settings[key] = value
	return save()


func unlocked(id: int) -> bool:
	if id < 1 or id > 100:
		return false
	return id == 1 or data.records.has(str(id - 1))


func record_result(id: int, result: Dictionary, assisted: bool) -> Error:
	if not _integer(id, 1, 100) or not _result_valid(result):
		return ERR_INVALID_PARAMETER
	var stars: int = int(result.stars)
	var score: int = int(result.score)
	var seconds: float = float(result.seconds)
	var records: Dictionary = data.practice if assisted else data.records
	var previous: Dictionary = records.get(str(id), {})
	var old_time: float = float(previous.get("seconds", seconds))
	if old_time <= 0.0:
		old_time = seconds
	records[str(id)] = {
		"stars": maxi(stars, int(previous.get("stars", 0))),
		"score": maxi(score, int(previous.get("score", 0))),
		"seconds": minf(seconds, old_time),
		"completions": mini(1_000_000, int(previous.get("completions", 0)) + 1),
	}
	return save()


func _result_valid(result: Dictionary) -> bool:
	if result.size() != 3 or not _keys_allowed(result, ["stars", "score", "seconds"]):
		return false
	if not _integer(result.get("stars"), 1, 3) or not _integer(result.get("score"), 0, 1_000_000_000):
		return false
	var seconds: Variant = result.get("seconds")
	return _number(seconds) and seconds > 0.0 and seconds <= 86_400.0


func totals() -> Dictionary:
	var result := {"completed": data.records.size(), "stars": 0, "best_score": 0}
	for record: Dictionary in data.records.values():
		result.stars += int(record.stars)
		result.best_score += int(record.score)
	return result


func reset_progress() -> Error:
	var kept_settings: Dictionary = data.settings.duplicate()
	data = _defaults()
	data.settings = kept_settings
	_reset_pending = true
	return save()


func achievements() -> Array[Dictionary]:
	var progress: Dictionary = totals()
	var result: Array[Dictionary] = []
	var milestones := [
		["First spectrum", "completed", 1],
		["First world", "completed", 10],
		["Halfway to the horizon", "completed", 50],
		["White horizon", "completed", 100],
		["Star collector", "stars", 30],
		["Starlight keeper", "stars", 150],
		["Perfect spectrum", "stars", 300],
	]
	for milestone: Array in milestones:
		var current: int = int(progress[milestone[1]])
		(
			result
			. append(
				{
					"name": milestone[0],
					"current": current,
					"target": milestone[2],
					"unlocked": current >= int(milestone[2]),
				}
			)
		)
	return result


func _defaults() -> Dictionary:
	return {
		"version": 2,
		"settings": DEFAULT_SETTINGS.duplicate(),
		"records": {},
		"practice": {},
		"resume": {},
		"updated_at": "",
	}


func _path() -> String:
	return _root.path_join(FILE_NAME)


func _fail(code: Error, message: String) -> Error:
	warning = message
	return code


func _write_temp(document: Dictionary) -> Error:
	var content: String = JSON.stringify(document)
	if content.to_utf8_buffer().size() > MAX_BYTES:
		return ERR_OUT_OF_MEMORY
	var file: FileAccess = FileAccess.open(_path() + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	var result: Error = file.get_error()
	file.close()
	return result


func _backup_current() -> Error:
	if _read(_path()).is_empty():
		return OK
	var temporary: String = _path() + ".bak.tmp"
	var result: Error = DirAccess.copy_absolute(_path(), temporary)
	if result == OK:
		result = DirAccess.rename_absolute(temporary, _path() + ".bak")
	return result


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {}
	var parser := JSON.new()
	var result: Error = parser.parse(file.get_as_text())
	file.close()
	if result != OK:
		return {}
	if parser.data is Dictionary and parser.data.get("version") == 1:
		return _migrate(parser.data)
	return _normalize(parser.data)


func _normalize(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not _keys_allowed(raw, DOCUMENT_KEYS) or raw.get("version") != 2:
		return {}
	var result: Dictionary = _defaults()
	if not _settings_valid(raw.get("settings", {})):
		return {}
	result.settings.merge(raw.get("settings", {}), true)
	for category: String in ["records", "practice"]:
		var records: Variant = raw.get(category, {})
		if not _records_valid(records):
			return {}
		result[category] = records.duplicate(true)
	var resume: Variant = raw.get("resume", {})
	if not _resume_valid(resume):
		return {}
	result.resume = _normalize_resume(resume)
	var timestamp: Variant = raw.get("updated_at", "")
	if not timestamp is String or timestamp.length() > 32:
		return {}
	result.updated_at = timestamp
	return result


func _keys_allowed(value: Dictionary, allowed: Array) -> bool:
	for key: Variant in value:
		if not key is String or not allowed.has(key):
			return false
	return true


func _settings_valid(value: Variant) -> bool:
	if not value is Dictionary or not _keys_allowed(value, DEFAULT_SETTINGS.keys()):
		return false
	for entry: Variant in value.values():
		if not entry is bool:
			return false
	return true


func _records_valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 100:
		return false
	for key: Variant in value:
		if not key is String or not key.is_valid_int() or str(int(key)) != key:
			return false
		if not _integer(int(key), 1, 100) or not _record_valid(value[key]):
			return false
	return true


func _record_valid(record: Variant) -> bool:
	if not record is Dictionary or not _keys_allowed(record, RECORD_KEYS):
		return false
	if record.has("legacy") and not record.legacy is bool:
		return false
	var legacy: bool = record.get("legacy", false)
	if not _integer(record.get("stars"), 0 if legacy else 1, 3):
		return false
	if not _integer(record.get("score"), 0, 1_000_000_000):
		return false
	if not _integer(record.get("completions"), 1, 1_000_000):
		return false
	var seconds: Variant = record.get("seconds")
	return _number(seconds) and seconds <= 86_400.0 and (seconds >= 0.0 if legacy else seconds > 0.0)


func _resume_valid(value: Variant) -> bool:
	if not value is Dictionary or not _keys_allowed(value, RESUME_KEYS):
		return false
	if value.is_empty():
		return true
	if not _integer(value.get("level"), 1, 100) or not _integer(value.get("stage"), 0, 7):
		return false
	if not _integer(value.get("color"), 0, 3):
		return false
	if value.has("checkpoint") and not _integer(value.checkpoint, 0, 7):
		return false
	return value.get("mode") in ["standard", "practice", "assisted"] and _resume_stats_valid(value)


func _resume_stats_valid(value: Dictionary) -> bool:
	var elapsed: Variant = value.get("elapsed", 0.0)
	if not _number(elapsed) or elapsed < 0.0 or elapsed > 86_400.0:
		return false
	for key: String in ["taps", "deaths"]:
		if not _integer(value.get(key, 0), 0, 1_000_000_000):
			return false
	return true


func _normalize_resume(value: Dictionary) -> Dictionary:
	if value.is_empty():
		return {}
	var result := {"elapsed": 0.0, "taps": 0, "deaths": 0}
	result.merge(value.duplicate(true), true)
	return result


func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value) and value >= minimum and value <= maximum and value == floor(float(value))


func _migrate(raw: Dictionary) -> Dictionary:
	if not _keys_allowed(raw, ["version", "unlocked", "settings"]):
		return {}
	if not _integer(raw.get("unlocked"), 1, 101) or not _settings_valid(raw.get("settings", {})):
		return {}
	var migrated: Dictionary = _defaults()
	migrated.settings.merge(raw.get("settings", {}), true)
	for id: int in range(1, int(raw.unlocked)):
		migrated.records[str(id)] = {
			"stars": 0,
			"score": 0,
			"seconds": 0.0,
			"completions": 1,
			"legacy": true,
		}
	return migrated
