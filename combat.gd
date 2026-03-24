extends Control

var player_hp: int = 100
var enemy_hp: int = 80
var player_max_hp: int = 100
var enemy_max_hp: int = 80
var player_turn: bool = true
var combat_over: bool = false
var defending: bool = false
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var player_hp_label: Label
var enemy_hp_label: Label
var log_label: Label
var action_container: HBoxContainer
var initiative_label: Label
var roll_btn: Button

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var atmos := Label.new()
	atmos.text = "— ENCOUNTER —"
	atmos.add_theme_font_size_override("font_size", 14)
	atmos.modulate = Color(0.4, 0.3, 0.4)
	atmos.position = Vector2(494, 30)
	add_child(atmos)
	
	var player_bg := ColorRect.new()
	player_bg.color = Color(0.08, 0.08, 0.12)
	player_bg.size = Vector2(300, 160)
	player_bg.position = Vector2(60, 80)
	add_child(player_bg)
	
	var player_name_lbl := Label.new()
	player_name_lbl.text = GameData.player_emoticon + "   " + GameData.player_name
	player_name_lbl.add_theme_font_size_override("font_size", 22)
	player_name_lbl.modulate = GameData.player_color
	player_name_lbl.position = Vector2(76, 96)
	add_child(player_name_lbl)
	
	var player_habit_lbl := Label.new()
	player_habit_lbl.text = "First habit: %s" % GameData.first_habit.left(40)
	player_habit_lbl.add_theme_font_size_override("font_size", 11)
	player_habit_lbl.modulate = Color(0.45, 0.45, 0.45)
	player_habit_lbl.position = Vector2(76, 128)
	add_child(player_habit_lbl)
	
	player_hp_bar = ProgressBar.new()
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp
	player_hp_bar.size = Vector2(268, 20)
	player_hp_bar.position = Vector2(76, 158)
	add_child(player_hp_bar)
	
	player_hp_label = Label.new()
	player_hp_label.text = "HP  %d / %d" % [player_hp, player_max_hp]
	player_hp_label.add_theme_font_size_override("font_size", 13)
	player_hp_label.modulate = Color(0.7, 0.9, 0.7)
	player_hp_label.position = Vector2(76, 185)
	add_child(player_hp_label)
	
	var enemy_bg := ColorRect.new()
	enemy_bg.color = Color(0.12, 0.06, 0.06)
	enemy_bg.size = Vector2(300, 160)
	enemy_bg.position = Vector2(820, 80)
	add_child(enemy_bg)
	
	var enemy_name_lbl := Label.new()
	enemy_name_lbl.text = "◆  Lone Wanderer"
	enemy_name_lbl.add_theme_font_size_override("font_size", 22)
	enemy_name_lbl.modulate = Color(0.9, 0.25, 0.25)
	enemy_name_lbl.position = Vector2(836, 96)
	add_child(enemy_name_lbl)
	
	var enemy_type_lbl := Label.new()
	enemy_type_lbl.text = "Unknown affiliation — unknown intent"
	enemy_type_lbl.add_theme_font_size_override("font_size", 11)
	enemy_type_lbl.modulate = Color(0.45, 0.45, 0.45)
	enemy_type_lbl.position = Vector2(836, 128)
	add_child(enemy_type_lbl)
	
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp
	enemy_hp_bar.size = Vector2(268, 20)
	enemy_hp_bar.position = Vector2(836, 158)
	add_child(enemy_hp_bar)
	
	enemy_hp_label = Label.new()
	enemy_hp_label.text = "HP  %d / %d" % [enemy_hp, enemy_max_hp]
	enemy_hp_label.add_theme_font_size_override("font_size", 13)
	enemy_hp_label.modulate = Color(0.9, 0.5, 0.5)
	enemy_hp_label.position = Vector2(836, 185)
	add_child(enemy_hp_label)
	
	var vs := Label.new()
	vs.text = "VS"
	vs.add_theme_font_size_override("font_size", 52)
	vs.modulate = Color(0.35, 0.35, 0.4)
	vs.position = Vector2(544, 130)
	add_child(vs)
	
	initiative_label = Label.new()
	initiative_label.text = "Both sides roll. Highest number moves first.\nTies go to you."
	initiative_label.add_theme_font_size_override("font_size", 16)
	initiative_label.modulate = Color(0.75, 0.72, 0.65)
	initiative_label.position = Vector2(300, 300)
	initiative_label.custom_minimum_size = Vector2(580, 0)
	initiative_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(initiative_label)
	
	roll_btn = Button.new()
	roll_btn.text = "Roll Initiative"
	roll_btn.custom_minimum_size = Vector2(240, 52)
	roll_btn.add_theme_font_size_override("font_size", 18)
	roll_btn.position = Vector2(456, 368)
	roll_btn.pressed.connect(_roll_initiative)
	add_child(roll_btn)
	
	log_label = Label.new()
	log_label.text = " "
	log_label.add_theme_font_size_override("font_size", 16)
	log_label.modulate = Color(0.78, 0.78, 0.78)
	log_label.position = Vector2(160, 450)
	log_label.custom_minimum_size = Vector2(860, 80)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(log_label)
	
	action_container = HBoxContainer.new()
	action_container.position = Vector2(256, 558)
	action_container.add_theme_constant_override("separation", 16)
	action_container.visible = false
	add_child(action_container)
	
	_make_action("Attack", Color(0.9, 0.3, 0.3), _on_attack)
	_make_action("Defend", Color(0.3, 0.6, 0.9), _on_defend)
	_make_action("Flee", Color(0.6, 0.6, 0.3), _on_flee)

