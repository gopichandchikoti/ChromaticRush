extends RefCounted

const DIRECTORY: String = "res://docs/evidence"

var app: RushApp
var tree: SceneTree
var press: Callable
var replay: Callable
var key: Callable
var check: Callable
var _captures: Array[Dictionary] = []


func capture_views() -> Array[Dictionary]:
	if DisplayServer.get_name() == "headless":
		check.call(false, "--capture requires a rendering display; run without --headless")
		return []
	for dimensions: Vector2i in [Vector2i(480, 900), Vector2i(320, 600), Vector2i(900, 480)]:
		tree.root.size = dimensions
		await _frames()
		await _home()
		await _capture("home", dimensions)
		await press.call("Practice")
		await _capture("worlds", dimensions)
		await _home()
		await press.call("SET")
		await _capture("settings", dimensions)
		app.save.data.resume = {}
		app.start_level(1)
		key.call(KEY_SPACE)
		app._process(0.13)
		await _capture("play", dimensions)
		app.save.data.resume = {}
		app.start_level(1)
		replay.call()
		await _frames()
		await _capture("result", dimensions)
		for level: Dictionary in app.registry.levels:
			if level.stages[0].kind == "reverse":
				app.save.data.resume = {}
				app.start_level(int(level.id), true)
				break
		await _capture("reverse", dimensions)
	var report := {
		"source": "Actual native viewport captures from isolated automated UI session",
		"progress": "Level-one results were earned by timestamped input replay, not seeded records",
		"captures": _captures
	}
	var file: FileAccess = FileAccess.open(DIRECTORY.path_join("ui_capture_manifest.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	return _captures


func _frames() -> void:
	await tree.process_frame
	await tree.process_frame


func _home() -> void:
	app._show("home")
	await _frames()


func _capture(view: String, dimensions: Vector2i) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	var image: Image = tree.root.get_texture().get_image()
	var path: String = DIRECTORY.path_join("ui-%s-%dx%d.png" % [view, dimensions.x, dimensions.y])
	var result: Error = image.save_png(path)
	check.call(result == OK, "Native screenshot written: %s" % path)
	_captures.append(
		{
			"view": view,
			"requested_window": [dimensions.x, dimensions.y],
			"image_size": [image.get_width(), image.get_height()],
			"path": path
		}
	)
