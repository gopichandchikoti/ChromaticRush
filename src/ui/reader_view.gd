class_name ReaderView
extends RefCounted

const CONTENT_WIDTH: float = 400.0
const TEXT_WIDTH: float = 364.0


static func build(layer: Control, screen: String = "") -> void:
	var entries: Array[Control] = []
	_collect(layer, entries)
	if screen == "home":
		entries = _home_order(entries)
	for child: Node in layer.get_children():
		if child is Control:
			child.set_meta("reader_was_visible", child.is_visible_in_tree())
			child.hide()
	var background: ColorRect = ColorRect.new()
	background.name = "LargeText"
	background.set_meta("reader_screen", screen)
	background.color = RushSkin.BG
	background.size = Vector2(480, 900)
	layer.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ReaderScroll"
	scroll.position = Vector2(32, 20)
	scroll.size = Vector2(416, 860)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	background.add_child(scroll)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 24)
	scroll.add_child(rows)
	for entry: Control in entries:
		if entry is Button:
			_action(rows, entry)
		else:
			var source: Label = entry as Label
			_text(rows, source.text, source.get_theme_font_size("font_size") * 2, source.get_theme_color("font_color"))


static func refresh(layer: Control) -> void:
	var reader: Node = layer.get_node_or_null("LargeText")
	if reader == null:
		return
	var screen: String = str(reader.get_meta("reader_screen", ""))
	layer.remove_child(reader)
	reader.queue_free()
	for child: Node in layer.get_children():
		if child is Control and bool(child.get_meta("reader_was_visible", false)):
			child.show()
	build(layer, screen)


static func _home_order(entries: Array[Control]) -> Array[Control]:
	var summary: Array[Control] = []
	var actions: Array[Control] = []
	var rest: Array[Control] = []
	for entry: Control in entries:
		if entry is Button:
			if bool(entry.get_meta("primary", false)):
				actions.push_front(entry)
			elif entry.text == "SET":
				rest.append(entry)
			else:
				actions.append(entry)
		elif entry is Label:
			if "CLEARED" in entry.text:
				rest.append(entry)
			elif not entry.text in ["C H R O M A T I C", "RUSH", "PRECISION IN EVERY PULSE", "Chase the\nspectrum."]:
				summary.append(entry)
	return summary + actions + rest


static func _collect(parent: Node, entries: Array[Control]) -> void:
	for child: Node in parent.get_children():
		if not child is Control or not child.is_visible_in_tree():
			continue
		if child is Button:
			entries.append(child)
		elif child is Label and not child.text.is_empty():
			entries.append(child)
		else:
			_collect(child, entries)


static func _action(rows: VBoxContainer, source: Button) -> void:
	var proxy: Button = CheckButton.new() if source is CheckButton else Button.new()
	proxy.set_meta("reader_source", source.text)
	proxy.set_meta("primary", source.get_meta("primary", false))
	proxy.accessibility_name = source.accessibility_name
	proxy.accessibility_description = source.accessibility_description
	proxy.disabled = source.disabled
	var text: String = source.text
	if RushAccessibility.BUTTON_NAMES.has(text):
		text = source.accessibility_name
	var width: float = TEXT_WIDTH - (64.0 if source is CheckButton else 0.0)
	var font_size: int = source.get_theme_font_size("font_size") * 2
	var height: float = _height(text, font_size, width) + 40.0
	proxy.custom_minimum_size = Vector2(CONTENT_WIDTH, maxf(106.0, height))
	proxy.add_theme_stylebox_override("normal", RushSkin.style(RushSkin.SURFACE, RushSkin.LINE))
	proxy.add_theme_stylebox_override("focus", RushSkin.style(Color(1, 1, 1, 0.03), RushSkin.GOLD))
	rows.add_child(proxy)
	var label: Label = _text(proxy, text, font_size, RushSkin.MUTED if source.disabled else RushSkin.TEXT)
	label.position = Vector2(18, 20)
	label.size = Vector2(width, height - 40.0)
	if source is CheckButton:
		RushSkin.style_toggle(proxy)
		proxy.button_pressed = source.button_pressed
		proxy.toggled.connect(_toggle.bind(source))
	else:
		proxy.pressed.connect(source.pressed.emit)
	for child: Node in source.find_children("*", "Label", true, false):
		if child is Label and not child.text.is_empty():
			_text(rows, child.text, child.get_theme_font_size("font_size") * 2, RushSkin.MUTED)


static func _text(parent: Node, text: String, font_size: int, tint: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", RushSkin.font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(0, _height(text, font_size, CONTENT_WIDTH))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


static func _height(text: String, font_size: int, width: float) -> float:
	return RushSkin.font().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size).y + 8.0


static func _toggle(value: bool, source: Button) -> void:
	source.button_pressed = value
