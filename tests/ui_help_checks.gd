extends RefCounted

const SECTIONS: Array[Array] = [
	["TAP / SPACE", "Propel the orb"],
	["MATCH AT CONTACT", "Your orb must match"],
	["WAIT ON THE PERCH", "The line below your orb"],
	["FOLLOW THE DIRECTION", "Inverse gates reverse gravity"],
	["MAKE IT YOURS", "Practice opens all 100 routes"],
]


static func verify(layer: Control, check: Callable) -> void:
	var wrapped: int = 0
	var previous_end: float = 170.0
	for section: Array in SECTIONS:
		var title: Label = _label(layer, str(section[0]))
		var body: Label = _label(layer, str(section[1]))
		check.call(title != null and body != null, "Help section has heading and explanatory body: %s" % section[0])
		if title == null or body == null:
			continue
		check.call(
			title.position.y >= previous_end and body.position.y >= title.position.y + title.size.y,
			"Help section does not overlap preceding text: %s" % section[0]
		)
		check.call(body.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Help body wraps: %s" % section[0])
		check.call(
			body.position.x >= 32 and body.position.x + body.size.x <= 448,
			"Help body stays inside horizontal margins: %s" % section[0]
		)
		check.call(
			body.get_line_count() * body.get_line_height() <= body.size.y,
			"Every wrapped help line fits the body height: %s" % section[0]
		)
		check.call(body.position.y + body.size.y <= 868, "Help remains above bottom margin: %s" % section[0])
		wrapped += 1 if body.get_line_count() > 1 else 0
		previous_end = body.position.y + body.size.y
	check.call(wrapped >= 4, "At least four explanatory bodies wrap into multiple real lines")


static func _label(layer: Control, prefix: String) -> Label:
	for node: Node in layer.find_children("*", "Label", true, false):
		if node is Label and node.is_visible_in_tree() and node.text.begins_with(prefix):
			return node
	return null
