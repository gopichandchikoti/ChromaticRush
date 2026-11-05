extends SceneTree

const SaveStore = preload("res://src/services/save_store.gd")

var _checks: int = 0
var _failed: int = 0
var _root: String


func _init() -> void:
	_root = "user://save-tests-%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_root)
	_test_roundtrip()
	_test_resume_stats()
	_test_records()
	_test_achievements()
	_test_backup()
	_test_migration()
	_test_invalid()
	_test_write_failure()
	_test_atomic_failure()
	_test_reset()
	_test_reset_retry()
	_cleanup()
	print("SAVE TESTS: %s checks, %s failures" % [_checks, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error(description)


func _store(name: String) -> SaveStore:
	return SaveStore.new(_root.path_join(name))


func _write(name: String, content: String, suffix: String = "") -> void:
	var path: String = _root.path_join(name)
	DirAccess.make_dir_recursive_absolute(path)
	var file: FileAccess = FileAccess.open(path.path_join("progress.json") + suffix, FileAccess.WRITE)
	_check(file != null, "Fixture can be written")
	if file != null:
		file.store_string(content)
		file.close()


func _test_roundtrip() -> void:
	var save: SaveStore = _store("roundtrip")
	_check(save.load_save() == OK, "First launch loads default settings")
	_check(save.settings().color_labels and save.settings().sound, "Accessible and audio defaults")
	_check(save.unlocked(1) and not save.unlocked(2), "First level is the only initial standard unlock")
	_check(not save.unlocked(0) and not save.unlocked(101), "Out-of-range levels remain locked")
	_check(save.set_setting("sound", false) == OK, "Setting is saved")
	save.data.resume = {"level": 1, "stage": 2, "color": 3, "mode": "standard"}
	_check(save.save() == OK, "Checkpoint snapshot saves")
	var reopened: SaveStore = _store("roundtrip")
	_check(reopened.load_save() == OK, "Saved state reloads")
	_check(not reopened.settings().sound, "Setting survives restart")
	_check(reopened.data.resume.stage == 2 and reopened.data.resume.color == 3, "Checkpoint survives restart")
	_check(reopened.data.updated_at.ends_with("Z"), "Save timestamp explicitly uses UTC")
	_check(save.set_setting("unknown", true) == ERR_INVALID_PARAMETER, "Unknown settings rejected")
	_check(save.set_setting("sound", 1) == ERR_INVALID_PARAMETER, "Non-boolean setting rejected")


func _test_resume_stats() -> void:
	var save: SaveStore = _store("resume-stats")
	save.data.resume = {
		"level": 10, "stage": 3, "color": 2, "mode": "standard", "elapsed": 47.75, "taps": 81, "deaths": 2
	}
	_check(save.save() == OK, "Checkpoint run statistics save")
	var reopened: SaveStore = _store("resume-stats")
	_check(reopened.load_save() == OK, "Checkpoint statistics reload")
	_check(reopened.data.resume.elapsed == 47.75, "Elapsed time is preserved without rounding")
	_check(
		reopened.data.resume.taps == 81 and reopened.data.resume.deaths == 2, "Tap and death counts survive relaunch"
	)
	save.data.resume = {"level": 1, "stage": 0, "color": 0, "mode": "standard"}
	_check(save.save() == OK, "Older checkpoint snapshot remains readable")
	_check(
		save.data.resume.elapsed == 0.0 and save.data.resume.taps == 0 and save.data.resume.deaths == 0,
		"Missing checkpoint statistics receive explicit defaults"
	)
	var invalid_values := [
		["elapsed", NAN],
		["elapsed", INF],
		["elapsed", -0.01],
		["elapsed", 86_400.1],
		["elapsed", "bad"],
		["taps", -1],
		["taps", 0.5],
		["taps", true],
		["deaths", -1],
		["deaths", INF],
		["deaths", 1_000_000_001],
	]
	for invalid: Array in invalid_values:
		save.data.resume = {"level": 1, "stage": 0, "color": 0, "mode": "standard"}
		save.data.resume[invalid[0]] = invalid[1]
		_check(save.save() == ERR_INVALID_DATA, "Invalid checkpoint statistic rejected: %s" % invalid[0])
	save.data.resume = {
		"level": 1,
		"stage": 0,
		"color": 0,
		"mode": "standard",
		"elapsed": 86_400.0,
		"taps": 1_000_000_000,
		"deaths": 1_000_000_000
	}
	_check(save.save() == OK, "Bounded checkpoint statistics accept their maximum values")


func _test_records() -> void:
	var save: SaveStore = _store("records")
	_check(save.record_result(1, {"stars": 2, "score": 120, "seconds": 20.0}, true) == OK, "Practice result persists")
	_check(save.totals().completed == 0 and not save.unlocked(2), "Practice cannot award standard progress")
	_check(not save.achievements()[0].unlocked, "Practice cannot award standard achievements")
	_check(
		save.record_result(1, {"stars": 1, "score": 80, "seconds": 30.0}, false) == OK, "Standard completion persists"
	)
	_check(save.unlocked(2) and save.achievements()[0].unlocked, "Completion unlocks next level and first achievement")
	_check(save.record_result(1, {"stars": 3, "score": 70, "seconds": 35.0}, false) == OK, "Replay merges record")
	var record: Dictionary = save.data.records["1"]
	_check(record.stars == 3 and record.score == 80 and record.seconds == 30.0, "Each personal best retained")
	_check(record.completions == 2, "Completion count increments")
	_check(
		save.record_result(1, {"stars": 2, "score": 150, "seconds": 25.0}, false) == OK,
		"Faster higher-score replay saves"
	)
	_check(save.totals() == {"completed": 1, "stars": 3, "best_score": 150}, "Totals derive from standard records")
	_check(save.data.practice["1"].seconds == 20.0, "Standard update preserves separate practice record")
	_check(
		save.record_result(0, {"stars": 1, "score": 0, "seconds": 1.0}, false) == ERR_INVALID_PARAMETER,
		"Invalid level rejected"
	)
	_check(
		save.record_result(1, {"stars": 0, "score": 0, "seconds": 1.0}, false) == ERR_INVALID_PARAMETER,
		"Invalid stars rejected"
	)
	_check(
		save.record_result(1, {"stars": 1, "score": -1, "seconds": 1.0}, false) == ERR_INVALID_PARAMETER,
		"Negative score rejected"
	)
	_check(
		save.record_result(1, {"stars": 1, "score": 0, "seconds": NAN}, false) == ERR_INVALID_PARAMETER,
		"NaN time rejected"
	)
	_check(
		save.record_result(1, {"stars": 1, "score": 0, "seconds": INF}, false) == ERR_INVALID_PARAMETER,
		"Infinite time rejected"
	)
	_check(
		save.record_result(1, {"stars": 1, "score": 0, "seconds": 0.0}, false) == ERR_INVALID_PARAMETER,
		"Zero time rejected"
	)


func _test_backup() -> void:
	var save: SaveStore = _store("backup")
	_check(save.record_result(1, {"stars": 1, "score": 50, "seconds": 10.0}, false) == OK, "Initial backup fixture")
	_check(
		save.record_result(2, {"stars": 2, "score": 70, "seconds": 15.0}, false) == OK,
		"Second save creates previous backup"
	)
	_write("backup", "{truncated")
	var recovered: SaveStore = _store("backup")
	_check(recovered.load_save() == OK, "Valid previous save recovers corrupt primary")
	_check(recovered.totals().completed == 1 and not recovered.warning.is_empty(), "Recovery warns of possible loss")
	_check(recovered.set_setting("music", false) == OK, "Recovered state can be saved")
	_write("backup", "bad again")
	var again: SaveStore = _store("backup")
	_check(again.load_save() == OK and again.totals().completed == 1, "Corrupt primary never poisons valid backup")


func _test_achievements() -> void:
	var save: SaveStore = _store("achievements")
	for count: int in [0, 1, 10, 50, 100]:
		save.data.records.clear()
		for id: int in range(1, count + 1):
			save.data.records[str(id)] = {"stars": 3, "score": 1, "seconds": 1.0, "completions": 1}
		var expected := [
			count >= 1, count >= 10, count >= 50, count >= 100, count * 3 >= 30, count * 3 >= 150, count * 3 >= 300
		]
		var actual: Array[Dictionary] = save.achievements()
		for index: int in expected.size():
			_check(actual[index].unlocked == expected[index], "Achievement thresholds follow actual standard records")


func _test_migration() -> void:
	_write("migration", JSON.stringify({"version": 1, "unlocked": 11, "settings": {"sound": false}}))
	var save: SaveStore = _store("migration")
	_check(save.load_save() == OK and save.data.version == 2, "V1 migrates to current schema")
	_check(save.unlocked(11) and not save.unlocked(12), "V1 unlocks preserved")
	_check(save.totals().completed == 10 and save.totals().stars == 0, "Migration invents no stars")
	_check(not save.settings().sound and save.settings().color_labels, "Migration merges valid settings and defaults")
	_check(
		save.data.records["1"].legacy and save.data.records["1"].seconds == 0.0, "Missing legacy times marked unknown"
	)
	_check(
		save.record_result(1, {"stars": 2, "score": 40, "seconds": 12.0}, false) == OK,
		"Legacy record accepts real result"
	)
	_check(
		save.data.records["1"].seconds == 12.0 and not save.data.records["1"].has("legacy"),
		"Real result replaces unknown legacy fields"
	)


func _test_invalid() -> void:
	var bad_documents := [
		"[]",
		"null",
		"{broken",
		'{"version":99}',
		'{"version":2,"settings":{"sound":1}}',
		'{"version":2,"settings":{"tracking":true}}',
		'{"version":1,"unlocked":102}',
		'{"version":2,"records":{"101":{"stars":1,"score":1,"seconds":1,"completions":1}}}',
		'{"version":2,"records":{"01":{"stars":1,"score":1,"seconds":1,"completions":1}}}',
		'{"version":2,"records":{"1":{"stars":4,"score":1,"seconds":1,"completions":1}}}',
		'{"version":2,"resume":{"level":1,"stage":0,"color":5,"mode":"standard"}}',
		'{"version":2,"updated_at":4}',
		'{"version":2,"unexpected":true}',
	]
	for index: int in bad_documents.size():
		var name: String = "invalid-%s" % index
		_write(name, bad_documents[index])
		var save: SaveStore = _store(name)
		_check(save.load_save() == ERR_FILE_CORRUPT, "Malformed document rejected: %s" % index)
		_check(save.totals().completed == 0 and not save.warning.is_empty(), "Safe empty state with warning")
	_write("oversized", " ".repeat(SaveStore.MAX_BYTES + 1))
	_check(_store("oversized").load_save() == ERR_FILE_CORRUPT, "Oversized save rejected before parsing")
	var invalid_memory: SaveStore = _store("invalid-memory")
	invalid_memory.data.settings.sound = "invalid"
	_check(invalid_memory.save() == ERR_INVALID_DATA, "Unvalidated in-memory edits cannot reach disk")


func _test_write_failure() -> void:
	var blocker: String = _root.path_join("file-blocker")
	var file: FileAccess = FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("not a directory")
	file.close()
	var save: SaveStore = SaveStore.new(blocker.path_join("nested"))
	_check(
		save.record_result(1, {"stars": 1, "score": 10, "seconds": 3.0}, false) != OK,
		"Unavailable save directory returns failure"
	)
	_check(
		save.totals().completed == 1 and not save.warning.is_empty(), "Write failure retains in-memory result and warns"
	)


func _test_reset() -> void:
	var save: SaveStore = _store("reset")
	save.record_result(1, {"stars": 3, "score": 100, "seconds": 12.0}, false)
	save.record_result(2, {"stars": 2, "score": 60, "seconds": 15.0}, true)
	save.set_setting("sound", false)
	save.data.resume = {"level": 2, "stage": 0, "color": 0, "mode": "practice"}
	_check(save.reset_progress() == OK, "Reset writes new progress")
	_check(
		save.totals().completed == 0 and save.data.practice.is_empty() and save.data.resume.is_empty(),
		"Reset clears records and checkpoints"
	)
	_check(not save.settings().sound, "Reset preserves settings")
	_write("reset", "corrupt")
	var reopened: SaveStore = _store("reset")
	_check(
		reopened.load_save() == OK and reopened.totals().completed == 0,
		"Recovery after reset cannot resurrect deleted progress"
	)


func _test_atomic_failure() -> void:
	var save: SaveStore = _store("atomic-failure")
	_check(
		save.record_result(1, {"stars": 2, "score": 60, "seconds": 20.0}, false) == OK,
		"Atomic replacement fixture created"
	)
	var temporary: String = _root.path_join("atomic-failure/progress.json.tmp")
	DirAccess.make_dir_absolute(temporary)
	_check(
		save.record_result(2, {"stars": 3, "score": 80, "seconds": 25.0}, false) != OK,
		"Blocked temporary path reports write failure"
	)
	var reopened: SaveStore = _store("atomic-failure")
	_check(
		reopened.load_save() == OK and reopened.totals().completed == 1,
		"Failed temporary write leaves previous primary save intact"
	)
	_check(save.totals().completed == 2, "Failed atomic write retains new in-memory progress")
	DirAccess.remove_absolute(temporary)


func _test_reset_retry() -> void:
	var save: SaveStore = _store("reset-retry")
	_check(
		save.record_result(1, {"stars": 3, "score": 100, "seconds": 12.0}, false) == OK,
		"Reset retry starts from durable progress"
	)
	var temporary: String = _root.path_join("reset-retry/progress.json.tmp")
	_check(DirAccess.make_dir_absolute(temporary) == OK, "Block the reset temporary write")
	_check(save.reset_progress() != OK and not save.warning.is_empty(), "Failed reset remains visibly pending")
	_check(save.totals().completed == 0, "Failed reset retains the requested empty in-memory progress")
	DirAccess.remove_absolute(temporary)
	_check(save.save() == OK and save.warning.is_empty(), "Generic Retry completes the pending reset")
	_write("reset-retry", "corrupt")
	var reopened: SaveStore = _store("reset-retry")
	_check(
		reopened.load_save() == OK and reopened.totals().completed == 0,
		"Backup recovery after a retried reset cannot resurrect erased records"
	)


func _cleanup() -> void:
	var directory: DirAccess = DirAccess.open(_root)
	for name: String in directory.get_directories():
		var folder: String = _root.path_join(name)
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file))
		DirAccess.remove_absolute(folder)
	for file: String in directory.get_files():
		DirAccess.remove_absolute(_root.path_join(file))
	DirAccess.remove_absolute(_root)
