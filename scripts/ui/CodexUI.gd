extends Control

var player_stats = null
var current_profile: CharacterProfile = null

# UI elements
var ui_labels = {}

func _ready():
	visible = false
	print("[CodexUI] Ready - waiting for signal")
	
	# Get parent and connect signal
	var parent = get_parent()
	if parent:
		print("[CodexUI] Parent is: ", parent.name)
		if parent.has_signal("codex_open_requested"):
			parent.codex_open_requested.connect(_on_open_codex)
			print("[CodexUI] Signal connected successfully!")
		else:
			print("[CodexUI] ERROR: Parent has no codex_open_requested signal")
	else:
		print("[CodexUI] ERROR: No parent found")

func _input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		visible = false

func _on_open_codex(profile: CharacterProfile):
	current_profile = profile
	visible = true
	print("[CodexUI] Opening for: ", profile.character_name)
	_update_display()

func _update_display():
	if not current_profile:
		return
	
	# Find all labels
	var all_labels = _find_all_labels(self)
	
	for label in all_labels:
		if label.name == "NameLabel":
			label.text = current_profile.character_name
			label.visible = true
		elif label.name == "LevelLabel":
			label.text = "Level %d" % current_profile.level
			label.visible = true
		elif label.name == "CallLabel":
			label.text = "Call: %s" % current_profile.call_title
			label.visible = true
		elif label.name == "FateLabel":
			var fate = current_profile.fate_title if current_profile.fate_title != "" else "Unwritten"
			label.text = "Fate: %s" % fate
			label.visible = true
		elif label.name == "RoleLabel":
			label.text = "Role: %s" % current_profile.field_role
			label.visible = true
		elif label.name == "Mastery1Label":
			label.text = "%s (Lv. %d)" % [current_profile.mastery_1_name, current_profile.mastery_1_level]
			label.visible = true
		elif label.name == "Mastery2Label":
			label.text = "%s (Lv. %d)" % [current_profile.mastery_2_name, current_profile.mastery_2_level]
			label.visible = true
		elif label.name == "StageLabel":
			label.text = "Root Stage: %s" % current_profile.root_stage
			label.visible = true
		elif label.name == "HabitLogLabel":
			if current_profile.current_habit_log.size() > 0:
				label.text = "Recent Habits:\n" + "\n".join(current_profile.current_habit_log)
			else:
				label.text = "No habits recorded."
			label.visible = true

func _find_all_labels(node: Node) -> Array:
	var labels = []
	for child in node.get_children():
		if child is Label:
			labels.append(child)
		labels.append_array(_find_all_labels(child))
	return labels
