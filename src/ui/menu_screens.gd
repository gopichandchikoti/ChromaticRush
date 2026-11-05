class_name MenuScreens
extends ScreenBase
## Home, world and level selection, and route detail. Settings/help/achievements are SettingsScreens.

signal play(level_id: int, practice: bool)
signal setting_changed(key: String, value: bool)
signal reset_requested

var registry: LevelRegistry
var practice: bool = false
var selected: int = 1
var _settings: SettingsScreens = SettingsScreens.new()


func _init() -> void:
	_settings.navigate.connect(_forward_navigation)
	_settings.setting_changed.connect(_forward_setting)
	_settings.reset_requested.connect(_forward_reset)


func _forward_navigation(screen: String, world: int) -> void:
	navigate.emit(screen, world)


func _forward_setting(key: String, value: bool) -> void:
	setting_changed.emit(key, value)


func _forward_reset() -> void:
	reset_requested.emit()


func render(screen: String, world_id: int = 1) -> void:
	_settings.layer = layer
	_settings.save = save
	match screen:
		"home":
			_home()
		"worlds":
			_worlds()
		"levels":
			_levels(world_id)
		"detail":
			_detail()
		"settings":
			_settings.settings()
		"achievements":
			_settings.achievements()
		"help":
			_settings.help()


func next_level() -> int:
	var resume: Dictionary = save.data.resume
	if not resume.is_empty() and str(resume.mode) == "standard":
		return int(resume.level)
	for id: int in range(1, 101):
		if not save.data.records.has(str(id)):
			return id
	return 100


func _home() -> void:
	RushSkin.label(layer, "C H R O M A T I C", Rect2(32, 28, 260, 22), 17)
	RushSkin.heading(layer, "RUSH", Rect2(32, 47, 220, 42), 36)
	RushSkin.button(layer, "SET", Rect2(374, 28, 74, 66), func() -> void: navigate.emit("settings", 1))
	RushSkin.label(layer, "PRECISION IN EVERY PULSE", Rect2(32, 126, 410, 26), 17, RushSkin.accent)
	RushSkin.heading(layer, "Chase the\nspectrum.", Rect2(32, 150, 416, 112), 44)
	var next_id: int = next_level()
	var definition: Dictionary = registry.get_level(next_id)
	RushSkin.label(
		layer,
		"%02d / %s" % [definition.world, registry.get_world(definition.world).name.to_upper()],
		Rect2(32, 607, 416, 25),
		16,
		RushSkin.accent
	)
	RushSkin.heading(layer, definition.name, Rect2(32, 637, 416, 40), 28)
	RushSkin.button(
		layer, "CONTINUE RUN     →", Rect2(32, 697, 416, 66), func() -> void: play.emit(next_id, false), true
	)
	RushSkin.button(layer, "Worlds  01—10", Rect2(32, 775, 250, 64), func() -> void: _browse(false))
	RushSkin.button(layer, "Practice", Rect2(294, 775, 154, 64), func() -> void: _browse(true))
	var totals: Dictionary = save.totals()
	RushSkin.label(
		layer,
		"%03d / 100 CLEARED     ·     %03d / 300 STARS" % [totals.completed, totals.stars],
		Rect2(32, 859, 416, 23),
		15,
		RushSkin.MUTED
	)


func _browse(is_practice: bool) -> void:
	practice = is_practice
	navigate.emit("worlds", 1)


