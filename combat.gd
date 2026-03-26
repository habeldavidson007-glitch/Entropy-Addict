extends Control

# ─────────────────────────────────────────
# COMBAT SYSTEM — Party + Subdue + Calls
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
var enemy_type: String = "Unknown affiliation — unknown intent"
var enemy_id: String = ""

var active_party_members: Array = []
var party_member_hp: Dictionary = {}

# UI Elements
var player_panel: ColorRect
var enemy_panel: ColorRect
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var player_hp_label: Label
var enemy_hp_label: Label
var log_label: Label
var action_container: HBoxContainer
var roll_btn: Button
var subdue_btn: Button
var party_hp_labels: Array = []
var party_hp_bars: Array = []

var xp_reward: int = 50
var enemy_damage_min: int = 6
var enemy_damage_max: int = 15

func _ready() -> void:
	player_max_hp = GameData.get_max_hp()
	player_hp = player_max_hp

	enemy_call = await GameData.generate_call(enemy_type, float(enemy_hp) / enemy_max_hp)

	# Generate a real name with 50% chance
	var possible_real_names = ["Maret", "Ossel", "Kaelen", "Vera", "Lyra", "Dain", "Ghiar", "Ryn", "Varek", "Senne"]
	enemy_real_name = possible_real_names[randi_range(0, possible_real_names.size() - 1)] if randf() < 0.5 else ""

	enemy_id = "enemy_%d_%d" % [Time.get_unix_time_from_system(), randi_range(0, 999)]
	active_party_members = GameData.get_party_members()

	for member in active_party_members:
		var member_name = member.get("name", "Unknown")
		party_member_hp[member_name] = member.get("hp", member.get("max_hp", 80))

	_build_clean_ui()
	_update_subdue_button()

