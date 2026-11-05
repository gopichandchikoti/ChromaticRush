extends SceneTree

const Feedback = preload("res://src/ui/effects.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	var effects: Feedback = Feedback.new()
	for index: int in range(100):
		effects.burst(Vector2(index, 30), Color.CYAN)
		effects.ring(Vector2.ZERO, Color.CYAN)
		effects.shatter(Vector2.ZERO, Color.CYAN)
		effects.follow(Vector2(index, 0), true)
	_check(effects._sparks.size() == Feedback.MAX_SPARKS, "Repeated bursts retain a bounded spark budget")
	_check(effects._rings.size() == Feedback.MAX_RINGS, "Repeated contacts retain a bounded ring budget")
	_check(effects._shards.size() == Feedback.MAX_SHARDS, "Repeated failures retain a bounded shard budget")
	_check(effects._trail.size() == Feedback.TRAIL_LENGTH, "Flight trail is bounded between updates")
	effects.shake(1.0)
	effects.update(0.1)
	_check(not effects.offset().is_zero_approx(), "Normal feedback can shake the playfield")
	effects.calm = true
	_check(_empty(effects) and effects.offset().is_zero_approx(), "Enabling reduced motion clears existing feedback")
	effects.burst(Vector2.ZERO, Color.CYAN)
	effects.ring(Vector2.ZERO, Color.CYAN)
	effects.shatter(Vector2.ZERO, Color.CYAN)
	effects.follow(Vector2.ZERO, true)
	effects.shake(1.0)
	effects.update(0.1)
	_check(_empty(effects) and effects.offset().is_zero_approx(), "Reduced motion suppresses all decorative effects")
	effects.calm = false
	effects.burst(Vector2.ZERO, Color.CYAN)
	effects.ring(Vector2.ZERO, Color.CYAN)
	effects.shatter(Vector2.ZERO, Color.CYAN)
	effects.update(2.0)
	_check(_empty(effects), "Expired feedback releases its transient state")
	_test_adaptive()
	print(JSON.stringify({"suite": "presentation effects", "checks": checks, "failures": failures}))
	quit(1 if failures else 0)


func _empty(effects: Feedback) -> bool:
	return (
		effects._sparks.is_empty()
		and effects._rings.is_empty()
		and effects._shards.is_empty()
		and effects._trail.is_empty()
	)


func _test_adaptive() -> void:
	var effects: Feedback = Feedback.new()
	_fill(effects)
	for _frame: int in range(Feedback.SLOW_FRAMES - 1):
		effects.observe_frame(0.03)
	_check(not effects.low_quality, "A short slow-frame burst does not change quality")
	effects.observe_frame(0.03)
	_check(effects.low_quality, "Sustained slow rendering lowers only decorative quality")
	_check(_low_caps(effects), "Switching quality immediately trims existing feedback to the low budget")
	_fill(effects)
	_check(_low_caps(effects), "New low-quality bursts, rings, shards and trails stay within budget")
	for _frame: int in range(Feedback.RECOVERY_FRAMES):
		effects.observe_frame(0.021)
	_check(effects.low_quality, "Neutral frame times do not cause quality oscillation")
	for _frame: int in range(Feedback.RECOVERY_FRAMES - 1):
		effects.observe_frame(0.016)
	_check(effects.low_quality, "Recovery waits for the full sustained healthy interval")
	effects.observe_frame(0.016)
	_check(not effects.low_quality, "Sustained healthy rendering restores full decorative quality")
	_fill(effects)
	_check(effects._sparks.size() == Feedback.MAX_SPARKS, "Recovered quality uses the full spark budget")
	for _cycle: int in range(3):
		for _frame: int in range(Feedback.SLOW_FRAMES - 1):
			effects.observe_frame(0.03)
		effects.observe_frame(0.016)
	_check(not effects.low_quality, "Interrupted slow intervals cannot accumulate into a false downgrade")
	effects.calm = true
	_check(_empty(effects), "Reduced-motion mode still clears feedback after adaptive transitions")


func _fill(effects: Feedback) -> void:
	for index: int in range(100):
		effects.burst(Vector2.ZERO, Color.CYAN)
		effects.ring(Vector2.ZERO, Color.CYAN)
		effects.shatter(Vector2.ZERO, Color.CYAN)
		effects.follow(Vector2(index, 0), true)


func _low_caps(effects: Feedback) -> bool:
	return (
		effects._sparks.size() <= Feedback.LOW_SPARKS
		and effects._shards.size() <= Feedback.LOW_SHARDS
		and effects._rings.size() <= Feedback.LOW_RINGS
		and effects._trail.size() <= Feedback.LOW_TRAIL
	)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(message)
