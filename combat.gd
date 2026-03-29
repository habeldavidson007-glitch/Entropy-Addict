extends Control
# ═══════════════════════════════════════════════════════════
# COMBAT SCENE — Turn-based SRPG
# ═══════════════════════════════════════════════════════════

# ── Combat state ──
var player_hp: int
var player_max_hp: int
var enemy_hp: int
var enemy_max_hp: int
# FIX: Corrected syntax (removed space in type declaration)
var enemy_data: Dictionary = {}
var player_turn: bool = true
var combat_over: bool = false
var defending: bool   = false
var turn_count: int   = 0
var phase: String     = "initiative"

# ── UI nodes ──
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var player_hp_label: Label
var enemy_hp_label: Label
var initiative_label: Label
var roll_btn: Button
var action_container: HBoxContainer
var log_container: VBoxContainer
var recruit_panel: Control
var codex_panel: Control
var attr_panel: Control
var enemy_name_label: Label
var enemy_desc_label: Label
var party_turn_label: Label

const ENEMY_POOL_NEUTRAL: Array = [
	"Road-Worn Traveler","Former Ironwind Outrider","Salt Marsh Drifter",
	"Sunfall Vagrant","Displaced Farmer","Steppe Exile"
]
const ENEMY_POOL_HOSTILE: Array = [
	"Route Hijacker","Barrens Raider","Flats Scavenger",
	"Succession War Remnant","Iron Pass Fugitive","Ashborn Deserter"
]

func _ready() -> void:
	player_hp     = GameData.player_hp
	player_max_hp = GameData.player_max_hp
	if not GameData.encounter_enemy.is_empty():
		enemy_data = GameData.encounter_enemy
	else:
		_generate_random_enemy()
	enemy_hp     = enemy_data.get("hp", 50)
	enemy_max_hp = enemy_data.get("max_hp", 50)
	_build_ui()
	_load_enemy_desc_groq()

