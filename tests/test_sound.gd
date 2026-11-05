extends SceneTree

const Bank = preload("res://src/services/sound_bank.gd")

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bank := Bank.new()
	root.add_child(bank)
	bank.set_process(false)
	_check(bank.get_child_count() == 6, "Audio uses a bounded voice pool")
	bank.play("tap")
	_check(_playing(bank, 0, 4), "Enabled sound effect starts a real playback")
	bank.enabled = false
	_check(not _playing(bank, 0, 4), "Disabling sound stops an in-flight effect immediately")
	bank.play("complete")
	_check(not _playing(bank, 0, 4), "Disabled effects cannot start new playback")
	bank._process(1.0)
	_check(_playing(bank, 4, 6), "Enabled music starts a cached note")
	bank.music_enabled = false
	_check(not _playing(bank, 4, 6), "Disabling music stops an in-flight note immediately")
	bank._process(2.0)
	_check(not _playing(bank, 4, 6), "Disabled music cannot start another note")
	bank.enabled = true
	bank.music_enabled = true
	bank.suspend(true)
	bank.play("tap")
	bank._process(2.0)
	_check(not _playing(bank, 0, 6), "Background suspension rejects effects and music")
	bank.suspend(false)
	bank.play("tap")
	_check(_playing(bank, 0, 4), "Foreground sound remains usable after suspension")
	bank.suspend(true)
	for node: Node in bank.get_children():
		_check(node is AudioStreamPlayer and node.stream == null, "Suspension drops inactive stream handles")
	await create_timer(0.6).timeout
	bank.queue_free()
	await process_frame
	await process_frame
	print(JSON.stringify({"suite": "native audio state", "checks": _checks, "failures": _failures}))
	quit(1 if not _failures.is_empty() else 0)


func _playing(bank: SoundBank, first: int, end: int) -> bool:
	for index: int in range(first, end):
		var voice: AudioStreamPlayer = bank.get_child(index) as AudioStreamPlayer
		if voice.playing:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr(message)
