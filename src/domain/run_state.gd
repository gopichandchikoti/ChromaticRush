class_name RunState
extends RefCounted

const STEP: float = 1.0 / 120.0
const GRAVITY: float = 720.0
const IMPULSE: float = 510.0

var level: Dictionary
var stage_index: int = 0
var contact: int = 0
var color: int = 0
var altitude: float = 0.0
var velocity: float = 0.0
var elapsed: float = 0.0
var taps: int = 0
var deaths: int = 0
var checkpoint: int = 0
var checkpoint_color: int = 0
var status: String = "ready"
var mode: String = "standard"
var slow_time: bool = false
var last_event: String = ""
## Presentation hints, never read by the simulation itself.
var fail_color: int = -1
var fail_open: bool = true
var cleared_stage: Dictionary = {}
var cleared_color: int = 0
var cleared_time: float = 0.0
var _accumulator: float = 0.0
var _tap_cooldown: float = 0.0


func _init(definition: Dictionary, run_mode: String = "standard") -> void:
	level = definition
	mode = run_mode
	color = int(level.start_color)
	checkpoint_color = color


## True while the clock runs: waiting on the perch ("ready") and in flight ("playing").
func is_live() -> bool:
	return status == "ready" or status == "playing"


func stage() -> Dictionary:
	return level.stages[mini(stage_index, level.stages.size() - 1)]


func direction() -> float:
	return -1.0 if str(stage().kind) == "reverse" else 1.0


func tap() -> bool:
	if status in ["failed", "complete", "paused"] or _tap_cooldown > 0.000000001:
		return false
	status = "playing"
	velocity = IMPULSE
	taps += 1
	_tap_cooldown = 0.10
	return true


func advance(delta: float) -> void:
	last_event = ""
	if not is_live():
		return
	_accumulator += minf(delta, 0.5) * (0.7 if slow_time else 1.0)
	while _accumulator + 0.000000001 >= STEP and is_live():
		_tick(STEP)
		_accumulator = maxf(0.0, _accumulator - STEP)


func _tick(delta: float) -> void:
	var before: float = altitude
	elapsed += delta
	_tap_cooldown = maxf(0.0, _tap_cooldown - delta)
	velocity -= GRAVITY * delta
	altitude = maxf(0.0, altitude + velocity * delta)
	if altitude == 0.0:
		velocity = maxf(velocity, 0.0)
	var height: float = GateRules.contact_height(stage(), contact)
	if before < height and altitude >= height:
		_resolve_crossing(GateRules.crossing_time(before, altitude, height, elapsed, delta))


func _resolve_crossing(time: float) -> void:
	if not GateRules.matches(stage(), time, color, contact):
		fail_color = GateRules.sample(stage(), time, contact)
		fail_open = GateRules.is_open(stage(), time)
		status = "failed"
		deaths += 1
		last_event = "failed"
		return
	contact += 1
	last_event = "contact"
	if contact < GateRules.contacts(stage()):
		return
	cleared_stage = stage()
	cleared_color = color
	cleared_time = time
	if str(stage().kind) == "switch":
		color = int(stage().color)
	var keep_checkpoint: bool = bool(stage().checkpoint)
	stage_index += 1
	contact = 0
	altitude = 0.0
	velocity = 0.0
	last_event = "cleared"
	if keep_checkpoint:
		checkpoint = stage_index
		checkpoint_color = color
	if stage_index == level.stages.size():
		status = "complete"
		last_event = "complete"


func retry() -> void:
	stage_index = checkpoint
	color = checkpoint_color
	contact = 0
	altitude = 0.0
	velocity = 0.0
	_tap_cooldown = 0.0
	_accumulator = 0.0
	status = "ready"
	last_event = ""


func stars() -> int:
	if deaths == 0 and elapsed <= float(level.par):
		return 3
	return 2 if deaths <= 2 else 1


func score() -> int:
	return maxi(100, level.stages.size() * 1000 + stars() * 500 - int(elapsed * 10.0) - deaths * 200)


func snapshot() -> Dictionary:
	return {
		"level": int(level.id),
		"stage": checkpoint,
		"color": checkpoint_color,
		"mode": mode,
		"elapsed": elapsed,
		"taps": taps,
		"deaths": deaths
	}