func _generate_random_enemy() -> void:
	var faction := "hostile" if randf() < 0.55 else "neutral"
	var pool: Array = ENEMY_POOL_HOSTILE if faction == "hostile" else ENEMY_POOL_NEUTRAL
	var lv := randi_range(1, GameData.player_level + 1)
	enemy_data = {
		"name": pool[randi() % pool.size()],
		"faction": faction,
		"level": lv,
		"hp": 40 + lv * 8,
		"max_hp": 40 + lv * 8,
		"type": "lone_wanderer",
	}

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	for i in range(0, 1152, 48):
		var l := ColorRect.new()
		l.color = Color(1,1,1,0.01)
		l.size = Vector2(1, 648)
		l.position = Vector2(i, 0)
		add_child(l)

	var hdr := ColorRect.new()
	hdr.color = Color(0.06, 0.04, 0.09)
	hdr.size = Vector2(1152, 46)
	add_child(hdr)
	var faction_col: Color = Color(0.35,0.25,0.42) if enemy_data.get("faction","hostile")=="hostile" else Color(0.20,0.38,0.22)
	var enc_lbl := Label.new()
	enc_lbl.text = "— ENCOUNTER: %s —" % enemy_data.get("faction","hostile").to_upper()
	enc_lbl.add_theme_font_size_override("font_size", 13)
	enc_lbl.modulate = faction_col
	enc_lbl.position = Vector2(440, 15)
	add_child(enc_lbl)

	# Player Panel
	var pp := ColorRect.new()
	pp.color = Color(0.07, 0.08, 0.12)
	pp.size = Vector2(370, 220)
	pp.position = Vector2(28, 54)
	add_child(pp)
	var ps := ColorRect.new()
	ps.color = GameData.player_color
	ps.size = Vector2(3, 220)
	ps.position = Vector2(28, 54)
	add_child(ps)

	var pn := Label.new()
	pn.text = "%s  %s" % [GameData.player_emoticon, GameData.player_name]
	pn.add_theme_font_size_override("font_size", 20)
	pn.modulate = GameData.player_color
	pn.position = Vector2(44, 64)
	add_child(pn)

	var pl := Label.new()
	pl.text = "Lv.%d  ·  STR%d  INT%d  DEX%d  LCK%d" % [
		GameData.player_level, GameData.attr_str, GameData.attr_int, GameData.attr_dex, GameData.attr_luck]
	pl.add_theme_font_size_override("font_size", 11)
	pl.modulate = Color(0.40,0.40,0.40)
	pl.position = Vector2(44, 90)
	add_child(pl)

	if GameData.first_habit_name != "":
		var hl := Label.new()
		hl.text = "[ %s · %s ]" % [GameData.first_habit_name, GameData.get_habit_stage(GameData.first_habit_name)]
		hl.add_theme_font_size_override("font_size", 10)
		hl.modulate = Color(0.44,0.66,0.44)
		hl.position = Vector2(44, 107)
		add_child(hl)

	var tf_lbl := Label.new()
	tf_lbl.text = "Terrain %.1f  ·  Dodge +%.0f%%  ·  Flee %.0f%%" % [
		GameData.terrain_familiarity, GameData.get_dodge_bonus()*100, GameData.get_flee_chance()*100]
	tf_lbl.add_theme_font_size_override("font_size", 10)
	tf_lbl.modulate = Color(0.40,0.56,0.40)
	tf_lbl.position = Vector2(44, 122)
	add_child(tf_lbl)

	player_hp_bar = ProgressBar.new()
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value     = player_hp
	player_hp_bar.size      = Vector2(326, 16)
	player_hp_bar.position  = Vector2(44, 178)
	add_child(player_hp_bar)

	player_hp_label = Label.new()
	player_hp_label.text = "HP  %d / %d" % [player_hp, player_max_hp]
	player_hp_label.add_theme_font_size_override("font_size", 13)
	player_hp_label.modulate = Color(0.60, 0.86, 0.60)
	player_hp_label.position = Vector2(44, 202)
	add_child(player_hp_label)

	# Enemy Panel
	var ep := ColorRect.new()
	ep.color = Color(0.10, 0.05, 0.08)
	ep.size  = Vector2(370, 220)
	ep.position = Vector2(754, 54)
	add_child(ep)
	var es_col: Color = Color(0.65,0.08,0.08) if enemy_data.get("faction","hostile")=="hostile" else Color(0.10,0.55,0.32)
	var es := ColorRect.new()
	es.color    = es_col
	es.size     = Vector2(3, 220)
	es.position = Vector2(1120, 54)
	add_child(es)

	enemy_name_label = Label.new()
	enemy_name_label.text = "◆  %s" % enemy_data.get("name","Lone Wanderer")
	enemy_name_label.add_theme_font_size_override("font_size", 20)
	enemy_name_label.modulate = es_col
	enemy_name_label.position = Vector2(770, 64)
	add_child(enemy_name_label)

	var el := Label.new()
	el.text = "Lv.%d  ·  %s" % [enemy_data.get("level",1), enemy_data.get("faction","hostile").capitalize()]
	el.add_theme_font_size_override("font_size", 11)
	el.modulate = Color(0.40,0.40,0.40)
	el.position = Vector2(770, 90)
	add_child(el)

	enemy_desc_label = Label.new()
	enemy_desc_label.text = enemy_data.get("name","") + " — affiliation unclear."
	enemy_desc_label.add_theme_font_size_override("font_size", 11)
	enemy_desc_label.modulate = Color(0.38,0.38,0.38)
	enemy_desc_label.position = Vector2(770, 107)
	enemy_desc_label.custom_minimum_size = Vector2(340, 0)
	enemy_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(enemy_desc_label)

	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value     = enemy_hp
	enemy_hp_bar.size      = Vector2(326, 16)
	enemy_hp_bar.position  = Vector2(770, 178)
	add_child(enemy_hp_bar)

	enemy_hp_label = Label.new()
	enemy_hp_label.text = "HP  %d / %d" % [enemy_hp, enemy_max_hp]
	enemy_hp_label.add_theme_font_size_override("font_size", 13)
	enemy_hp_label.modulate = es_col
	enemy_hp_label.position = Vector2(770, 202)
	add_child(enemy_hp_label)

	var vs := Label.new()
	vs.text = "VS"
	vs.add_theme_font_size_override("font_size", 44)
	vs.modulate = Color(0.18,0.18,0.22)
	vs.position = Vector2(554, 120)
	add_child(vs)

	var ib := ColorRect.new()
	ib.color = Color(0.06,0.05,0.08)
	ib.size  = Vector2(740, 82)
	ib.position = Vector2(206, 298)
	add_child(ib)

	initiative_label = Label.new()
	initiative_label.text = _get_initiative_text()
	initiative_label.add_theme_font_size_override("font_size", 15)
	initiative_label.modulate = Color(0.70,0.68,0.60)
	initiative_label.position = Vector2(240, 306)
	initiative_label.custom_minimum_size = Vector2(660, 0)
	initiative_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(initiative_label)

	roll_btn = Button.new()
	roll_btn.text = "Roll Initiative"
	roll_btn.custom_minimum_size = Vector2(270, 54)
	roll_btn.add_theme_font_size_override("font_size", 18)
	roll_btn.position = Vector2(441, 392)
	roll_btn.pressed.connect(_roll_initiative)
	add_child(roll_btn)

	party_turn_label = Label.new()
	party_turn_label.text = ""
	party_turn_label.add_theme_font_size_override("font_size", 12)
	party_turn_label.modulate = Color(0.70, 0.90, 0.70)
	party_turn_label.position = Vector2(206, 464)
	party_turn_label.custom_minimum_size = Vector2(380, 0)
	party_turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(party_turn_label)

	var lb := ColorRect.new()
	lb.color = Color(0.04,0.03,0.06)
	lb.size  = Vector2(940, 80)
	lb.position = Vector2(106, 460)
	add_child(lb)

	log_container = VBoxContainer.new()
	log_container.position = Vector2(118, 465)
	log_container.custom_minimum_size = Vector2(918, 0)
	log_container.add_theme_constant_override("separation", 2)
	add_child(log_container)

	action_container = HBoxContainer.new()
	action_container.position = Vector2(100, 556)
	action_container.add_theme_constant_override("separation", 16)
	action_container.visible = false
	add_child(action_container)

	_build_action_buttons()
	_build_recruit_panel()
	_build_codex_panel()
	_build_attr_panel()

