class_name Backdrop
extends Control
## World-themed background that fills the whole window. A GPU gradient supplies depth; a few dozen
## low-alpha motif shapes (different in every world) drift over it. Redrawn at 30 Hz, frozen when calm.

var calm: bool = false
var dim: float = 0.0
var _world: int = 0
var _clock: float = 0.0
var _since_draw: float = 0.0
var _motif: String = "stars"
var _tint: Color = Color.WHITE
var _items: Array[Dictionary] = []
var _sky: GradientTexture2D
var _glow: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky = _make_texture(GradientTexture2D.FILL_LINEAR, Vector2(0, 0), Vector2(0, 1))
	_glow = _make_texture(GradientTexture2D.FILL_RADIAL, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	var vignette: GradientTexture2D = _make_texture(
		GradientTexture2D.FILL_RADIAL, Vector2(0.5, 0.5), Vector2(1.0, 0.85)
	)
	vignette.gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	vignette.gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.02, 0.03, 0.06, 0.62)])
	for texture: GradientTexture2D in [_sky, _glow, vignette]:
		var rect: TextureRect = TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(rect)
	var requested: int = maxi(_world, 1)
	_world = 0  # force a full rebuild now that the textures exist
	set_world(requested)


func set_world(id: int) -> void:
	if id == _world and not _items.is_empty():
		return
	_world = id
	var theme: Dictionary = RushSkin.theme_of(id)
	_motif = str(theme.motif)
	_tint = theme.accent
	if _sky != null:
		_sky.gradient.colors = PackedColorArray([theme.top, theme.bottom])
		_glow.gradient.colors = PackedColorArray([Color(_tint, 0.2), Color(_tint, 0.0)])
	_build()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	if not calm:
		_clock += delta
	_since_draw += delta
	if _since_draw >= 1.0 / 30.0:
		_since_draw = 0.0
		queue_redraw()


func _draw() -> void:
	match _motif:
		"stars":
			_stars()
		"waves":
			_waves()
		"prisms":
			_prisms()
		"sparks":
			_sparks()
		"arcs":
			_arcs()
		"streaks":
			_streaks()
		"embers":
			_embers()
		"beams":
			_beams()
		"ribbons":
			_ribbons()
		"horizon":
			_horizon()
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.09, dim))


func _make_texture(fill: int, from: Vector2, to: Vector2) -> GradientTexture2D:
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = Gradient.new()
	texture.fill = fill
	texture.fill_from = from
	texture.fill_to = to
	texture.width = 64
	texture.height = 128
	return texture


func _build() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7919 * _world
	_items.clear()
	var count: int = 30
	match _motif:
		"waves", "ribbons":
			count = 6
		"prisms", "beams", "arcs":
			count = 9
		"streaks":
			count = 24
	for index: int in range(count):
		_items.append(
			{
				"x": rng.randf(),
				"y": rng.randf(),
				"s": rng.randf_range(0.6, 1.0),
				"p": rng.randf() * TAU,
				"d": -1.0 if index % 2 == 0 else 1.0
			}
		)


func _at(item: Dictionary, drift: float, speed: float) -> Vector2:
	return Vector2(float(item.x) * size.x, fposmod(float(item.y) + drift * speed * float(item.s), 1.0) * size.y)


func _stars() -> void:
	for item: Dictionary in _items:
		var twinkle: float = 0.5 + 0.5 * sin(_clock * 1.2 + float(item.p))
		draw_circle(
			_at(item, -_clock, 0.006), 1.0 + float(item.s) * 1.7, Color(_tint, 0.22 + 0.5 * twinkle * float(item.s))
		)


func _waves() -> void:
	for index: int in range(_items.size()):
		var base: float = size.y * (0.2 + index * 0.13)
		var points: PackedVector2Array = PackedVector2Array()
		for x: int in range(0, int(size.x) + 24, 24):
			points.append(
				Vector2(x, base + sin(x * 0.012 + _clock * (0.4 + index * 0.07) + index) * (14.0 + index * 3.0))
			)
		draw_polyline(points, Color(_tint, 0.1), 1.5, true)
		var node: float = fposmod(float(_items[index].x) + _clock * 0.02 * float(_items[index].d), 1.0) * size.x
		draw_circle(
			Vector2(node, base + sin(node * 0.012 + _clock * (0.4 + index * 0.07) + index) * (14.0 + index * 3.0)),
			2.6,
			Color(_tint, 0.45)
		)


