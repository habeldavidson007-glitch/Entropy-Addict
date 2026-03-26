extends Control

var quest_label: Label

func _ready() -> void:
	# Connect to quest completed signal
	if GameData.has_signal("quest_completed"):
		GameData.quest_completed.connect(_on_quest_completed)
	
	_build_ui()
	_update_quest_display()

func _build_ui() -> void:
	# Quest panel in bottom-left
	var quest_panel := ColorRect.new()
	quest_panel.color = Color(0.1, 0.08, 0.12)
	quest_panel.size = Vector2(350, 120)
	quest_panel.position = Vector2(20, 420)
	add_child(quest_panel)
	
	var title := Label.new()
	title.text = "★ ACTIVE QUESTS"
	title.add_theme_font_size_override("font_size", 12)
	title.modulate = Color(0.9, 0.7, 0.3)
	title.position = Vector2(10, 8)
	quest_panel.add_child(title)
	
	quest_label = Label.new()
	quest_label.position = Vector2(10, 30)
	quest_label.custom_minimum_size = Vector2(330, 80)
	quest_label.add_theme_font_size_override("font_size", 11)
	quest_label.modulate = Color(0.8, 0.8, 0.8)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_panel.add_child(quest_label)

func _update_quest_display() -> void:
	if not quest_label:
		return
	
	var active_quests = GameData.get_active_quests() if GameData.has_method("get_active_quests") else []
	
	if active_quests.size() == 0:
		quest_label.text = "No active quests"
		quest_label.modulate = Color(0.6, 0.6, 0.6)
	else:
		var text = ""
		for quest in active_quests:
			text += "◆ %s\n" % quest.title
			text += "  %s\n" % quest.description
			text += "  Progress: %d/%d\n" % [quest.current, quest.requirement]
			text += "\n"
		quest_label.text = text

func _on_quest_completed(quest_id: String) -> void:
	if quest_label:
		var quest = GameData.quests.get(quest_id)
		if quest:
			quest_label.text += "\n✓ COMPLETED: %s!\nReward: %d XP" % [quest.title, quest.reward_xp]
			quest_label.modulate = Color(0.4, 0.9, 0.4)