func _get_initiative_text() -> String:
	if GameData.party_stage == "nomad_party":
		return "Party vs %s — roll 1d6. Highest side acts first. Ties go to you." % enemy_data.get("name","enemy")
	return "Roll 1d6. Highest moves first. Ties go to you."

func _build_action_buttons() -> void:
	_make_action("⚔  Attack",  Color(0.80,0.22,0.22), _on_attack)
	_make_action("🛡  Defend",  Color(0.22,0.50,0.80), _on_defend)
	if enemy_data.get("faction","hostile") == "neutral":
		_make_action("💬  Persuade", Color(0.30,0.72,0.44), _on_persuade)
	_make_action("↩  Flee",    Color(0.50,0.50,0.22), _on_flee)

func _make_action(label: String, col: Color, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(210, 54)
	btn.add_theme_font_size_override("font_size", 16)
	btn.modulate = col
	btn.pressed.connect(cb)
	action_container.add_child(btn)

func _build_recruit_panel() -> void:
	recruit_panel = Control.new()
	recruit_panel.visible = false
	add_child(recruit_panel)
	var rb := ColorRect.new()
	rb.color = Color(0.06, 0.10, 0.06, 0.95)
	rb.size  = Vector2(700, 130)
	rb.position = Vector2(226, 460)
	recruit_panel.add_child(rb)
	var rl := Label.new()
	rl.text = "They are subdued / willing. Recruit them?"
	rl.add_theme_font_size_override("font_size", 16)
	rl.modulate = Color(0.70, 0.92, 0.70)
	rl.position = Vector2(240, 470)
	recruit_panel.add_child(rl)
	var recruit_btn := Button.new()
	recruit_btn.text = "◈  Recruit"
	recruit_btn.custom_minimum_size = Vector2(200, 48)
	recruit_btn.add_theme_font_size_override("font_size", 16)
	recruit_btn.modulate = Color(0.30, 1.0, 0.50)
	recruit_btn.position = Vector2(240, 510)
	recruit_btn.pressed.connect(_do_recruit)
	recruit_panel.add_child(recruit_btn)
	var skip_btn := Button.new()
	skip_btn.text = "Leave them"
	skip_btn.custom_minimum_size = Vector2(180, 48)
	skip_btn.add_theme_font_size_override("font_size", 14)
	skip_btn.modulate = Color(0.50, 0.50, 0.50)
	skip_btn.position = Vector2(460, 510)
	skip_btn.pressed.connect(_skip_recruit)
	recruit_panel.add_child(skip_btn)

func _build_codex_panel() -> void:
	codex_panel = Control.new()
	codex_panel.visible = false
	add_child(codex_panel)
	var cb := ColorRect.new()
	cb.color = Color(0.05,0.06,0.10,0.96)
	cb.size  = Vector2(380, 260)
	cb.position = Vector2(20, 380)
	codex_panel.add_child(cb)
	var ct := Label.new()
	ct.text = "CODEX"
	ct.add_theme_font_size_override("font_size", 14)
	ct.modulate = Color(0.55,0.55,0.75)
	ct.position = Vector2(28, 385)
	codex_panel.add_child(ct)
	for i in range(3):
		var sl := Label.new()
		sl.text = "ACTIVE %d: %s" % [i+1, GameData.codex_active[i] if GameData.codex_active[i] != "" else "—"]
		sl.add_theme_font_size_override("font_size", 11)
		sl.modulate = Color(0.70,0.82,0.70)
		sl.position = Vector2(28, 408 + i*18)
		codex_panel.add_child(sl)
	for i in range(3):
		var sl := Label.new()
		sl.text = "PASSIVE %d: %s" % [i+1, GameData.codex_passive[i] if GameData.codex_passive[i] != "" else "—"]
		sl.add_theme_font_size_override("font_size", 11)
		sl.modulate = Color(0.60,0.70,0.82)
		sl.position = Vector2(28, 462 + i*18)
		codex_panel.add_child(sl)

func _build_attr_panel() -> void:
	attr_panel = Control.new()
	attr_panel.visible = false
	add_child(attr_panel)
	var ab := ColorRect.new()
	ab.color = Color(0.06,0.06,0.10,0.96)
	ab.size  = Vector2(320, 200)
	ab.position = Vector2(416, 380)
	attr_panel.add_child(ab)
	var at := Label.new()
	at.text = "ALLOCATE ATTRIBUTES — %d points" % GameData.attr_points
	at.add_theme_font_size_override("font_size", 13)
	at.modulate = Color(0.75,0.75,0.55)
	at.position = Vector2(424, 385)
	attr_panel.add_child(at)
	var attrs := [["STR","str",Color(0.88,0.38,0.38)],["INT","int",Color(0.38,0.62,0.88)],
				  ["DEX","dex",Color(0.38,0.88,0.62)],["LCK","luck",Color(0.88,0.78,0.28)]]
	for i in range(4):
		var info: Array = attrs[i]
		var btn := Button.new()
		btn.text = "+ %s (now %d)" % [info[0], _get_attr_val(info[1])]
		btn.custom_minimum_size = Vector2(280, 38)
		btn.add_theme_font_size_override("font_size", 13)
		btn.modulate = info[2]
		btn.position = Vector2(424, 410 + i * 44)
		btn.pressed.connect(_spend_attr.bind(info[1]))
		attr_panel.add_child(btn)

func _get_attr_val(attr: String) -> int:
	match attr:
		"str": return GameData.attr_str
		"int": return GameData.attr_int
		"dex": return GameData.attr_dex
		"luck": return GameData.attr_luck
	return 0

func _spend_attr(attr: String) -> void:
	if GameData.spend_attr_point(attr):
		_rebuild_attr_panel()

func _rebuild_attr_panel() -> void:
	attr_panel.queue_free()
	_build_attr_panel()
	if GameData.attr_points > 0:
		attr_panel.visible = true

func _roll_initiative() -> void:
	roll_btn.visible = false
	var pr := randi_range(1, 6)
	var er := randi_range(1, 6)
	var p_str := "%s rolls %d" % [GameData.player_name, pr]
	if GameData.party_stage == "nomad_party" and GameData.party_members.size() > 0:
		p_str = "Your party rolls %d" % pr
	initiative_label.text = "%s.  Enemy rolls %d.  %s moves first." % [p_str, er, "YOU" if pr >= er else "ENEMY"]
	player_turn = pr >= er
	await get_tree().create_timer(1.2).timeout
	_update_party_turn_label()
	if player_turn:
		_log("Your move.")
		action_container.visible = true
		codex_panel.visible = true
		if GameData.attr_points > 0:
			attr_panel.visible = true
	else:
		_enemy_action()

func _update_party_turn_label() -> void:
	if GameData.party_stage == "nomad_party" and GameData.party_members.size() > 0:
		var order: Array = GameData.get_party_turn_order()
		var names := [GameData.player_name]
		for m in order:
			names.append(m.get("name","?"))
		party_turn_label.text = "Turn order: " + " → ".join(names)
	else:
		party_turn_label.text = ""

func _on_attack() -> void:
	if not player_turn or combat_over: return
	defending = false
	action_container.visible = false
	turn_count += 1
	var dmg: int = randi_range(8, 18) + GameData.get_damage_bonus()
	enemy_hp = max(enemy_hp - dmg, 0)
	_update_bars()
	_log("%s strikes for %d damage." % [GameData.player_name, dmg])
	GameData.add_habit("Combat Strike")
	if enemy_hp <= 0:
		_on_enemy_defeated()
		return
	player_turn = false
	await get_tree().create_timer(0.9).timeout
	_enemy_action()

func _on_defend() -> void:
	if not player_turn or combat_over: return
	defending = true
	action_container.visible = false
	_log("%s braces. Damage reduced this turn." % GameData.player_name)
	GameData.add_habit("Combat Guard")
	player_turn = false
	await get_tree().create_timer(0.9).timeout
	_enemy_action()

func _on_persuade() -> void:
	if not player_turn or combat_over: return
	if enemy_data.get("faction","hostile") != "neutral": return
	action_container.visible = false
	var chance: float = 0.30 + GameData.get_persuade_bonus() + GameData.terrain_familiarity * 0.01
	chance = clamp(chance, 0.05, 0.90)
	GameData.add_habit("Persuasion")
	if randf() < chance:
		_log("They listen. The tension breaks. They are willing to talk.")
		await get_tree().create_timer(1.0).timeout
		_show_recruit_panel()
	else:
		_log("They don't trust you yet. They hold their ground.")
		player_turn = false
		await get_tree().create_timer(0.8).timeout
		_enemy_action()

func _on_flee() -> void:
	if combat_over: return
	action_container.visible = false
	var flee_chance: float = GameData.get_flee_chance()
	GameData.add_habit("Strategic Retreat")
	if randf() < flee_chance:
		_log("You find an opening. You slip away.")
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://world.tscn")
	else:
		_log("No opening. They cut off the path.")
		player_turn = false
		await get_tree().create_timer(0.8).timeout
		_enemy_action()

func _enemy_action() -> void:
	if combat_over: return
	if enemy_data.get("faction","hostile") == "neutral" and randf() < 0.25:
		_log("They back off. Not looking for a fight.")
		player_turn = true
		await get_tree().create_timer(0.7).timeout
		_log("Your move.")
		action_container.visible = true
		return
	var dmg := randi_range(5, 14)
	if defending:
		dmg = int(dmg * 0.40)
		defending = false
	player_hp = max(player_hp - dmg, 0)
	_update_bars()
	_log("Enemy strikes for %d damage." % dmg)
	if player_hp <= 0:
		_end_combat(false)
		return
	player_turn = true
	await get_tree().create_timer(0.65).timeout
	_log("Your move.")
	action_container.visible = true

func _on_enemy_defeated() -> void:
	combat_over = true
	action_container.visible = false
	
	# FIX: Break the Variant chain explicitly to satisfy strict typing
	var lvl_val: Variant = enemy_data.get("level", 1)
	var enemy_lvl: int = lvl_val as int
	var xp: int = 20 + (enemy_lvl * 12)
	
	GameData.add_xp(xp)
	GameData.player_hp = max(player_hp, 1)
	_log("They fall. +%d XP." % xp)
	
	GameData.add_to_codex(
		enemy_data.get("name", "Unknown"),
		enemy_data.get("call", "[ Unread ]"),
		{"level": enemy_lvl, "faction": enemy_data.get("faction", "hostile")},
		"Defeated in combat."
	)
	
	await get_tree().create_timer(0.8).timeout
	_show_recruit_panel()

func _show_recruit_panel() -> void:
	action_container.visible = false
	recruit_panel.visible = true

func _do_recruit() -> void:
	recruit_panel.visible = false
	var new_member := {
		"name": enemy_data.get("name","Unknown"),
		"emoticon": "◇",
		"color": Color(randf_range(0.4,0.9), randf_range(0.4,0.9), randf_range(0.4,0.9)),
		"level": enemy_data.get("level",1),
		"hp": enemy_data.get("hp",40),
		"max_hp": enemy_data.get("max_hp",40),
		"role": _guess_role(),
		"mastery_1": "", "mastery_2": "",
		"habits": {}, "codex_skills": [],
		"relationship": 40.0, "loyalty": 30.0,
		"emotional_state": "cautious",
		"call": "[ Unread ]", "call_tier": 0,
		"type": enemy_data.get("faction","neutral"),
		"is_alpha": false,
	}
	GameData.recruit_member(new_member)
	_log("%s joins you." % new_member["name"])
	if GameData.party_members.size() == 1:
		GameData.trigger_formation_quest()
	await get_tree().create_timer(2.2).timeout
	get_tree().change_scene_to_file("res://world.tscn")

func _guess_role() -> String:
	var lv := enemy_data.get("level", 1)
	if lv >= 4: return "breaker"
	elif lv >= 2: return "anchor"
	return "auxiliary"

func _skip_recruit() -> void:
	recruit_panel.visible = false
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://world.tscn")

func _update_bars() -> void:
	if is_instance_valid(player_hp_bar): player_hp_bar.value = player_hp
	if is_instance_valid(enemy_hp_bar):  enemy_hp_bar.value  = enemy_hp
	if is_instance_valid(player_hp_label): player_hp_label.text = "HP  %d / %d" % [player_hp, player_max_hp]
	if is_instance_valid(enemy_hp_label):  enemy_hp_label.text  = "HP  %d / %d" % [enemy_hp, enemy_max_hp]

func _end_combat(won: bool) -> void:
	combat_over = true
	action_container.visible = false
	if won:
		GameData.player_hp = max(player_hp, 1)
		_log("You move on.")
	else:
		GameData.player_hp = 1
		_log("You fall. The world continues without permission.")
	await get_tree().create_timer(2.6).timeout
	get_tree().change_scene_to_file("res://world.tscn")

func _log(text: String) -> void:
	if not is_instance_valid(log_container): return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.modulate = Color(0.78,0.76,0.70)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(918, 0)
	log_container.add_child(lbl)
	while log_container.get_child_count() > 3:
		log_container.get_child(0).queue_free()

func _load_enemy_desc_groq() -> void:
	if GameData.groq_api_key.begins_with("PASTE") or GameData.groq_api_key.length() < 10: return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_desc_resp.bind(http))
	var prompt := "Enemy: %s. Type: %s. Region: %s. One sentence under 20 words. Cold, specific, grounded. What you see when you look at them." % [
		enemy_data.get("name","unknown"), enemy_data.get("faction","hostile"), GameData.starting_region]
	var body := JSON.stringify({"model":"llama3-8b-8192","messages":[{"role":"user","content":prompt}],"max_tokens":55,"temperature":0.7})
	http.request("https://api.groq.com/openai/v1/chat/completions",
		["Content-Type: application/json","Authorization: Bearer "+GameData.groq_api_key],
		HTTPClient.METHOD_POST, body)

func _on_desc_resp(_r:int, code:int, _h:PackedStringArray, body:PackedByteArray, http:HTTPRequest) -> void:
	http.queue_free()
	if code != 200: return
	
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK: return
	
	var d: Dictionary = json.get_data() as Dictionary
	
	if not d.has("choices"): return
	
	var choices: Array = d["choices"]
	if choices.is_empty(): return
	
	var message: Dictionary = choices[0].get("message", {})
	var t: String = message.get("content", "").strip_edges()
	
	if t.length() > 0 and is_instance_valid(enemy_desc_label):
		enemy_desc_label.text = t