func _prisms() -> void:
	for item: Dictionary in _items:
		var center: Vector2 = _at(item, _clock, 0.004) + Vector2(sin(_clock * 0.2 + float(item.p)) * 18.0, 0)
		var radius: float = 26.0 + float(item.s) * 34.0
		var turn: float = float(item.p) + _clock * 0.12 * float(item.d)
		var points: PackedVector2Array = PackedVector2Array()
		for corner: int in range(4):
			points.append(center + Vector2.from_angle(turn + corner * TAU / 3.0) * radius)
		draw_polyline(points, Color(_tint, 0.13), 1.4, true)


func _sparks() -> void:
	for item: Dictionary in _items:
		var point: Vector2 = _at(item, -_clock, 0.03)
		var fade: float = sin(clampf(point.y / size.y, 0.0, 1.0) * PI)
		draw_line(point, point + Vector2(0, 6.0 + 10.0 * float(item.s)), Color(_tint, 0.42 * fade), 1.6, true)
	for index: int in range(3):
		var x: float = fposmod(_clock * (0.05 + index * 0.02) + index * 0.33, 1.4) * size.x - size.x * 0.2
		var y: float = size.y * (0.3 + index * 0.25)
		draw_line(Vector2(x, y), Vector2(x + 140, y), Color(_tint, 0.12), 2.0, true)


func _arcs() -> void:
	for item: Dictionary in _items:
		var center: Vector2 = Vector2(float(item.x) * size.x, float(item.y) * size.y)
		var start: float = float(item.p) + _clock * 0.1 * float(item.d)
		draw_arc(center, 60.0 + float(item.s) * 150.0, start, start + 1.3, 36, Color(_tint, 0.11), 1.6, true)


func _streaks() -> void:
	for item: Dictionary in _items:
		var point: Vector2 = _at(item, _clock, 0.05)
		draw_line(point, point - Vector2(3, 26.0 * float(item.s)), Color(_tint, 0.2), 1.3, true)


func _embers() -> void:
	for item: Dictionary in _items:
		var point: Vector2 = _at(item, -_clock, 0.02)
		point.x += sin(_clock * 0.8 + float(item.p)) * 12.0
		var fade: float = sin(clampf(point.y / size.y, 0.0, 1.0) * PI)
		draw_circle(point, 1.0 + float(item.s) * 1.6, Color(_tint, 0.5 * fade))


func _beams() -> void:
	for item: Dictionary in _items:
		var x: float = float(item.x) * size.x + sin(_clock * 0.25 + float(item.p)) * 14.0
		var width: float = 12.0 + float(item.s) * 26.0
		var shimmer: float = 0.5 + 0.5 * sin(_clock * 0.5 + float(item.p))
		draw_rect(Rect2(x - width / 2.0, 0, width, size.y), Color(_tint, 0.02 + 0.03 * shimmer))
	for radius: float in [120.0, 210.0, 300.0]:
		draw_arc(Vector2(size.x / 2.0, size.y + 20.0), radius, PI, TAU, 56, Color(_tint, 0.09), 1.5, true)


func _ribbons() -> void:
	for index: int in range(_items.size()):
		var points: PackedVector2Array = PackedVector2Array()
		var base: float = size.y * (0.14 + index * 0.15)
		for x: int in range(0, int(size.x) + 20, 20):
			points.append(
				Vector2(
					x, base + sin(x * 0.008 + _clock * 0.35 + index * 1.7) * 30.0 + sin(x * 0.02 - _clock * 0.3) * 12.0
				)
			)
		draw_polyline(points, Color(_tint, 0.12), 2.0, true)


func _horizon() -> void:
	var y: float = size.y * 0.62
	for strip: int in range(8):
		var fade: float = 1.0 - absf(strip - 3.5) / 4.0
		draw_rect(Rect2(0, y + (strip - 4) * 12.0, size.x, 12.0), Color(_tint, 0.045 * fade))
	for item: Dictionary in _items:
		var point: Vector2 = _at(item, -_clock, 0.008)
		draw_circle(point, 0.9 + float(item.s), Color(_tint, 0.28 * float(item.s)))
	for ray: int in range(-3, 4):
		draw_line(
			Vector2(size.x / 2.0, y), Vector2(size.x / 2.0 + ray * size.x * 0.22, 0), Color(_tint, 0.03), 1.5, true
		)
