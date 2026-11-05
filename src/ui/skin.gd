class_name RushSkin
extends RefCounted
## Design tokens and widget factories. The four gate colours never change; each world adds its own
## accent, gradient and motif so the ten chapters are recognisable at a glance.

const BG: Color = Color("0b1020")
const SURFACE: Color = Color("131c30")
const SURFACE_HI: Color = Color("1a2540")
const TEXT: Color = Color("f5f2e8")
const MUTED: Color = Color("9ba7bf")
const LINE: Color = Color("26344f")
const GOLD: Color = Color("f4ca64")
const COLORS: Array[Color] = [Color("58e1df"), Color("ff8278"), Color("f4ca64"), Color("b69aff")]
const NAMES: Array[String] = ["CYAN / 1", "CORAL / 2", "GOLD / 3", "IRIS / 4"]
const WORLDS: Array[Dictionary] = [
	{"accent": "58e1df", "top": "0a1124", "bottom": "10243c", "motif": "stars"},
	{"accent": "77d4ea", "top": "07161f", "bottom": "0b3140", "motif": "waves"},
	{"accent": "b69aff", "top": "141326", "bottom": "2a1d4a", "motif": "prisms"},
	{"accent": "f4ca64", "top": "1a1116", "bottom": "3a2418", "motif": "sparks"},
	{"accent": "ff8278", "top": "0f1622", "bottom": "26213a", "motif": "arcs"},
	{"accent": "9cafff", "top": "120f26", "bottom": "1b2a56", "motif": "streaks"},
	{"accent": "f7a078", "top": "1c1216", "bottom": "42261b", "motif": "embers"},
	{"accent": "72e9cc", "top": "0b1620", "bottom": "0e3a3a", "motif": "beams"},
	{"accent": "c7a1ef", "top": "170f24", "bottom": "34204a", "motif": "ribbons"},
	{"accent": "f5f2e8", "top": "141c27", "bottom": "303b51", "motif": "horizon"},
]

static var world: int = 1
static var accent: Color = Color("58e1df")
static var _switch_icons: Dictionary = {}
static var calm: bool = false


static func set_world(id: int) -> void:
	world = clampi(id, 1, WORLDS.size())
	accent = Color(str(WORLDS[world - 1].accent))


static func theme_of(id: int) -> Dictionary:
	var entry: Dictionary = WORLDS[clampi(id - 1, 0, WORLDS.size() - 1)]
	return {
		"accent": Color(str(entry.accent)),
		"top": Color(str(entry.top)),
		"bottom": Color(str(entry.bottom)),
		"motif": str(entry.motif)
	}


static func font(bold: bool = false) -> Font:
	return load("res://assets/SpaceGrotesk-%s.ttf" % ("Bold" if bold else "Regular")) as Font


static func label(parent: Node, text: String, box: Rect2, size: int = 20, color: Color = TEXT) -> Label:
	var item: Label = Label.new()
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.text = text
	RushAccessibility.label_control(item, text)
	item.position = box.position
	item.size = box.size
	item.add_theme_font_override("font", font())
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	item.size = box.size
	return item


static func heading(parent: Node, text: String, box: Rect2, size: int = 38) -> Label:
	var item: Label = label(parent, text, box, size)
	item.add_theme_font_override("font", font(true))
	return item


static func style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 14) -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	result.set_border_width_all(1)
	result.border_color = border
	result.content_margin_left = 18
	result.content_margin_right = 18
	result.anti_aliasing = true
	return result


static func button(parent: Node, text: String, box: Rect2, action: Callable, primary: bool = false) -> Button:
	var item: Button = Button.new()
	item.text = text
	RushAccessibility.label_control(item, text)
	item.position = box.position
	item.size = box.size
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.custom_minimum_size = Vector2(maxf(box.size.x, 66.0), maxf(box.size.y, 66.0))
	item.set_meta("primary", primary)
	item.add_theme_font_override("font", font(true))
	item.add_theme_font_size_override("font_size", 21)
	var fill: Color = accent if primary else SURFACE
	var ink: Color = BG if primary else TEXT
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		item.add_theme_color_override(state, ink)
	item.add_theme_color_override("font_disabled_color", Color(MUTED, 0.55))
	var rim: Color = Color(accent, 0.0) if primary else Color(LINE, 1.0)
	item.add_theme_stylebox_override("normal", style(fill, rim))
	item.add_theme_stylebox_override("hover", style(fill.lightened(0.1), accent))
	item.add_theme_stylebox_override("pressed", style(fill.darkened(0.12), TEXT))
	item.add_theme_stylebox_override("focus", style(Color(1, 1, 1, 0.03), GOLD))
	item.add_theme_stylebox_override("disabled", style(Color(SURFACE, 0.55), Color(LINE, 0.6)))
	item.pressed.connect(action)
	item.button_down.connect(_press_feel.bind(item, true))
	item.button_up.connect(_press_feel.bind(item, false))
	parent.add_child(item)
	return item