func _worlds() -> void:
	header("The spectrum", "PRACTICE / all routes open" if practice else "Ten worlds. One hundred ways through.")
	var rows: VBoxContainer = column()
	for world: Dictionary in registry.worlds:
		var id: int = int(world.id)
		var tint: Color = RushSkin.theme_of(id).accent
		var unlocked: bool = practice or save.unlocked((id - 1) * 10 + 1)
		var cleared: int = 0
		var stars: int = 0
		for level_id: int in range((id - 1) * 10 + 1, id * 10 + 1):
			var record: Dictionary = save.data.records.get(str(level_id), {})
			cleared += 1 if not record.is_empty() else 0
			stars += int(record.get("stars", 0))
		var card: Button = RushSkin.card(
			rows, "%02d   %s" % [id, world.name], Vector2(405, 112), func() -> void: navigate.emit("levels", id)
		)
		card.disabled = not unlocked
		var ink: Color = tint if unlocked else Color(tint, 0.45)
		_stripe(card, ink)
		RushSkin.label(card, str(world.theme), Rect2(18, 46, 340, 38), 14, RushSkin.MUTED)
		if unlocked:
			var big: Label = RushSkin.heading(card, "%02d" % id, Rect2(300, 6, 92, 56), 44)
			big.add_theme_color_override("font_color", Color(ink, 0.2))
			big.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bar(card, Rect2(18, 96, 230, 5), cleared / 10.0, ink)
		var tally: Label = RushSkin.label(
			card, "%d / 10  ·  %d / 30" % [cleared, stars], Rect2(256, 88, 134, 20), 14, ink
		)
		tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if not unlocked:
			var lock: Glyph = Glyph.new("lock", RushSkin.MUTED, true, 30.0)
			lock.position = Vector2(360, 14)
			card.add_child(lock)


func _levels(world_id: int) -> void:
	var world: Dictionary = registry.get_world(world_id)
	header(world.name, "PRACTICE / standard records stay separate" if practice else "Choose a route. Make it yours.")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroller().add_child(grid)
	var records: Dictionary = save.data.practice if practice else save.data.records
	for definition: Dictionary in world.levels:
		var id: int = int(definition.id)
		var record: Dictionary = records.get(str(id), {})
		var available: bool = practice or save.unlocked(id)
		var card: Button = RushSkin.card(grid, "%02d" % id, Vector2(202, 118), func() -> void: _select_level(id))
		card.add_theme_font_size_override("font_size", 28)
		card.disabled = not available
		_stripe(card, RushSkin.accent if available else RushSkin.MUTED)
		RushSkin.label(
			card,
			str(definition.name),
			Rect2(18, 48, 172, 38),
			14,
			RushSkin.MUTED if available else Color(RushSkin.MUTED, 0.6)
		)
		_level_footer(card, record, available)
		var kinds: Array[String] = _kinds(definition)
		for slot: int in range(kinds.size()):
			var icon: Glyph = Glyph.new(kinds[slot], RushSkin.accent if available else RushSkin.MUTED, true, 18.0)
			icon.position = Vector2(202 - 16 - (kinds.size() - slot) * 22, 14)
			card.add_child(icon)


func _level_footer(card: Button, record: Dictionary, available: bool) -> void:
	if not record.is_empty():
		for index: int in range(3):
			var earned: bool = index < int(record.stars)
			var star: Glyph = Glyph.new("star", RushSkin.GOLD if earned else RushSkin.MUTED, earned, 20.0)
			star.position = Vector2(18 + index * 24, 90)
			card.add_child(star)
	elif available:
		RushSkin.label(card, "READY", Rect2(18, 90, 120, 20), 13, RushSkin.accent)
	else:
		var lock: Glyph = Glyph.new("lock", RushSkin.MUTED, true, 20.0)
		lock.position = Vector2(18, 90)
		card.add_child(lock)
		RushSkin.label(card, "LOCKED", Rect2(44, 91, 120, 20), 13, RushSkin.MUTED)


func _select_level(id: int) -> void:
	selected = id
	navigate.emit("detail", int(registry.get_level(id).world))


