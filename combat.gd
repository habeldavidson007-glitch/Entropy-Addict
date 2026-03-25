extends Control

# ─────────────────────────────────────────
# COMBAT SYSTEM — With Call + Subdue + Name Reveal
# ─────────────────────────────────────────

var player_hp: int = 100
var enemy_hp: int = 80
var player_max_hp: int = 100
var enemy_max_hp: int = 80
var player_turn: bool = true
var combat_over: bool = false
var defending: bool = false
var enemy_call: String = ""
var enemy_name: String = "Lone Wanderer"
var enemy_real_name: String = ""
var enemy_type: String = "Unknown"

# UI References
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var player_hp_label: Label
var enemy_hp_label: Label
var enemy_call_label: Label
var log_label: Label
var action_container: HBoxContainer
var initiative_label: Label
var roll_btn: Button
var player_bg: ColorRect
var enemy_bg: ColorRect
var xp_bar: ColorRect
var xp_label: Label
var level_label: Label
var subdue_btn: Button

# Combat values
var xp_reward: int = 50
var enemy_damage_min: int = 6
var enemy_damage_max: int = 15

func _ready() -> void:
	player_max_hp = GameData.get_max_hp()
	player_hp = player_max_hp
	
	# Generate enemy Call via Groq
	enemy_call = await GameData.generate_call(enemy_type, float(enemy_hp) / enemy_max_hp)
	
	_build_ui()
	_update_xp_display()

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
	
	# ─── PLAYER SECTION ───
	player_bg = ColorRect.new()
	player_bg.color = Color(0.08, 0.08, 0.12)
	player_bg.size = Vector2(300, 220)
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
	
	level_label = Label.new()
	level_label.text = "Level %d" % GameData.player_level
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.modulate = Color(0.9, 0.7, 0.3)
	level_label.position = Vector2(76, 148)
	add_child(level_label)
	
	player_hp_bar = ProgressBar.new()
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp
	player_hp_bar.size = Vector2(268, 20)
	player_hp_bar.position = Vector2(76, 172)
	add_child(player_hp_bar)
	
	player_hp_label = Label.new()
	player_hp_label.text = "HP  %d / %d" % [player_hp, player_max_hp]
	player_hp_label.add_theme_font_size_override("font_size", 13)
	player_hp_label.modulate = Color(0.7, 0.9, 0.7)
	player_hp_label.position = Vector2(76, 199)
	add_child(player_hp_label)
	
	var xp_bar_bg := ColorRect.new()
	xp_bar_bg.color = Color(0.15, 0.15, 0.2)
	xp_bar_bg.size = Vector2(268, 8)
	xp_bar_bg.position = Vector2(76, 222)
	add_child(xp_bar_bg)
	
	xp_bar = ColorRect.new()
	xp_bar.color = Color(0.3, 0.6, 0.9)
	xp_bar.size = Vector2(268, 8)
	xp_bar.position = Vector2(76, 222)
	add_child(xp_bar)
	
	xp_label = Label.new()
	xp_label.text = "%d / %d XP" % [GameData.player_xp, GameData.xp_to_next_level]
	xp_label.add_theme_font_size_override("font_size", 10)
	xp_label.modulate = Color(0.5, 0.6, 0.7)
	xp_label.position = Vector2(76, 235)
	add_child(xp_label)
	
	# ─── ENEMY SECTION ───
	enemy_bg = ColorRect.new()
	enemy_bg.color = Color(0.12, 0.06, 0.06)
	enemy_bg.size = Vector2(300, 180)
	enemy_bg.position = Vector2(820, 80)
	add_child(enemy_bg)
	
	var enemy_name_lbl := Label.new()
	enemy_name_lbl.text = "◆  " + enemy_name
	enemy_name_lbl.add_theme_font_size_override("font_size", 22)
	enemy_name_lbl.modulate = Color(0.9, 0.25, 0.25)
	enemy_name_lbl.position = Vector2(836, 96)
	add_child(enemy_name_lbl)
	
	enemy_call_label = Label.new()
	enemy_call_label.text = "'%s'" % enemy_call
	enemy_call_label.add_theme_font_size_override("font_size", 14)
	enemy_call_label.modulate = Color(0.7, 0.7, 0.9)
	enemy_call_label.position = Vector2(836, 122)
	add_child(enemy_call_label)
	
	var enemy_type_lbl := Label.new()
	enemy_type_lbl.text = enemy_type
	enemy_type_lbl.add_theme_font_size_override("font_size", 11)
	enemy_type_lbl.modulate = Color(0.45, 0.45, 0.45)
	enemy_type_lbl.position = Vector2(836, 145)
	add_child(enemy_type_lbl)
	
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp
	enemy_hp_bar.size = Vector2(268, 20)
	enemy_hp_bar.position = Vector2(836, 172)
	add_child(enemy_hp_bar)
	
	enemy_hp_label = Label.new()
	enemy_hp_label.text = "HP  %d / %d" % [enemy_hp, enemy_max_hp]
	enemy_hp_label.add_theme_font_size_override("font_size", 13)
	enemy_hp_label.modulate = Color(0.9, 0.5, 0.5)
	enemy_hp_label.position = Vector2(836, 199)
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
	_style_button(roll_btn, Color(0.4, 0.6, 0.9))
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
	
	# ─── SUBDUE BUTTON ───
	subdue_btn = Button.new()
	subdue_btn.text = "🤝 Subdue"
	subdue_btn.custom_minimum_size = Vector2(200, 52)
	subdue_btn.add_theme_font_size_override("font_size", 18)
	subdue_btn.pressed.connect(_on_subdue)
	_style_button(subdue_btn, Color(0.6, 0.4, 0.8))
	subdue_btn.visible = false
	action_container.add_child(subdue_btn)

