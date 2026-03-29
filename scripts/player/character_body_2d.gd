extends CharacterBody2D
# ═══════════════════════════════════════════════════════════
# PLAYER — Top-down movement, 2×d12 dice, HUD
# ═══════════════════════════════════════════════════════════

const TILE_SIZE: int = 32
const MOVE_DURATION: float = 0.10

var shadow_rect: ColorRect
var body_rect: ColorRect
var collision_shape: CollisionShape2D

var dice_result: int  = 0
var is_moving: bool   = false
var tiles_remaining: int = 0
var move_direction: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var blocked_direction: String = ""

var ui_layer: CanvasLayer
var dice_label: Label
var hp_label: Label
var level_label: Label
var time_label: Label
var familiarity_label: Label
var quest_panel: Control
var quest_label: Label
var direction_buttons: Control
var buttons: Dictionary = {}

var camera: Camera2D
var shake_intensity: float = 0.0
var shake_duration: float  = 0.0
var shake_timer: float     = 0.0

var flash_overlay: ColorRect
var is_transitioning: bool = false
var world_ref: Node
var _quest_show_timer: float = 0.0

func _ready() -> void:
	position = GameData.get_spawn_position() * TILE_SIZE
	target_position = position
	_build_player()
	_setup_camera()
	_setup_ui()
	world_ref = get_parent()
	
	if GameData.has_signal("quest_completed"):
		GameData.connect("quest_completed", _on_quest_completed)
	if GameData.has_signal("level_up"):
		GameData.connect("level_up", _on_level_up)
	if GameData.has_signal("party_updated"):
		GameData.connect("party_updated", _on_party_updated)
		
	GameData.trigger_explore_quest()

func _build_player() -> void:
	shadow_rect = ColorRect.new()
	shadow_rect.size = Vector2(TILE_SIZE-2, TILE_SIZE-2)
	shadow_rect.position = Vector2(-TILE_SIZE/2.0+4, -TILE_SIZE/2.0+5)
	shadow_rect.color = Color(0,0,0,0.38)
	add_child(shadow_rect)

	body_rect = ColorRect.new()
	body_rect.size = Vector2(TILE_SIZE-4, TILE_SIZE-4)
	body_rect.position = Vector2(-TILE_SIZE/2.0, -TILE_SIZE/2.0)
	body_rect.color = GameData.player_color
	add_child(body_rect)

	var hi1 := ColorRect.new()
	hi1.size = Vector2(TILE_SIZE-4, 5)
	hi1.position = Vector2(-TILE_SIZE/2.0, -TILE_SIZE/2.0)
	hi1.color = Color(1,1,1,0.26)
	add_child(hi1)
	
	var hi2 := ColorRect.new()
	hi2.size = Vector2(4, TILE_SIZE-4)
	hi2.position = Vector2(-TILE_SIZE/2.0, -TILE_SIZE/2.0)
	hi2.color = Color(1,1,1,0.14)
	add_child(hi2)

	collision_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE_SIZE-8, TILE_SIZE-8)
	collision_shape.shape = shape
	add_child(collision_shape)

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.5
	camera.zoom = Vector2(1.5, 1.5)
	add_child(camera)

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1,1,1,0)
	flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(flash_overlay)

	var hud := ColorRect.new()
	hud.color = Color(0.04,0.04,0.05,0.92)
	hud.size = Vector2(1152, 54)
	ui_layer.add_child(hud)
	
	var accent := ColorRect.new()
	accent.color = GameData.player_color * Color(0.6,0.6,0.6,1)
	accent.size = Vector2(1152, 2)
	accent.position = Vector2(0, 52)
	ui_layer.add_child(accent)

	var name_lbl := Label.new()
	name_lbl.text = "%s  %s" % [GameData.player_emoticon, GameData.player_name]
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.modulate = GameData.player_color
	name_lbl.position = Vector2(14, 12)
	ui_layer.add_child(name_lbl)

	var reg_lbl := Label.new()
	reg_lbl.text = GameData.starting_region
	reg_lbl.add_theme_font_size_override("font_size", 10)
	reg_lbl.modulate = Color(0.40,0.40,0.40)
	reg_lbl.position = Vector2(14, 38)
	ui_layer.add_child(reg_lbl)

	hp_label = Label.new()
	hp_label.text = "HP  %d / %d" % [GameData.player_hp, GameData.player_max_hp]
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.modulate = Color(0.55, 0.88, 0.55)
	hp_label.position = Vector2(280, 10)
	ui_layer.add_child(hp_label)

	level_label = Label.new()
	level_label.text = "Lv.%d  XP %d/%d  STR%d INT%d DEX%d LCK%d" % [
		GameData.player_level, GameData.player_xp, GameData.player_level*120,
		GameData.attr_str, GameData.attr_int, GameData.attr_dex, GameData.attr_luck]
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.modulate = Color(0.50,0.50,0.50)
	level_label.position = Vector2(280, 33)
	ui_layer.add_child(level_label)

	familiarity_label = Label.new()
	familiarity_label.text = "Terrain %.1f  |  Dodge +%.0f%%" % [GameData.terrain_familiarity, GameData.get_dodge_bonus()*100]
	familiarity_label.add_theme_font_size_override("font_size", 10)
	familiarity_label.modulate = Color(0.42,0.55,0.42)
	familiarity_label.position = Vector2(680, 14)
	ui_layer.add_child(familiarity_label)

	time_label = Label.new()
	time_label.text = GameData.get_time_label()
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.modulate = Color(0.62,0.60,0.50)
	time_label.position = Vector2(900, 10)
	ui_layer.add_child(time_label)

	var day_lbl := Label.new()
	day_lbl.text = "Day %d" % GameData.days_survived
	day_lbl.add_theme_font_size_override("font_size", 11)
	day_lbl.modulate = Color(0.35,0.35,0.35)
	day_lbl.position = Vector2(900, 30)
	ui_layer.add_child(day_lbl)

	if GameData.first_habit_name != "":
		var habit_lbl := Label.new()
		habit_lbl.text = "[ %s ]" % GameData.first_habit_name
		habit_lbl.add_theme_font_size_override("font_size", 10)
		habit_lbl.modulate = Color(0.45,0.68,0.45)
		habit_lbl.position = Vector2(550, 14)
		ui_layer.add_child(habit_lbl)

	var status_bg := ColorRect.new()
	status_bg.color = Color(0.04,0.04,0.05,0.78)
	status_bg.size = Vector2(680, 36)
	status_bg.position = Vector2(14, 56)
	ui_layer.add_child(status_bg)

	dice_label = Label.new()
	dice_label.position = Vector2(20, 62)
	dice_label.text = "Press SPACE to roll the dice. (2d12)"
	dice_label.add_theme_font_size_override("font_size", 15)
	dice_label.modulate = Color(0.84,0.81,0.72)
	ui_layer.add_child(dice_label)

	quest_panel = Control.new()
	quest_panel.visible = false
	ui_layer.add_child(quest_panel)
	
	var qbg := ColorRect.new()
	qbg.color = Color(0.06,0.08,0.06,0.92)
	qbg.size = Vector2(580, 56)
	qbg.position = Vector2(286, 56)
	quest_panel.add_child(qbg)
	
	var qaccent := ColorRect.new()
	qaccent.color = Color(0.28, 0.88, 0.28)
	qaccent.size = Vector2(3, 56)
	qaccent.position = Vector2(286, 56)
	quest_panel.add_child(qaccent)
	
	quest_label = Label.new()
	quest_label.position = Vector2(296, 62)
	quest_label.text = ""
	quest_label.add_theme_font_size_override("font_size", 13)
	quest_label.modulate = Color(0.6, 0.92, 0.6)
	quest_label.custom_minimum_size = Vector2(566, 0)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_panel.add_child(quest_label)

	direction_buttons = Control.new()
	direction_buttons.visible = false
	ui_layer.add_child(direction_buttons)
	_make_button("▲", Vector2(220, 110), "up")
	_make_button("▼", Vector2(220, 188), "down")
	_make_button("◄", Vector2(142, 148), "left")
	_make_button("►", Vector2(298, 148), "right")

