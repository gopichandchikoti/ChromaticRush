class_name HudView
extends Control
## Custom-drawn HUD furniture: gate progress pips with checkpoint marks and the orb colour chip.
## Text lives in real Labels (see RunScreens) so it stays accessible; this only draws shapes.

const PIPS_LEFT: float = 32.0
const PIPS_WIDTH: float = 220.0

var run: RunState
var calm: bool = false
var _clock: float = 0.0
var _pill: StyleBoxFlat


func _ready() -> void:
	size = Vector2(480, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill = RushSkin.style(Color(RushSkin.SURFACE, 0.9), Color(RushSkin.LINE, 1.0), 18)


func _process(delta: float) -> void:
	if not calm:
		_clock += delta
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	_pips()
	_chip()


func _pips() -> void:
	var count: int = run.level.stages.size()
	var width: float = minf(46.0, (PIPS_WIDTH - 6.0 * (count - 1)) / count)
	var accent: Color = RushSkin.accent
	for index: int in range(count):
		var x: float = PIPS_LEFT + index * (width + 6.0)
		var box: Rect2 = Rect2(x, 120, width, 8)
		var done: bool = index < run.stage_index
		var current: bool = index == run.stage_index
		var fill: Color = accent if done else RushSkin.LINE
		if current:
			var beat: float = 0.75 + 0.25 * sin(_clock * 5.0)
			fill = Color(RushSkin.TEXT, beat)
			draw_rect(box.grow(3.0), Color(RushSkin.TEXT, 0.1), true)
		draw_rect(box, fill, true)
		if bool(run.level.stages[index].checkpoint):
			var reached: bool = run.checkpoint > index
			var tip: Vector2 = Vector2(x + width, 112)
			var mark: PackedVector2Array = PackedVector2Array(
				[tip + Vector2(0, -4), tip + Vector2(4, 0), tip + Vector2(0, 4), tip + Vector2(-4, 0)]
			)
			draw_colored_polygon(mark, RushSkin.GOLD if reached else Color(RushSkin.MUTED, 0.55))


func _chip() -> void:
	draw_style_box(_pill, Rect2(32, 164, 262, 38))
	var center: Vector2 = Vector2(54, 183)
	var tint: Color = RushSkin.COLORS[run.color]
	draw_circle(center, 13.0, Color(tint, 0.22))
	draw_circle(center, 9.5, tint)
	RushSkin.marker(self, center, run.color, RushSkin.BG)