func _style_button(btn: Button, col: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = col.darkened(0.3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.5)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := style.duplicate()
	hover_style.bg_color = col
	hover_style.shadow_size = 6
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := style.duplicate()
	pressed_style.bg_color = col.darkened(0.5)
	pressed_style.shadow_size = 2
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style := style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3)
	disabled_style.shadow_size = 0
	btn.add_theme_stylebox_override("disabled", disabled_style)

func _make_action(label: String, col: Color, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(200, 52)
	btn.add_theme_font_size_override("font_size", 18)
	_style_button(btn, col)
	btn.pressed.connect(callback)
	action_container.add_child(btn)

func _update_xp_display() -> void:
	if xp_bar and xp_label and level_label:
		var progress = GameData.get_xp_progress()
		xp_bar.size.x = 268 * progress
		xp_label.text = "%d / %d XP" % [GameData.player_xp, GameData.xp_to_next_level]
		level_label.text = "Level %d" % GameData.player_level

func _update_subdue_button() -> void:
	var hp_percent = float(enemy_hp) / enemy_max_hp
	if GameData.can_subdue(hp_percent):
		subdue_btn.visible = true
		subdue_btn.text = "🤝 Subdue (%.0f%%)" % (GameData.get_subdue_chance() * 100)
	else:
		subdue_btn.visible = false

func _roll_initiative() -> void:
	roll_btn.visible = false
	
	var tween = create_tween()
	tween.tween_property(roll_btn, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(roll_btn, "scale", Vector2(1, 1), 0.1)
	
	var player_roll := randi_range(1, 10)
	var enemy_roll := randi_range(1, 10)
	
	var dex_bonus = GameData.get_initiative_bonus() * 10
	player_roll += int(dex_bonus)
	
	initiative_label.text = "Rolling..."
	await get_tree().create_timer(0.5).timeout
	
	if player_roll >= enemy_roll:
		player_turn = true
		initiative_label.text = "%s rolls %d. Enemy rolls %d. YOU move first." % [GameData.player_name, player_roll, enemy_roll]
		initiative_label.modulate = Color(0.4, 0.9, 0.4)
		await get_tree().create_timer(1.0).timeout
		_log("Your move. Choose an action.")
		action_container.visible = true
	else:
		player_turn = false
		initiative_label.text = "%s rolls %d. Enemy rolls %d. ENEMY moves first." % [GameData.player_name, player_roll, enemy_roll]
		initiative_label.modulate = Color(0.9, 0.4, 0.4)
		await get_tree().create_timer(1.2).timeout
		_enemy_action()

func _on_attack() -> void:
	if not player_turn or combat_over:
		return
	defending = false
	action_container.visible = false
	
	var tween = create_tween()
	tween.tween_property(player_bg, "position:x", player_bg.position.x + 50, 0.15)
	tween.tween_property(player_bg, "position:x", player_bg.position.x, 0.15)
	
	await get_tree().create_timer(0.2).timeout
	
	var base_dmg = GameData.get_base_damage()
	var dmg = randi_range(base_dmg - 2, base_dmg + 8)
	
	var crit_roll = randf()
	var is_crit = crit_roll < GameData.get_crit_chance()
	
	if is_crit:
		dmg *= 2
		_log("CRITICAL HIT! ", Color(1, 0.3, 0.3))
		await get_tree().create_timer(0.3).timeout
	
	enemy_hp -= dmg
	enemy_hp = max(enemy_hp, 0)
	
	_flash_damage(false)
	_screen_shake(5.0)
	_show_damage_number(dmg, false, is_crit)
	
	_update_bars()
	_update_subdue_button()
	_log("%s strikes for %d damage." % [GameData.player_name, dmg])
	
	if enemy_hp <= 0:
		_end_combat(true)
		return
	
	player_turn = false
	await get_tree().create_timer(1.0).timeout
	_enemy_action()

func _on_subdue() -> void:
	if not player_turn or combat_over:
		return
	
	action_container.visible = false
	_log("Attempting to subdue...", Color(0.9, 0.9, 0.3))
	
	var hp_percent = float(enemy_hp) / enemy_max_hp
	var success = GameData.attempt_subdue(enemy_name, enemy_call, enemy_type)
	
	if success:
		# Show name reveal if available
		if enemy_real_name and enemy_real_name != enemy_name:
			_log("✅ Subdued %s!" % enemy_name, Color(0.6, 0.9, 0.6))
			await get_tree().create_timer(1.0).timeout
			_log("📜 Real name uncovered: %s" % enemy_real_name, Color(1, 0.9, 0.3))
			await _show_name_reveal_animation(enemy_name, enemy_real_name)
		else:
			_log("✅ %s subdued! They may join your cause later." % enemy_name, Color(0.6, 0.9, 0.6))
		
		await get_tree().create_timer(1.5).timeout
		_end_combat(true, true)
	else:
		_log("❌ Subdue failed — enemy breaks free!", Color(0.9, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		player_turn = false
		_enemy_action()

func _show_name_reveal_animation(generic_name: String, real_name: String) -> void:
	"""Animated name reveal"""
	var reveal_label := Label.new()
	reveal_label.text = "Subdued: %s" % generic_name
	reveal_label.add_theme_font_size_override("font_size", 24)
	reveal_label.modulate = Color(0.6, 0.8, 0.6)
	reveal_label.position = Vector2(400, 300)
	reveal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(reveal_label)
	
	# Fade out generic name
	var tween = create_tween()
	tween.tween_property(reveal_label, "modulate:a", 0, 0.5)
	await tween.finished
	
	# Show real name
	reveal_label.text = "Real Name: %s" % real_name
	reveal_label.modulate = Color(1, 0.9, 0.3)
	reveal_label.position.y = 320
	
	tween = create_tween()
	tween.tween_property(reveal_label, "modulate:a", 1, 0.3)
	await get_tree().create_timer(1.5).timeout
	tween.tween_property(reveal_label, "modulate:a", 0, 0.5)
	await tween.finished
	
	reveal_label.queue_free()

func _on_defend() -> void:
	if not player_turn or combat_over:
		return
	defending = true
	action_container.visible = false
	
	var tween = create_tween()
	tween.tween_property(player_bg, "modulate", Color(0.5, 0.7, 1, 1), 0.2)
	tween.tween_property(player_bg, "modulate", Color(1, 1, 1, 1), 0.2)
	
	_log("%s braces. Incoming damage reduced this turn." % GameData.player_name)
	player_turn = false
	await get_tree().create_timer(1.0).timeout
	_enemy_action()

func _on_flee() -> void:
	if combat_over:
		return
	action_container.visible = false
	
	var base_flee = 0.42
	var flee_bonus = GameData.get_flee_bonus()
	var flee_chance = base_flee + flee_bonus
	
	var roll := randf()
	if roll < flee_chance:
		_log("You slip into the dark. The encounter ends.")
		await get_tree().create_timer(1.6).timeout
		_return_to_world(true)
	else:
		_log("No opening. The enemy cuts off the path.")
		player_turn = false
		await get_tree().create_timer(1.0).timeout
		_enemy_action()

func _enemy_action() -> void:
	if combat_over:
		return
	
	var tween = create_tween()
	tween.tween_property(enemy_bg, "position:x", enemy_bg.position.x - 50, 0.15)
	tween.tween_property(enemy_bg, "position:x", enemy_bg.position.x, 0.15)
	
	await get_tree().create_timer(0.2).timeout
	
	var base_evasion = GameData.get_evasion_chance()
	var familiar_bonus = GameData.familiar_environment_bonus / 200.0
	var total_evasion = base_evasion + familiar_bonus
	
	var evasion_roll = randf()
	if evasion_roll < total_evasion:
		_log("You evade the attack! (Familiar terrain helps)", Color(0.3, 1, 0.3))
		player_turn = true
		initiative_label.text = "★ YOUR TURN ★"
		initiative_label.modulate = Color(0.4, 0.9, 0.4)
		await get_tree().create_timer(0.6).timeout
		_log("Your move.")
		action_container.visible = true
		return
	
	var dmg := randi_range(enemy_damage_min, enemy_damage_max)
	var defense = GameData.get_base_defense()
	dmg = max(1, dmg - defense)
	
	if defending:
		dmg = int(dmg * 0.5)
		_log("Your defense reduces damage to %d!" % dmg)
	
	defending = false
	player_hp -= dmg
	player_hp = max(player_hp, 0)
	
	_flash_damage(true)
	_screen_shake(8.0)
	_show_damage_number(dmg, true, false)
	
	_update_bars()
	_log("Enemy strikes for %d damage." % dmg)
	
	if player_hp <= 0:
		_end_combat(false)
		return
	
	player_turn = true
	initiative_label.text = "★ YOUR TURN ★"
	initiative_label.modulate = Color(0.4, 0.9, 0.4)
	await get_tree().create_timer(0.6).timeout
	_log("Your move.")
	action_container.visible = true

func _update_bars() -> void:
	_animate_hp_bar(player_hp_bar, player_hp)
	_animate_hp_bar(enemy_hp_bar, enemy_hp)
	
	# Change HP bar color based on health %
	player_hp_bar.modulate = _get_hp_color(player_hp, player_max_hp)
	enemy_hp_bar.modulate = _get_hp_color(enemy_hp, enemy_max_hp)
	
	player_hp_label.text = "HP  %d / %d" % [player_hp, player_max_hp]
	enemy_hp_label.text = "HP  %d / %d" % [enemy_hp, enemy_max_hp]

func _get_hp_color(current: int, max_hp: int) -> Color:
	var percent = float(current) / max_hp
	if percent > 0.6:
		return Color(0.7, 0.9, 0.7)  # Green
	elif percent > 0.3:
		return Color(0.9, 0.9, 0.3)  # Yellow
	else:
		return Color(0.9, 0.3, 0.3)  # Red

func _animate_hp_bar(bar: ProgressBar, target_value: float) -> void:
	var tween = create_tween()
	tween.tween_property(bar, "value", target_value, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _show_damage_number(amount: int, is_player: bool, is_crit: bool = false) -> void:
	var dmg_lbl := Label.new()
	dmg_lbl.text = "-%d" % amount
	dmg_lbl.add_theme_font_size_override("font_size", 28 if not is_crit else 36)
	dmg_lbl.modulate = Color(1, 0.3, 0.3) if not is_player else Color(0.3, 0.8, 1)
	
	if is_crit:
		dmg_lbl.text = "CRIT! -%d" % amount
		dmg_lbl.modulate = Color(1, 0.1, 0.1) if not is_player else Color(1, 0.8, 0.1)
	
	var pos = Vector2(200, 150) if is_player else Vector2(950, 150)
	dmg_lbl.position = pos
	
	var shadow := Label.new()
	shadow.text = dmg_lbl.text
	shadow.add_theme_font_size_override("font_size", 28 if not is_crit else 36)
	shadow.modulate = Color(0, 0, 0, 0.5)
	shadow.position = Vector2(2, 2)
	dmg_lbl.add_child(shadow)
	
	add_child(dmg_lbl)
	
	var tween = create_tween()
	tween.tween_property(dmg_lbl, "position:y", pos.y - 60, 0.6).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(dmg_lbl, "modulate:a", 0, 0.6)
	tween.tween_callback(dmg_lbl.queue_free)

func _flash_damage(is_player: bool) -> void:
	var flash_color := Color(1, 0, 0, 0.5)
	var target_bg = player_bg if is_player else enemy_bg
	
	var flash_rect := ColorRect.new()
	flash_rect.color = flash_color
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target_bg.add_child(flash_rect)
	
	var tween = create_tween()
	tween.tween_property(flash_rect, "modulate:a", 0, 0.15)
	tween.tween_callback(flash_rect.queue_free)

func _screen_shake(intensity: float = 10.0) -> void:
	var original_pos = position
	var tween = create_tween()
	for i in range(5):
		tween.tween_property(self, "position", 
			original_pos + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), 0.05)
	tween.tween_property(self, "position", original_pos, 0.1)

func _show_xp_gain(amount: int) -> void:
	var xp_lbl := Label.new()
	xp_lbl.text = "+%d XP" % amount
	xp_lbl.add_theme_font_size_override("font_size", 24)
	xp_lbl.modulate = Color(1, 0.9, 0.3)
	xp_lbl.position = Vector2(500, 400)
	add_child(xp_lbl)
	
	var tween = create_tween()
	tween.tween_property(xp_lbl, "position:y", 350, 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(xp_lbl, "modulate:a", 0, 0.5)
	tween.tween_callback(xp_lbl.queue_free)

func _show_level_up_effect() -> void:
	var level_up_notification := Label.new()
	level_up_notification.text = "★ LEVEL UP! ★"
	level_up_notification.add_theme_font_size_override("font_size", 48)
	level_up_notification.modulate = Color(1, 0.9, 0.3)
	level_up_notification.position = Vector2(350, 250)
	add_child(level_up_notification)
	
	var tween = create_tween()
	tween.tween_property(level_up_notification, "scale", Vector2(1.3, 1.3), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(level_up_notification, "scale", Vector2(1, 1), 0.3)
	tween.parallel().tween_property(level_up_notification, "position:y", 200, 0.6)
	tween.tween_property(level_up_notification, "modulate:a", 0, 0.5)
	tween.tween_callback(level_up_notification.queue_free)

func _end_combat(player_won: bool, subdued: bool = false) -> void:
	combat_over = true
	action_container.visible = false
	
	if player_won:
		if subdued:
			_log("Encounter ends — subdued enemy may join later.", Color(0.6, 0.9, 0.6))
		else:
			_log("The wanderer falls. You move on.")
		
		if not subdued:
			_show_xp_gain(xp_reward)
			var leveled_up = GameData.add_xp(xp_reward)
			await get_tree().create_timer(0.8).timeout
			_update_xp_display()
			
			if leveled_up and GameData.stat_points > 0:
				_show_level_up_effect()
				await get_tree().create_timer(0.5).timeout
				_log("LEVEL UP! Allocating stat points...", Color(1, 0.9, 0.3))
				await get_tree().create_timer(1.0).timeout
				
				var level_up_scene = load("res://level_up_ui.tscn")
				if level_up_scene:
					var level_up_ui = level_up_scene.instantiate()
					add_child(level_up_ui)
					await level_up_ui.stats_confirmed
					_log("Stats allocated! You are now level %d!" % GameData.player_level, Color(0.6, 0.9, 0.6))
				else:
					_log("ERROR: level_up_ui.tscn not found!")
					_log("You are now level %d!" % GameData.player_level)
			elif leveled_up:
				_log("You are now level %d!" % GameData.player_level)
		
		var tween = create_tween()
		tween.tween_property(enemy_bg, "modulate:a", 0, 1.0)
	else:
		_log("You fall. The Ashveld Flats take one more.", Color(0.9, 0.3, 0.3))
		var tween = create_tween()
		tween.tween_property(player_bg, "modulate:a", 0, 1.0)
	
	await get_tree().create_timer(2.8).timeout
	_return_to_world(player_won)

func _return_to_world(_player_won: bool) -> void:
	GameData.save_game()
	get_tree().change_scene_to_file("res://world.tscn")

func _log(text: String, color: Color = Color(0.78, 0.78, 0.78)) -> void:
	log_label.text = text
	log_label.modulate = color
