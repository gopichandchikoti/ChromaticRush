class_name ScreenBase
extends RefCounted
## Shared scaffolding for menu screens: themed header and scrolling content column.

signal navigate(screen: String, world_id: int)

var layer: Control
var save: RushSave


func header(title: String, subtitle: String = "") -> void:
	RushSkin.button(layer, "←", Rect2(32, 26, 64, 64), func() -> void: navigate.emit("back", 1))
	RushSkin.heading(layer, title, Rect2(112, 26, 336, 48), 34)
	RushSkin.label(layer, subtitle, Rect2(32, 112, 416, 46), 18, RushSkin.MUTED)
	RushSkin.rule(layer, 170)
	var accent_bar: ColorRect = ColorRect.new()
	accent_bar.color = RushSkin.accent
	accent_bar.position = Vector2(32, 169)
	accent_bar.size = Vector2(72, 3)
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(accent_bar)


func column() -> VBoxContainer:
	var rows: VBoxContainer = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 12)
	scroller().add_child(rows)
	return rows


func scroller() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(32, 190)
	scroll.size = Vector2(416, 670)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	return scroll


func panel(parent: Control, rect: Rect2, tint: Color = RushSkin.SURFACE) -> Panel:
	var item: Panel = Panel.new()
	item.position = rect.position
	item.size = rect.size
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_stylebox_override("panel", RushSkin.style(Color(tint, 0.92), RushSkin.LINE, 16))
	parent.add_child(item)
	return item


func bar(parent: Control, rect: Rect2, fraction: float, tint: Color) -> void:
	for part: int in range(2):
		var piece: ColorRect = ColorRect.new()
		piece.color = RushSkin.LINE if part == 0 else tint
		piece.position = rect.position
		piece.size = Vector2(rect.size.x * (1.0 if part == 0 else clampf(fraction, 0.0, 1.0)), rect.size.y)
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(piece)