func _build_clean_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "— ENCOUNTER —"
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(0.6, 0.5, 0.6)
	title.position = Vector2(500, 20)
	add_child(title)

	var left_x = 30
	var left_y = 70

	# Party Panel
	if active_party_members.size() > 0:
		var party_panel := ColorRect.new()
		party_panel.color = Color(0.1, 0.08, 0.12)
		party_panel.size = Vector2(300, 50 + (active_party_members.size() * 40))
		party_panel.position = Vector2(left_x, left_y)
		add_child(party_panel)

		var party_title := Label.new()
		party_title.text = "★ PARTY (%d)" % active_party_members.size()
		party_title.add_theme_font_size_override("font_size", 13)
		party_title.modulate = Color(0.9, 0.7, 0.3)
		party_title.position = Vector2(10, 10)
		party_panel.add_child(party_title)

		var offset_y = 35
		for member in active_party_members:
			var member_name = member.get("name", "Unknown")
			var member_max = member.get("max_hp", 80)
			var current = party_member_hp.get(member_name, member_max)

			var name_lbl := Label.new()
			name_lbl.text = "• " + member_name
			name_lbl.add_theme_font_size_override("font_size", 11)
			name_lbl.modulate = Color(0.9, 0.7, 0.5)
			name_lbl.position = Vector2(10, offset_y)
			party_panel.add_child(name_lbl)

			var hp_lbl := Label.new()
			hp_lbl.text = "HP: %d/%d" % [current, member_max]
			hp_lbl.add_theme_font_size_override("font_size", 10)
			hp_lbl.modulate = Color(0.7, 0.9, 0.7)
			hp_lbl.position = Vector2(10, offset_y + 18)
			party_panel.add_child(hp_lbl)
			party_hp_labels.append(hp_lbl)

			var hp_bar := ProgressBar.new()
			hp_bar.max_value = member_max
			hp_bar.value = current
			hp_bar.size = Vector2(150, 12)
			hp_bar.position = Vector2(140, offset_y + 20)
			party_panel.add_child(hp_bar)
			party_hp_bars.append(hp_bar)

			offset_y += 40

	# Player Panel
	var party_offset_y = (60 + (active_party_members.size() * 40)) if active_party_members.size() > 0 else 0
	player_panel = ColorRect.new()
	player_panel.color = Color(0.12, 0.1, 0.15)
	player_panel.size = Vector2(300, 180)
	player_panel.position = Vector2(left_x, left_y + party_offset_y)
	add_child(player_panel)

	var player_name_lbl := Label.new()
	player_name_lbl.text = GameData.player_emoticon + " " + GameData.player_name
	player_name_lbl.add_theme_font_size_override("font_size", 20)
	player_name_lbl.modulate = GameData.player_color
	player_name_lbl.position = Vector2(15, 15)
	player_panel.add_child(player_name_lbl)

	var level_lbl := Label.new()
	level_lbl.text = "Level %d" % GameData.player_level
	level_lbl.add_theme_font_size_override("font_size", 14)
	level_lbl.modulate = Color(0.9, 0.7, 0.3)
	level_lbl.position = Vector2(15, 42)
	player_panel.add_child(level_lbl)

	player_hp_bar = ProgressBar.new()
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp
	player_hp_bar.size = Vector2(270, 22)
	player_hp_bar.position = Vector2(15, 65)
	player_panel.add_child(player_hp_bar)

	player_hp_label = Label.new()
	player_hp_label.text = "HP: %d / %d" % [player_hp, player_max_hp]
	player_hp_label.add_theme_font_size_override("font_size", 12)
	player_hp_label.modulate = Color(0.7, 0.9, 0.7)
	player_hp_label.position = Vector2(15, 92)
	player_panel.add_child(player_hp_label)

	var xp_bar_bg := ColorRect.new()
	xp_bar_bg.color = Color(0.2, 0.2, 0.25)
	xp_bar_bg.size = Vector2(270, 8)
	xp_bar_bg.position = Vector2(15, 115)
	player_panel.add_child(xp_bar_bg)

	var xp_bar := ColorRect.new()
	xp_bar.color = Color(0.3, 0.6, 0.9)
	xp_bar.size = Vector2(270 * GameData.get_xp_progress(), 8)
	xp_bar.position = Vector2(15, 115)
	player_panel.add_child(xp_bar)

	var xp_lbl := Label.new()
	xp_lbl.text = "%d / %d XP" % [GameData.player_xp, GameData.xp_to_next_level]
	xp_lbl.add_theme_font_size_override("font_size", 10)
	xp_lbl.modulate = Color(0.6, 0.7, 0.8)
	xp_lbl.position = Vector2(15, 130)
	player_panel.add_child(xp_lbl)

	# Enemy Panel
	enemy_panel = ColorRect.new()
	enemy_panel.color = Color(0.15, 0.08, 0.08)
	enemy_panel.size = Vector2(320, 200)
	enemy_panel.position = Vector2(800, 70)
	add_child(enemy_panel)

	var enemy_name_lbl := Label.new()
	enemy_name_lbl.text = "◆ " + enemy_name
	enemy_name_lbl.add_theme_font_size_override("font_size", 20)
	enemy_name_lbl.modulate = Color(0.9, 0.4, 0.4)
	enemy_name_lbl.position = Vector2(15, 15)
	enemy_panel.add_child(enemy_name_lbl)

	var call_lbl := Label.new()
	call_lbl.text = "'%s'" % enemy_call
	call_lbl.add_theme_font_size_override("font_size", 12)
	call_lbl.modulate = Color(0.7, 0.7, 0.9)
	call_lbl.position = Vector2(15, 42)
	enemy_panel.add_child(call_lbl)

	var type_lbl := Label.new()
	type_lbl.text = enemy_type
	type_lbl.add_theme_font_size_override("font_size", 10)
	type_lbl.modulate = Color(0.5, 0.5, 0.5)
	type_lbl.position = Vector2(15, 62)
	enemy_panel.add_child(type_lbl)

	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp
	enemy_hp_bar.size = Vector2(290, 22)
	enemy_hp_bar.position = Vector2(15, 90)
	enemy_panel.add_child(enemy_hp_bar)

	enemy_hp_label = Label.new()
	enemy_hp_label.text = "HP: %d / %d" % [enemy_hp, enemy_max_hp]
	enemy_hp_label.add_theme_font_size_override("font_size", 12)
	enemy_hp_label.modulate = Color(0.9, 0.6, 0.6)
	enemy_hp_label.position = Vector2(15, 118)
	enemy_panel.add_child(enemy_hp_label)

	# VS
	var vs := Label.new()
	vs.text = "VS"
	vs.add_theme_font_size_override("font_size", 48)
	vs.modulate = Color(0.5, 0.5, 0.6)
	vs.position = Vector2(540, 180)
	add_child(vs)

	# Status label
	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.text = "Both sides roll. Highest moves first."
	status_lbl.add_theme_font_size_override("font_size", 14)
	status_lbl.modulate = Color(0.7, 0.7, 0.7)
	status_lbl.position = Vector2(350, 300)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_lbl)

	# Roll button
	roll_btn = Button.new()
	roll_btn.text = "Roll Initiative"
	roll_btn.custom_minimum_size = Vector2(220, 50)
	roll_btn.add_theme_font_size_override("font_size", 16)
	roll_btn.position = Vector2(465, 340)
	roll_btn.pressed.connect(_roll_initiative)
	_style_btn(roll_btn, Color(0.4, 0.6, 0.9))
	add_child(roll_btn)

	# Combat log
	log_label = Label.new()
	log_label.text = " "
	log_label.add_theme_font_size_override("font_size", 14)
	log_label.modulate = Color(0.8, 0.8, 0.8)
	log_label.position = Vector2(100, 420)
	log_label.custom_minimum_size = Vector2(950, 60)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(log_label)

	# Action buttons
	action_container = HBoxContainer.new()
	action_container.position = Vector2(150, 520)
	action_container.add_theme_constant_override("separation", 15)
	action_container.visible = false
	add_child(action_container)

	_make_btn("Attack", Color(0.9, 0.3, 0.3), _on_attack)
	_make_btn("Defend", Color(0.3, 0.6, 0.9), _on_defend)
	_make_btn("Flee",   Color(0.7, 0.7, 0.3), _on_flee)

	subdue_btn = Button.new()
	subdue_btn.text = "Subdue"
	subdue_btn.custom_minimum_size = Vector2(160, 50)
	subdue_btn.add_theme_font_size_override("font_size", 16)
	subdue_btn.pressed.connect(_on_subdue)
	_style_btn(subdue_btn, Color(0.7, 0.4, 0.9))
	subdue_btn.visible = false
	action_container.add_child(subdue_btn)

