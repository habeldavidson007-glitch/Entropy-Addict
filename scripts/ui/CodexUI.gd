extends Control

var player_stats = null
var current_profile: CharacterProfile = null

func _ready():
	visible = false
	
	# Get player (parent node)
	player_stats = get_parent()
	
	# Connect signals
	if player_stats and player_stats.has_signal("codex_open_requested"):
		player_stats.codex_open_requested.connect(_on_open_codex)
	
	print("[CodexUI] Ready. Player: ", player_stats)

func _input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		visible = false

func _on_open_codex(profile: CharacterProfile):
	current_profile = profile
	visible = true
	print("[CodexUI] Opening for: ", profile.character_name)
	print("[CodexUI] Profile Level: ", profile.level)
	print("[CodexUI] Profile XP: ", profile.xp, "/", profile.xp_to_next_level)
	
	# Build the display text
	_build_display()

func _build_display():
	if not current_profile:
		return
	
	# Find all labels by searching from root
	var all_labels = _get_all_labels(self)
	
	print("[CodexUI] Found ", all_labels.size(), " labels in scene")
	
	# Update each label if it exists
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
			label.text = "Fate: %s" % (current_profile.fate_title if current_profile.fate_title != "" else "Unwritten")
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
			label.text = "No habits recorded."
			label.visible = true
	
	print("[CodexUI] Display built")

func _get_all_labels(node: Node) -> Array:
	var labels = []
	for child in node.get_children():
		if child is Label:
			labels.append(child)
		# Also check grandchildren
		labels.append_array(_get_all_labels(child))
	return labels
