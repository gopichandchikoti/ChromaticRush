class_name GateRules
extends RefCounted

const KINDS: Array[String] = ["ring", "slide", "pendulum", "pulse", "switch", "reverse", "chain"]
const ORB_RADIUS: float = 11.0


static func sample(stage: Dictionary, time: float, contact: int = 0) -> int:
	var angle: float = time * float(stage.speed) + float(stage.phase)
	var offset: int = int(stage.offset)
	match str(stage.kind):
		"slide", "switch":
			return posmod(int(floor(2.0 - sin(angle) * 2.4)) + offset, 4)
		"pendulum":
			var span: float = float(stage.get("drift", 42.0)) / 20.0
			return posmod(int(floor(2.0 + sin(angle) * span)) + offset, 4)
		"pulse":
			return posmod(int(floor(angle / (PI / 2.0))) + offset, 4)
		"chain":
			return posmod(int(floor((angle + contact * 0.26) / (PI / 2.0))) + offset, 4)
		_:
			return posmod(int(floor(wrapf(PI / 2.0 - angle, 0.0, TAU) / (PI / 2.0))) + offset, 4)


static func is_open(stage: Dictionary, time: float) -> bool:
	if str(stage.kind) != "pulse":
		return true
	var cycle: float = fposmod(time * float(stage.speed) + float(stage.phase), PI / 2.0)
	return cycle < (PI / 2.0) * float(stage.get("width", 0.42))


static func matches(stage: Dictionary, time: float, color: int, contact: int = 0) -> bool:
	return is_open(stage, time) and sample(stage, time, contact) == color


static func contact_height(stage: Dictionary, contact: int = 0) -> float:
	return float(stage.gap) + contact * 54.0 - ORB_RADIUS


static func contacts(stage: Dictionary) -> int:
	return 2 if str(stage.kind) == "chain" else 1


static func crossing_time(before: float, after: float, height: float, time: float, delta: float) -> float:
	var fraction: float = clampf((height - before) / maxf(after - before, 0.00001), 0.0, 1.0)
	return time - delta + fraction * delta


static func next_window(stage: Dictionary, time: float, color: int, contact: int = 0) -> float:
	for tick: int in range(2400):
		var candidate: float = time + tick / 120.0
		if matches(stage, candidate, color, contact):
			return candidate - time
	return -1.0