func _make_button(label: String, pos: Vector2, dir: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.position = pos
	btn.size = Vector2(68, 68)
	btn.add_theme_font_size_override("font_size", 26)
	btn.pressed.connect(_on_direction_chosen.bind(dir))
	direction_buttons.add_child(btn)
	buttons[dir] = btn

func _show_direction_buttons(blocked: String = "") -> void:
	direction_buttons.visible = true
	for dir in buttons:
		buttons[dir].visible = (dir != blocked)

func _input(event: InputEvent) -> void:
	if is_transitioning: return
	if event.is_action_pressed("ui_accept") and not is_moving and dice_result == 0 and tiles_remaining == 0:
		_roll_dice()
		return
	if direction_buttons.visible and not is_moving:
		if event.is_action_pressed("ui_up") and blocked_direction != "up":
			_on_direction_chosen("up")
		elif event.is_action_pressed("ui_down") and blocked_direction != "down":
			_on_direction_chosen("down")
		elif event.is_action_pressed("ui_left") and blocked_direction != "left":
			_on_direction_chosen("left")
		elif event.is_action_pressed("ui_right") and blocked_direction != "right":
			_on_direction_chosen("right")

func _roll_dice() -> void:
	var d1 := randi_range(1, 12)
	var d2 := randi_range(1, 12)
	dice_result = d1 + d2
	blocked_direction = ""
	dice_label.text = "Rolled %d + %d = %d  —  choose direction." % [d1, d2, dice_result]
	_show_direction_buttons()
	GameData.add_habit("Dice Roll")

func _on_direction_chosen(dir: String) -> void:
	direction_buttons.visible = false
	if dice_result > 0:
		tiles_remaining = dice_result
		dice_result = 0
	match dir:
		"up":    move_direction = Vector2(0, -TILE_SIZE)
		"down":  move_direction = Vector2(0,  TILE_SIZE)
		"left":  move_direction = Vector2(-TILE_SIZE, 0)
		"right": move_direction = Vector2( TILE_SIZE, 0)
	blocked_direction = ""
	_move_next_tile()

func _move_next_tile() -> void:
	if tiles_remaining <= 0:
		var gp := Vector2i(position / TILE_SIZE)
		if world_ref:
			world_ref.update_enemy_visibility(gp)
			var detect_level: String = world_ref.get_detection_level(gp)
			var dist: float = world_ref.get_closest_enemy_distance(gp)
			_check_detection(detect_level, dist)
			if world_ref.check_encounter(gp):
				_trigger_battle_transition()
			else:
				is_moving = false
		else:
			is_moving = false
		return
		
	var next_pos  := position + move_direction
	var next_grid := Vector2i(next_pos / TILE_SIZE)
	
	if not world_ref or not world_ref.is_walkable(next_grid):
		if   move_direction == Vector2(0,-TILE_SIZE): blocked_direction = "up"
		elif move_direction == Vector2(0, TILE_SIZE):  blocked_direction = "down"
		elif move_direction == Vector2(-TILE_SIZE,0):  blocked_direction = "left"
		elif move_direction == Vector2( TILE_SIZE,0):  blocked_direction = "right"
		is_moving = false
		dice_label.text = "Blocked. %d moves left — choose another direction." % tiles_remaining
		_show_direction_buttons(blocked_direction)
		return
		
	is_moving = true
	target_position = next_pos
	tiles_remaining -= 1

func _check_detection(level: String, dist: float) -> void:
	match level:
		"encounter": dice_label.text = "❗ Enemy right here."
		"visible":
			dice_label.text = "⚠  Enemy %.0f tiles away. Stay sharp." % dist
			_start_shake(2.5, 0.28)
		"warning":   dice_label.text = "👁  Presence detected — %.0f tiles. Be aware." % dist
		"safe":      dice_label.text = "Press SPACE to roll. (2d12)"

func _trigger_battle_transition() -> void:
	is_transitioning = true
	dice_label.text = "⚔  Enemy encountered."
	_start_shake(10.0, 0.60)
	var tw := create_tween()
	tw.tween_property(flash_overlay, "color", Color(1,1,1,1), 0.11)
	tw.tween_property(flash_overlay, "color", Color(1,1,1,0), 0.11)
	tw.tween_property(flash_overlay, "color", Color(1,1,1,1), 0.11)
	tw.tween_property(flash_overlay, "color", Color(1,1,1,0), 0.11)
	tw.tween_property(flash_overlay, "color", Color(1,1,1,1), 0.30)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://combat.tscn")
	)

