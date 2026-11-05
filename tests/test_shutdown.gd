extends SceneTree

const App = preload("res://src/app.gd")

var _app: App
var _root_path: String
var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_root_path = "user://shutdown-tests-%s" % Time.get_ticks_usec()
	_app = App.new()
	_app.save_root = _root_path
	_app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_app)
	await create_timer(0.15).timeout
	_app.sound._process(1.0)
	var playing: bool = false
	for voice: Node in _app.sound.get_children():
		playing = playing or (voice is AudioStreamPlayer and voice.playing)
	_check(playing, "Shutdown starts with a real active soundtrack voice")
	_app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(_app.sound.suspended, "WM close suspends all new audio immediately")
	for voice: Node in _app.sound.get_children():
		_check(voice is AudioStreamPlayer and not voice.playing, "WM close stops every pooled voice")
	print(JSON.stringify({"suite": "graceful native shutdown", "checks": _checks, "failures": _failures}))
	if not _failures.is_empty():
		quit(1)
		return
	await create_timer(2.0).timeout
	printerr("Graceful shutdown did not quit within two seconds")
	quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr(message)
		quit(1)


func _finalize() -> void:
	if DirAccess.dir_exists_absolute(_root_path):
		for file: String in DirAccess.get_files_at(_root_path):
			DirAccess.remove_absolute(_root_path.path_join(file))
		DirAccess.remove_absolute(_root_path)