func _style_btn(btn: Button, col: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = col.darkened(0.3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = col
	btn.add_theme_stylebox_override("hover", hover)

func _make_btn(text: String, col: Color, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 50)
	btn.add_theme_font_size_override("font_size", 16)
	_style_btn(btn, col)
	btn.pressed.connect(callback)
	action_container.add_child(btn)

func _update_subdue_button() -> void:
	var hp_pct = float(enemy_hp) / enemy_max_hp
	if hp_pct <= 0.35 and hp_pct > 0.0:
		subdue_btn.visible = true
		var chance = min(0.85, 0.25 + float(GameData.player_level) * 0.03)
		subdue_btn.text = "Subdue (%.0f%%)" % (chance * 100)
	else:
		subdue_btn.visible = false

func _roll_initiative() -> void:
	roll_btn.visible = false

	var p_roll = randi_range(1, 10) + int(GameData.get_initiative_bonus() * 10)
	var e_roll = randi_range(1, 10)
	p_roll += active_party_members.size()

	var status = get_node_or_null("StatusLabel")
	if status:
		status.text = "Rolling..."

	await get_tree().create_timer(0.5).timeout

	if p_roll >= e_roll:
		player_turn = true
		if status:
			status.text = "You roll %d. Enemy rolls %d. YOU go first!" % [p_roll, e_roll]
			status.modulate = Color(0.4, 0.9, 0.4)
		await get_tree().create_timer(1.0).timeout
		_log("Your turn!")
		action_container.visible = true
	else:
		player_turn = false
		if status:
			status.text = "You roll %d. Enemy rolls %d. ENEMY goes first!" % [p_roll, e_roll]
			status.modulate = Color(0.9, 0.4, 0.4)
		await get_tree().create_timer(1.0).timeout
		_enemy_action()

func _on_attack() -> void:
	if not player_turn or combat_over:
		return
	action_container.visible = false

	# FIX: Use actual damage calculation instead of hardcoded 10
	var base_dmg = GameData.get_base_damage()
	var dmg = randi_range(base_dmg - 2, base_dmg + 8)
	var is_crit = randf() < GameData.get_crit_chance()
	if is_crit:
		dmg *= 2

	enemy_hp -= dmg
	enemy_hp = max(enemy_hp, 0)
	_update_all_bars()

	if is_crit:
		_log("CRITICAL HIT! %s attacks for %d damage!" % [GameData.player_name, dmg])
	else:
		_log("%s attacks for %d damage!" % [GameData.player_name, dmg])

	if active_party_members.size() > 0:
		await get_tree().create_timer(0.4).timeout
		await _party_attack()

	if enemy_hp <= 0:
		_end_combat(true)
		return

	player_turn = false
	await get_tree().create_timer(0.8).timeout
	_enemy_action()

func _party_attack() -> void:
	for member in active_party_members:
		# FIX: renamed from 'name' to 'member_name' to avoid shadowing built-in
		var member_name = member.get("name", "Unknown")
		var max_hp = member.get("max_hp", 80)
		if party_member_hp.get(member_name, max_hp) <= 0:
			continue

		var dmg = randi_range(4, 8) + GameData.player_level
		enemy_hp -= dmg
		enemy_hp = max(enemy_hp, 0)
		_update_all_bars()
		_log("%s attacks for %d damage!" % [member_name, dmg])

		if enemy_hp <= 0:
			break
		await get_tree().create_timer(0.3).timeout

func _on_subdue() -> void:
	if not player_turn or combat_over:
		return
	action_container.visible = false
	_log("Attempting to subdue...")

	var chance = min(0.85, 0.25 + float(GameData.player_level) * 0.03)
	if randf() < chance:
		_log("Subdued %s!" % enemy_name)

		if enemy_real_name != "" and enemy_real_name != enemy_name:
			await get_tree().create_timer(0.8).timeout
			_log("Real name: %s" % enemy_real_name)
			# Update enemy name label in panel
			var name_lbl = _find_enemy_name_label()
			if name_lbl:
				name_lbl.text = "◆ " + enemy_real_name

		var recruit_name = enemy_real_name if enemy_real_name != "" else enemy_name
		GameData.add_party_member(recruit_name, enemy_call, enemy_type, 80)
		_log("%s joins your party!" % recruit_name)

		await get_tree().create_timer(1.2).timeout
		_end_combat(true, true)
	else:
		_log("Subdue failed!")
		await get_tree().create_timer(0.8).timeout
		player_turn = false
		_enemy_action()

func _find_enemy_name_label() -> Label:
	for child in enemy_panel.get_children():
		if child is Label and child.text.begins_with("◆"):
			return child
	return null

func _on_defend() -> void:
	if not player_turn or combat_over:
		return
	defending = true
	action_container.visible = false
	_log("%s defends. Damage reduced!" % GameData.player_name)
	player_turn = false
	await get_tree().create_timer(0.8).timeout
	_enemy_action()

func _on_flee() -> void:
	if combat_over:
		return
	action_container.visible = false
	var flee_chance = 0.42 + GameData.get_flee_bonus()
	if randf() < flee_chance:
		_log("You escaped!")
		await get_tree().create_timer(1.0).timeout
		_return_to_world(true)
	else:
		_log("Can't escape!")
		player_turn = false
		await get_tree().create_timer(0.8).timeout
		_enemy_action()

func _enemy_action() -> void:
	if combat_over:
		return

	var dmg = randi_range(enemy_damage_min, enemy_damage_max)
	var defense = GameData.get_base_defense()
	dmg = max(1, dmg - defense)

	if defending:
		dmg = int(dmg * 0.5)
		defending = false

	# Enemy targets a random party member 40% of the time
	if active_party_members.size() > 0 and randf() < 0.4:
		var idx = randi_range(0, active_party_members.size() - 1)
		var target = active_party_members[idx]
		# FIX: renamed from 'name' to 'target_name'
		var target_name = target.get("name", "Unknown")
		var t_hp = party_member_hp.get(target_name, 80)
		t_hp -= dmg
		t_hp = max(t_hp, 0)
		party_member_hp[target_name] = t_hp
		_log("Enemy hits %s for %d!" % [target_name, dmg])
		_update_party_ui()
	else:
		player_hp -= dmg
		player_hp = max(player_hp, 0)
		_log("Enemy hits you for %d!" % dmg)
		_update_all_bars()

	if player_hp <= 0:
		# Check if all party also dead
		var all_dead = true
		for m in active_party_members:
			if party_member_hp.get(m.get("name", ""), 0) > 0:
				all_dead = false
				break
		if all_dead:
			_end_combat(false)
			return

	player_turn = true
	var status = get_node_or_null("StatusLabel")
	if status:
		status.text = "★ YOUR TURN ★"
		status.modulate = Color(0.4, 0.9, 0.4)
	await get_tree().create_timer(0.6).timeout
	_log("Your move!")
	action_container.visible = true

func _end_combat(won: bool, subdued: bool = false) -> void:
	combat_over = true
	action_container.visible = false

	if won:
		if subdued:
			_log("Enemy joins your party!")
		else:
			_log("Victory! +%d XP" % xp_reward)
			GameData.add_xp(xp_reward)
	else:
		_log("You were defeated...")

	await get_tree().create_timer(2.0).timeout
	_return_to_world(won)

func _return_to_world(_won: bool) -> void:
	# FIX: Sync party HP back to GameData properly
	for i in range(active_party_members.size()):
		if i < GameData.party_members.size():
			# FIX: renamed from 'name' to 'mem_name'
			var mem_name = active_party_members[i].get("name", "Unknown")
			if party_member_hp.has(mem_name):
				GameData.party_members[i]["hp"] = party_member_hp[mem_name]
	GameData.save_game()
	get_tree().change_scene_to_file("res://world.tscn")

func _update_all_bars() -> void:
	player_hp_bar.value = player_hp
	player_hp_label.text = "HP: %d / %d" % [player_hp, player_max_hp]
	enemy_hp_bar.value = enemy_hp
	enemy_hp_label.text = "HP: %d / %d" % [enemy_hp, enemy_max_hp]
	_update_subdue_button()

func _update_party_ui() -> void:
	for i in range(active_party_members.size()):
		# FIX: renamed from 'name' to 'mem_name'
		var mem_name = active_party_members[i].get("name", "Unknown")
		var max_hp = active_party_members[i].get("max_hp", 80)
		var cur = party_member_hp.get(mem_name, max_hp)

		if i < party_hp_labels.size():
			party_hp_labels[i].text = "HP: %d/%d" % [cur, max_hp]
			party_hp_labels[i].modulate = Color(0.7, 0.9, 0.7) if cur > 0 else Color(0.9, 0.3, 0.3)
		if i < party_hp_bars.size():
			party_hp_bars[i].value = cur

func _log(text: String) -> void:
	log_label.text = text
