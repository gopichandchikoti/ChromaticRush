class_name Glyph
extends Control
## Small vector icons drawn in code (no image assets): stars, lock and one mark per gate mechanic.

var kind: String = "star"
var tint: Color = Color.WHITE
var filled: bool = true
var glow: bool = false
var slot: int = 0


func _init(shape: String = "star", color: Color = Color.WHITE, solid: bool = true, edge: float = 24.0) -> void:
	kind = shape
	tint = color
	filled = solid
	custom_minimum_size = Vector2(edge, edge)
	size = Vector2(edge, edge)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) / 2.0 - 1.0
	match kind:
		"star":
			_star(c, r)
		"lock":
			_lock(c, r)
		"ring":
			_ring(c, r)
		"slide":
			_slide(c, r)
		"pendulum":
			_pendulum(c, r)
		"pulse":
			_pulse(c, r)
		"switch":
			_switch(c, r)
		"chain":
			_chain(c, r)
		"reverse":
			_reverse(c, r)
		"orb":
			draw_circle(c, r, Color(tint, 0.22))
			draw_circle(c, r * 0.72, tint)
			RushSkin.marker(self, c, slot, RushSkin.BG)
		"check":
			draw_polyline(
				PackedVector2Array([c + Vector2(-r, 0), c + Vector2(-r * 0.3, r * 0.6), c + Vector2(r, -r * 0.6)]),
				tint,
				2.5,
				true
			)


func _star(c: Vector2, r: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(10):
		var radius: float = r if index % 2 == 0 else r * 0.46
		points.append(c + Vector2.from_angle(-PI / 2.0 + index * PI / 5.0) * radius)
	if glow and filled:
		var halo: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in points:
			halo.append(c + (point - c) * 1.32)
		draw_colored_polygon(halo, Color(tint, 0.14))
	if filled:
		draw_colored_polygon(points, tint)
	else:
		points.append(points[0])
		draw_polyline(points, Color(tint, 0.55), 1.5, true)


func _lock(c: Vector2, r: float) -> void:
	draw_arc(c + Vector2(0, -r * 0.1), r * 0.5, PI, TAU, 16, tint, 2.2, true)
	draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.1), Vector2(r * 1.4, r * 1.0)), tint)
	draw_circle(c + Vector2(0, r * 0.4), r * 0.14, Color("0b1020"))


func _ring(c: Vector2, r: float) -> void:
	for index: int in range(4):
		var start: float = index * PI / 2.0 + 0.12
		draw_arc(c, r * 0.72, start, start + PI / 2.0 - 0.24, 10, RushSkin.COLORS[index], r * 0.3, true)


func _slide(c: Vector2, r: float) -> void:
	for index: int in range(3):
		var x: float = c.x + (index - 1) * r * 0.72
		draw_line(Vector2(x - r * 0.3, c.y), Vector2(x + r * 0.3, c.y), RushSkin.COLORS[index], r * 0.4, true)


func _pendulum(c: Vector2, r: float) -> void:
	var bob: Vector2 = c + Vector2(r * 0.5, r * 0.55)
	draw_line(c + Vector2(0, -r * 0.85), bob, Color(tint, 0.6), 1.4, true)
	draw_circle(c + Vector2(0, -r * 0.85), r * 0.1, Color(tint, 0.6))
	draw_circle(bob, r * 0.3, tint)


func _pulse(c: Vector2, r: float) -> void:
	var low: float = r * 0.45
	var high: float = -r * 0.45
	var wave: PackedVector2Array = PackedVector2Array(
		[
			c + Vector2(-r, low),
			c + Vector2(-r * 0.5, low),
			c + Vector2(-r * 0.5, high),
			c + Vector2(r * 0.1, high),
			c + Vector2(r * 0.1, low),
			c + Vector2(r, low)
		]
	)
	draw_polyline(wave, tint, 2.2, true)


func _switch(c: Vector2, r: float) -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]
	)
	draw_colored_polygon(points, tint)


func _chain(c: Vector2, r: float) -> void:
	draw_arc(c + Vector2(-r * 0.35, 0), r * 0.55, 0, TAU, 20, tint, 2.2, true)
	draw_arc(c + Vector2(r * 0.35, 0), r * 0.55, 0, TAU, 20, tint, 2.2, true)


func _reverse(c: Vector2, r: float) -> void:
	draw_line(c + Vector2(0, -r * 0.8), c + Vector2(0, r * 0.7), tint, 2.2, true)
	draw_polyline(
		PackedVector2Array([c + Vector2(-r * 0.5, r * 0.2), c + Vector2(0, r * 0.75), c + Vector2(r * 0.5, r * 0.2)]),
		tint,
		2.2,
		true
	)