func _detail() -> void:
	var definition: Dictionary = registry.get_level(selected)
	header("Route %02d" % selected, registry.get_world(definition.world).name.to_upper())
	var title: Label = RushSkin.heading(layer, definition.name, Rect2(32, 196, 416, 90), 34)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var subtitle: Label = RushSkin.label(layer, definition.subtitle, Rect2(32, 290, 416, 70), 21, RushSkin.MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_route_strip(definition, 388.0)
	RushSkin.label(
		layer,
		"%d GATES     /     PAR %.0fs" % [definition.stages.size(), definition.par],
		Rect2(32, 470, 416, 28),
		18,
		RushSkin.accent
	)
	var names: Array[String] = _kinds(definition)
	RushSkin.label(layer, " + ".join(names).to_upper(), Rect2(32, 502, 416, 40), 16, RushSkin.MUTED)
	var records: Dictionary = save.data.practice if practice else save.data.records
	var record: Dictionary = records.get(str(selected), {})
	_panel_record(record)
	RushSkin.button(
		layer,
		"PRACTICE ROUTE  →" if practice else "START ROUTE  →",
		Rect2(32, 730, 416, 72),
		func() -> void: play.emit(selected, practice),
		true
	)
	RushSkin.label(layer, "SPACE / TAP to propel   ·   P / ESC to pause", Rect2(32, 834, 416, 36), 16, RushSkin.MUTED)


func _panel_record(record: Dictionary) -> void:
	panel(layer, Rect2(32, 560, 416, 132))
	if record.is_empty():
		RushSkin.label(layer, "YOUR FIRST CLEAR IS WAITING", Rect2(54, 600, 372, 30), 20)
		RushSkin.label(layer, "Three stars: no retries, under par.", Rect2(54, 636, 372, 26), 16, RushSkin.MUTED)
		return
	RushSkin.label(layer, "PERSONAL BEST", Rect2(54, 576, 300, 22), 14, RushSkin.MUTED)
	for index: int in range(3):
		var earned: bool = index < int(record.stars)
		var star: Glyph = Glyph.new("star", RushSkin.GOLD if earned else RushSkin.MUTED, earned, 30.0)
		star.glow = true
		star.position = Vector2(54 + index * 38, 606)
		layer.add_child(star)
	RushSkin.heading(layer, "%s  /  %d pts" % [_time(record), record.score], Rect2(54, 648, 372, 30), 22)


func _route_strip(definition: Dictionary, y: float) -> void:
	var stages: Array = definition.stages
	var step: float = minf(52.0, (416.0 - 56.0) / stages.size())
	var start: Vector2 = Vector2(32, y)
	var orb: Glyph = Glyph.new("orb", RushSkin.COLORS[int(definition.start_color)], true, 36.0)
	orb.slot = int(definition.start_color)
	orb.position = start
	layer.add_child(orb)
	var link: ColorRect = ColorRect.new()
	link.color = RushSkin.LINE
	link.position = Vector2(68, y + 17.0)
	link.size = Vector2(56.0 + (stages.size() - 1) * step - 36.0 + 19.0, 2)
	link.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(link)
	for index: int in range(stages.size()):
		var x: float = 32.0 + 56.0 + index * step
		panel(layer, Rect2(x, y, 38, 38), RushSkin.SURFACE_HI)
		var icon: Glyph = Glyph.new(str(stages[index].kind), RushSkin.accent, true, 22.0)
		icon.position = Vector2(x + 8, y + 8)
		layer.add_child(icon)
		if bool(stages[index].checkpoint):
			var flag: Glyph = Glyph.new("switch", RushSkin.GOLD, true, 11.0)
			flag.position = Vector2(x + 13, y + 44)
			layer.add_child(flag)


func _stripe(card: Button, tint: Color) -> void:
	var stripe: ColorRect = ColorRect.new()
	stripe.color = Color(tint, 0.85)
	stripe.position = Vector2(0, 16)
	stripe.size = Vector2(4, card.custom_minimum_size.y - 32.0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stripe)


func _kinds(definition: Dictionary) -> Array[String]:
	var kinds: Array[String] = []
	for stage: Dictionary in definition.stages:
		if not kinds.has(str(stage.kind)):
			kinds.append(str(stage.kind))
	return kinds


func _time(record: Dictionary) -> String:
	return "time unknown" if float(record.seconds) <= 0.0 else "%.1fs" % record.seconds