func _make_action(label: String, col: Color, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(200, 52)
	btn.add_theme_font_size_override("font_size", 18)
	btn.modulate = col
	btn.pressed.connect(callback)
	action_container.add_child(btn)

func _roll_initiative() -> void:
	roll_btn.visible = false
	var player_roll := randi_range(1, 10)
	var enemy_roll := randi_range(1, 10)
	if player_roll >= enemy_roll:
		player_turn = true
		initiative_label.text = "%s rolls %d. Enemy rolls %d. YOU move first." % [GameData.player_name, player_roll, enemy_roll]
		await get_tree().create_timer(1.0).timeout
		_log("Your move. Choose an action.")
		action_container.visible = true
	else:
		player_turn = false
		initiative_label.text = "%s rolls %d. Enemy rolls %d. ENEMY moves first." % [GameData.player_name, player_roll, enemy_roll]
		await get_tree().create_timer(1.2).timeout
		_enemy_action()

func _on_attack() -> void:
	if not player_turn or combat_over:
		return
	defending = false
	action_container.visible = false
	var dmg := randi_range(9, 20)
	enemy_hp -= dmg
	enemy_hp = max(enemy_hp, 0)
	_update_bars()
	_log("%s strikes for %d damage." % [GameData.player_name, dmg])
	if enemy_hp <= 0:
		_end_combat(true)
		return
	player_turn = false
	await get_tree().create_timer(1.0).timeout
	_enemy_action()

func _on_defend() -> void:
	if not player_turn or combat_over:
		return
	defending = true
	action_container.visible = false
	_log("%s braces. Incoming damage reduced this turn." % GameData.player_name)
	player_turn = false
	await get_tree().create_timer(1.0).timeout
	_enemy_action()

func _on_flee() -> void:
	if combat_over:
		return
	action_container.visible = false
	var roll := randf()
	if roll > 0.42:
		_log("You slip into the dark. The encounter ends.")
		await get_tree().create_timer(1.6).timeout
		get_tree().change_scene_to_file("res://world.tscn")
	else:
		_log("No opening. The enemy cuts off the path.")
		player_turn = false
		await get_tree().create_timer(1.0).timeout
		_enemy_action()

func _enemy_action() -> void:
	if combat_over:
		return
	var dmg := randi_range(6, 15)
	if defending:
		dmg = int(dmg * 0.5)
	defending = false
	player_hp -= dmg
	player_hp = max(player_hp, 0)
	_update_bars()
	_log("Enemy strikes for %d damage." % dmg)
	if player_hp <= 0:
		_end_combat(false)
		return
	player_turn = true
	await get_tree().create_timer(0.6).timeout
	_log("Your move.")
	action_container.visible = true

func _update_bars() -> void:
	player_hp_bar.value = player_hp
	enemy_hp_bar.value = enemy_hp
	player_hp_label.text = "HP  %d / %d" % [player_hp, player_max_hp]
	enemy_hp_label.text = "HP  %d / %d" % [enemy_hp, enemy_max_hp]

func _end_combat(player_won: bool) -> void:
	combat_over = true
	action_container.visible = false
	if player_won:
		_log("The wanderer falls. You move on.")
	else:
		_log("You fall. The Ashveld Flats take one more.")
	await get_tree().create_timer(2.8).timeout
	get_tree().change_scene_to_file("res://world.tscn")

func _log(text: String) -> void:
	log_label.text = text
