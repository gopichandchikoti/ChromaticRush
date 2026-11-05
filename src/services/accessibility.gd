class_name RushAccessibility
extends RefCounted

const BUTTON_NAMES: Dictionary = {"←": "Back", "Ⅱ": "Pause game", "SET": "Settings"}
const DESCRIPTIONS: Dictionary = {
	"Practice": "All one hundred routes are open. Results stay separate from standard records.",
	"CONTINUE": "Resume the saved standard route and its checkpoint.",
	"TRY AGAIN": "Return to the last earned checkpoint. Retry count and elapsed time are retained.",
	"TAP TO PROPEL": "Propel the orb toward the exit. Space or an arena tap performs the same action.",
	"Large text": "Double interface text and reflow menus into a scrolling layout. Gameplay timing is unchanged."
}


static func label_control(control: Control, text: String) -> void:
	control.accessibility_name = BUTTON_NAMES.get(text, _plain(text))
	for prefix: String in DESCRIPTIONS:
		if text.begins_with(prefix):
			control.accessibility_description = DESCRIPTIONS[prefix]
			break


static func prepare(layer: Control, screen: String, run: RunState, large_text: bool) -> void:
	_describe(layer)
	if large_text:
		if screen == "game":
			AccessibleHud.build(layer, run, bool(layer.get_meta("guide", false)))
		else:
			ReaderView.build(layer, screen)
	_describe(layer)
	_connect_focus(layer)
	update_status(layer, run)


static func update_status(layer: Control, run: RunState) -> void:
	if run == null:
		return
	var summary: String = (
		"Route %d, gate %d of %d. Orb %s. %s."
		% [
			run.level.id,
			mini(run.stage_index + 1, run.level.stages.size()),
			run.level.stages.size(),
			RushSkin.NAMES[run.color],
			str(run.stage().kind)
		]
	)
	if run.status in ["failed", "paused", "complete"]:
		summary += " " + run.status.capitalize() + "."
	for node: Node in layer.find_children("*", "Label", true, false):
		if not node is Label or not node.is_visible_in_tree():
			continue
		if node.accessibility_name != _plain(node.text):
			node.accessibility_name = _plain(node.text)
		if node.text.begins_with(RushSkin.NAMES[run.color]):
			if node.accessibility_description != summary:
				node.accessibility_description = summary
				node.accessibility_live = AccessibilityServer.LIVE_POLITE


static func prefers_reduced_motion(requested: bool) -> bool:
	return requested or DisplayServer.accessibility_should_reduce_animation() == 1


static func _describe(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is Button:
			if child.accessibility_name.is_empty():
				label_control(child, child.text)
			var details: Array[String] = []
			for label: Node in child.find_children("*", "Label", true, false):
				if label is Label and not label.text.is_empty():
					details.append(label.text)
			if not details.is_empty() and child.accessibility_description.is_empty():
				child.accessibility_description = " ".join(details)
		elif child is Label:
			child.accessibility_name = _plain(child.text)
		_describe(child)


static func _connect_focus(layer: Control) -> void:
	var controls: Array[Control] = []
	for node: Node in layer.find_children("*", "BaseButton", true, false):
		if node is BaseButton and node.is_visible_in_tree() and not node.disabled:
			if node.focus_mode != Control.FOCUS_NONE:
				controls.append(node)
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[posmod(index - 1, controls.size())])
		control.accessibility_flow_to_nodes = [control.focus_next]


static func _plain(text: String) -> String:
	return text.replace("→", "").replace("↑", "").replace("★", " stars ").strip_edges()