func _start_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration  = duration
	shake_timer     = duration

func _on_quest_completed(quest_id: String) -> void:
	_show_quest_notification("✓ Quest complete: " + quest_id.replace("_"," ").capitalize())

func _on_level_up(new_level: int) -> void:
	_show_quest_notification("↑ Level up! Now Lv.%d — %d attribute points available." % [new_level, GameData.attr_points])

func _on_party_updated() -> void:
	if GameData.party_stage == "nomad_party":
		_show_quest_notification("◈ Nomad Party formed — %d members." % (GameData.party_members.size()+1))

func _show_quest_notification(text: String) -> void:
	if is_instance_valid(quest_label):
		quest_label.text = text
	if is_instance_valid(quest_panel):
		quest_panel.visible = true
	_quest_show_timer = 4.5

func _process(delta: float) -> void:
	if shake_timer > 0:
		shake_timer -= delta
		var a := (shake_timer / shake_duration) * shake_intensity
		camera.offset = Vector2(randf_range(-a,a), randf_range(-a,a))
	else:
		camera.offset = Vector2.ZERO

	if is_moving and not is_transitioning:
		position = position.move_toward(target_position, TILE_SIZE / MOVE_DURATION * delta)
		if position == target_position:
			_move_next_tile()

	if _quest_show_timer > 0:
		_quest_show_timer -= delta
		if _quest_show_timer <= 0 and is_instance_valid(quest_panel):
			quest_panel.visible = false

	var b := GameData.get_ambient_brightness()
	if is_instance_valid(body_rect):
		var tinted := GameData.player_color * b
		tinted.a = 1.0
		body_rect.color = tinted

	if is_instance_valid(hp_label):
		hp_label.text = "HP  %d / %d" % [GameData.player_hp, GameData.player_max_hp]
	if is_instance_valid(level_label):
		level_label.text = "Lv.%d  XP %d/%d  STR%d INT%d DEX%d LCK%d" % [
			GameData.player_level, GameData.player_xp, GameData.player_level*120,
			GameData.attr_str, GameData.attr_int, GameData.attr_dex, GameData.attr_luck]
	if is_instance_valid(familiarity_label):
		familiarity_label.text = "Terrain %.1f  |  Dodge +%.0f%%" % [GameData.terrain_familiarity, GameData.get_dodge_bonus()*100]
	if is_instance_valid(time_label):
		time_label.text = GameData.get_time_label()