static func rule(parent: Node, y: float, width: float = 416.0) -> void:
	var line: ColorRect = ColorRect.new()
	line.color = LINE
	line.position = Vector2(32, y)
	line.size = Vector2(width, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


## Recolour a button's fill (used where the world accent would be mistaken for a gate colour).
static func recolor(item: Button, fill: Color) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var box: StyleBoxFlat = item.get_theme_stylebox(state) as StyleBoxFlat
		box.bg_color = fill if state == "normal" else (fill.lightened(0.1) if state == "hover" else fill.darkened(0.12))


## Card-style button: the Button owns the number/title text (so it stays a real, focusable control);
## decorations are non-interactive children.
static func card(parent: Node, text: String, size: Vector2, action: Callable) -> Button:
	var item: Button = button(parent, text, Rect2(Vector2.ZERO, size), action)
	item.custom_minimum_size = size
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.clip_text = true
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxFlat = item.get_theme_stylebox(state) as StyleBoxFlat
		box.content_margin_top = 12
		box.content_margin_bottom = size.y - 50
	return item


## A pill switch that reads clearly in both states (the stock CheckButton art is almost invisible here).
static func style_toggle(toggle: CheckButton) -> void:
	toggle.add_theme_icon_override("checked", _switch_icon(true))
	toggle.add_theme_icon_override("unchecked", _switch_icon(false))
	toggle.add_theme_icon_override("checked_disabled", _switch_icon(true))
	toggle.add_theme_icon_override("unchecked_disabled", _switch_icon(false))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		toggle.add_theme_color_override(state, TEXT)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = style(Color(SURFACE, 0.0), Color.TRANSPARENT, 12)
		if state == "focus":
			box = style(Color(1, 1, 1, 0.03), GOLD, 12)
		box.content_margin_left = 10
		box.content_margin_right = 8
		toggle.add_theme_stylebox_override(state, box)
	toggle.add_theme_constant_override("h_separation", 10)


## Colour-identity marker (circle, triangle, diamond, square) so hue is never the only cue.
static func marker(canvas: CanvasItem, p: Vector2, index: int, ink: Color) -> void:
	match index:
		0:
			canvas.draw_circle(p, 3.6, ink)
		1:
			canvas.draw_colored_polygon(
				PackedVector2Array([p + Vector2(0, -4.5), p + Vector2(4.5, 3.5), p + Vector2(-4.5, 3.5)]), ink
			)
		2:
			canvas.draw_colored_polygon(
				PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), ink
			)
		3:
			canvas.draw_rect(Rect2(p - Vector2(3.5, 3.5), Vector2(7, 7)), ink)


static func _press_feel(item: Button, down: bool) -> void:
	if not is_instance_valid(item) or item.disabled:
		return
	if calm:
		item.scale = Vector2.ONE
		return
	item.pivot_offset = item.size / 2.0
	var tween: Tween = item.create_tween()
	tween.tween_property(item, "scale", Vector2.ONE * (0.97 if down else 1.0), 0.07)


static func _switch_icon(on: bool) -> Texture2D:
	var key: String = "%s-%s" % [on, accent.to_html()]
	if _switch_icons.has(key):
		return _switch_icons[key]
	var width: int = 56
	var height: int = 32
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var track: Color = accent if on else Color(LINE, 1.0).lightened(0.12)
	var knob_x: float = width - height / 2.0 if on else height / 2.0
	for y: int in range(height):
		for x: int in range(width):
			var along: float = clampf(float(x), height / 2.0, width - height / 2.0)
			var edge: float = Vector2(x + 0.5, y + 0.5).distance_to(Vector2(along, height / 2.0)) - (height / 2.0 - 1.0)
			var pixel: Color = Color(track, clampf(0.5 - edge, 0.0, 1.0))
			var knob: float = (
				Vector2(x + 0.5, y + 0.5).distance_to(Vector2(knob_x, height / 2.0)) - (height / 2.0 - 5.0)
			)
			var cover: float = clampf(0.5 - knob, 0.0, 1.0)
			image.set_pixel(x, y, pixel.lerp(Color(TEXT if on else MUTED, 1.0), cover) if cover > 0.0 else pixel)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_switch_icons[key] = texture
	return texture
