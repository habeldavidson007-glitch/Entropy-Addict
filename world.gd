extends Node2D
class_name WorldMap

# ─────────────────────────────────────────
# WORLD — Ashveld Flats Terrain System
# Canonical Reference: Entropy Addict Master Bible v3
# Enhanced for Open World Turn-Based SRPG
# ─────────────────────────────────────────

## Core map configuration
const TILE_SIZE: int = 32
const MAP_WIDTH: int = 40
const MAP_HEIGHT: int = 40
@export var enemy_count: int = 15

## Detection ranges (in tiles) - affected by familiar environment bonus
const RANGE_WARNING: float   = 10.0
const RANGE_VISIBLE: float   = 7.0
const RANGE_ENCOUNTER: float = 2.0

## Terrain types for Ashveld Flats (savannah/plains logic)
enum Terrain { 
	GRASS,
	DRY_GRASS,
	DIRT,
	BOULDER,
	SAND,
	WATER_POOL
}

## Terrain visual configuration
const TERRAIN_COLORS: Dictionary = {
	Terrain.GRASS:      Color(0.52, 0.68, 0.28),
	Terrain.DRY_GRASS:  Color(0.68, 0.62, 0.32),
	Terrain.DIRT:       Color(0.55, 0.42, 0.28),
	Terrain.BOULDER:    Color(0.42, 0.38, 0.35),
	Terrain.SAND:       Color(0.76, 0.70, 0.52),
	Terrain.WATER_POOL: Color(0.25, 0.42, 0.48),
}

## Terrain gameplay properties
const TERRAIN_PROPERTIES: Dictionary = {
	Terrain.GRASS:      {"movement_cost": 1.0, "defensive_bonus": 0.0, "encounter_rate": 1.0},
	Terrain.DRY_GRASS:  {"movement_cost": 1.0, "defensive_bonus": 0.05, "encounter_rate": 1.1},
	Terrain.DIRT:       {"movement_cost": 0.9, "defensive_bonus": 0.0, "encounter_rate": 0.9},
	Terrain.BOULDER:    {"movement_cost": 999.0, "defensive_bonus": 0.3, "encounter_rate": 0.0},
	Terrain.SAND:       {"movement_cost": 1.2, "defensive_bonus": 0.0, "encounter_rate": 0.8},
	Terrain.WATER_POOL: {"movement_cost": 999.0, "defensive_bonus": 0.0, "encounter_rate": 0.0},
}

# Fog of war
const FOG_COLOR: Color = Color(0.05, 0.05, 0.07)
const FOG_EXPLORED_COLOR: Color = Color(0.15, 0.15, 0.18)

# Map state
var terrain_map: Dictionary = {}
var enemy_data: Array[Dictionary] = []
var explored_tiles: Dictionary = {}
var visible_tiles: Dictionary  = {}
var _player_grid: Vector2 = Vector2(-999, -999)

@export var sight_radius: int = 5

# UI references
var level_label: Label
var xp_notification: Label
var terrain_info: Label
var encounter_log: Label
var party_status_label: Label

# Alpha/Subdue tracking
var active_subdue_target: Dictionary = {}

# Signal connections to GameData
var _game_data_connected: bool = false

func _ready() -> void:
	_connect_game_data_signals()
	_generate_ashveld_terrain()
	await _spawn_enemies()
	_setup_ui()
	
	GameData.total_map_tiles = terrain_map.size()
	print("🗺 World initialized: %dx%d (%d tiles)" % [MAP_WIDTH, MAP_HEIGHT, terrain_map.size()])
	
	var spawn := GameData.get_spawn_position()
	_player_grid = spawn
	_reveal_around(spawn)
	_update_level_display()
	_update_party_status()
	queue_redraw()

# ─────────────────────────────────────────
# SIGNAL CONNECTIONS
# ─────────────────────────────────────────
func _connect_game_data_signals() -> void:
	if _game_data_connected:
		return
	
	if GameData.has_signal("level_changed"):
		GameData.level_changed.connect(_on_level_changed)
	if GameData.has_signal("xp_changed"):
		GameData.xp_changed.connect(_on_xp_changed)
	if GameData.has_signal("party_member_added"):
		GameData.party_member_added.connect(_on_party_member_added)
	if GameData.has_signal("party_member_removed"):
		GameData.party_member_removed.connect(_on_party_member_removed)
	if GameData.has_signal("exploration_milestone_reached"):
		GameData.exploration_milestone_reached.connect(_on_exploration_milestone)
	if GameData.has_signal("combat_finished"):
		GameData.combat_finished.connect(_on_combat_finished)
	
	_game_data_connected = true

func _on_level_changed(new_level: int) -> void:
	_update_level_display()
	_show_level_up_world_effect()

func _on_xp_changed(current_xp: int, xp_to_next: int) -> void:
	_update_level_display()

func _on_party_member_added(member_data: Dictionary) -> void:
	_update_party_status()
	_show_party_member_join_notification(member_data.get("name", "Unknown"))

func _on_party_member_removed(index: int) -> void:
	_update_party_status()

func _on_exploration_milestone(percentage: int) -> void:
	_show_milestone_notification(percentage)

func _on_combat_finished(victory: bool) -> void:
	# Refresh enemy visibility after combat
	if is_instance_valid(self):
		_reveal_around(_player_grid)
		queue_redraw()

# ─────────────────────────────────────────
# UI SETUP
# ─────────────────────────────────────────
func _setup_ui() -> void:
	# Level & XP display
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.modulate = Color(0.9, 0.7, 0.3)
	level_label.position = Vector2(16, 16)
	add_child(level_label)
	
	# Terrain info display
	terrain_info = Label.new()
	terrain_info.add_theme_font_size_override("font_size", 12)
	terrain_info.modulate = Color(0.7, 0.7, 0.7)
	terrain_info.position = Vector2(16, 40)
	add_child(terrain_info)
	
	# Party status display
	party_status_label = Label.new()
	party_status_label.add_theme_font_size_override("font_size", 12)
	party_status_label.modulate = Color(0.6, 0.8, 0.9)
	party_status_label.position = Vector2(16, 55)
	add_child(party_status_label)
	
	# XP notification (popup)
	xp_notification = Label.new()
	xp_notification.add_theme_font_size_override("font_size", 24)
	xp_notification.modulate = Color(1, 0.9, 0.3)
	xp_notification.visible = false
	xp_notification.position = Vector2(400, 100)
	add_child(xp_notification)
	
	# Encounter log
	encounter_log = Label.new()
	encounter_log.add_theme_font_size_override("font_size", 14)
	encounter_log.modulate = Color(0.6, 0.7, 0.9)
	encounter_log.position = Vector2(16, 70)
	encounter_log.custom_minimum_size = Vector2(300, 40)
	encounter_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(encounter_log)

func _update_level_display() -> void:
	if level_label:
		var derived_stats = GameData.get_all_derived_stats()
		level_label.text = "★ Lv.%d | %d/%d XP\n⚔ DMG:%d | 🛡 DEF:%d | 💨 EVA:%.0f%%" % [
			GameData.player_level,
			GameData.player_xp,
			GameData.xp_to_next_level,
			derived_stats.damage,
			derived_stats.defense,
			derived_stats.evasion * 100
		]

func _update_party_status() -> void:
	if not party_status_label:
		return
	
	if GameData.party.is_empty():
		party_status_label.text = "👤 Solo"
		return
	
	var party_names: Array[String] = []
	for member in GameData.party:
		party_names.append(member.get("name", "Unknown"))
	
	party_status_label.text = "👥 Party: %s" % ", ".join(party_names)

func _update_terrain_info(grid_pos: Vector2) -> void:
	if not terrain_info or not terrain_map.has(grid_pos):
		return
	
	var terrain: Terrain = terrain_map[grid_pos]
	var names = {
		Terrain.GRASS: "Grassland",
		Terrain.DRY_GRASS: "Dry Grass",
		Terrain.DIRT: "Bare Earth",
		Terrain.BOULDER: "Boulder Field",
		Terrain.SAND: "Sandy Patch",
		Terrain.WATER_POOL: "Water Hole"
	}
	
	var props = TERRAIN_PROPERTIES.get(terrain, {})
	var def_bonus = props.get("defensive_bonus", 0.0)
	var def_text = " (+%d%% DEF)" % int(def_bonus * 100) if def_bonus > 0 else ""
	
	terrain_info.text = "%s%s" % [names.get(terrain, "Unknown"), def_text]

func _show_xp_notification(amount: int, reason: String = "") -> void:
	if xp_notification:
		xp_notification.text = "+%d XP %s" % [amount, reason]
		xp_notification.position = Vector2(400, 100)
		xp_notification.visible = true
		xp_notification.modulate.a = 1.0
		
		var tween = create_tween()
		tween.tween_property(xp_notification, "position:y", 60, 0.5).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(xp_notification, "modulate:a", 0, 0.5)
		tween.tween_callback(func(): xp_notification.visible = false)

func _show_exploration_notification(tiles: int) -> void:
	var percentage = GameData.get_exploration_display()
	var familiar_bonus = GameData.familiar_environment_bonus
	var bonus_text = " (+%d%% familiar)" % familiar_bonus if familiar_bonus > 0 else ""
	var message = "🌍 +%d tiles explored (%s)%s" % [tiles, percentage, bonus_text]
	
	var notif := Label.new()
	notif.text = message
	notif.add_theme_font_size_override("font_size", 16)
	notif.modulate = Color(0.4, 0.8, 0.9)
	notif.position = Vector2(400, 300)
	add_child(notif)
	
	var tween = create_tween()
	tween.tween_property(notif, "position:y", 250, 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(notif, "modulate:a", 0, 0.5)
	tween.tween_callback(notif.queue_free)

func _show_party_member_join_notification(member_name: String) -> void:
	var notif := Label.new()
	notif.text = "👥 %s joined the party!" % member_name
	notif.add_theme_font_size_override("font_size", 18)
	notif.modulate = Color(0.6, 0.9, 0.6)
	notif.position = Vector2(400, 200)
	add_child(notif)
	
	var tween = create_tween()
	tween.tween_property(notif, "position:y", 150, 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(notif, "modulate:a", 0, 0.5)
	tween.tween_callback(notif.queue_free)

func _show_milestone_notification(percentage: int) -> void:
	var notif := Label.new()
	notif.text = "🎯 MILESTONE: %d%% Explored!\n+Familiar Environment Bonus" % percentage
	notif.add_theme_font_size_override("font_size", 24)
	notif.modulate = Color(1, 0.9, 0.3)
	notif.position = Vector2(350, 280)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(notif)
	
	var tween = create_tween()
	tween.tween_property(notif, "position:y", 220, 0.6).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(notif, "scale", Vector2(1.1, 1.1), 0.3)
	tween.tween_property(notif, "scale", Vector2(1, 1), 0.3)
	tween.parallel().tween_property(notif, "modulate:a", 0, 0.6)
	tween.tween_callback(notif.queue_free)

# ─────────────────────────────────────────
# TERRAIN GENERATION
# ─────────────────────────────────────────
func _generate_ashveld_terrain() -> void:
	var spawn := GameData.get_spawn_position()
	
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var pos := Vector2(x, y)
			var dist_from_spawn = pos.distance_to(spawn)
			
			var roll := randf()
			
			if dist_from_spawn < 5:
				if roll < 0.85:
					terrain_map[pos] = Terrain.GRASS
				else:
					terrain_map[pos] = Terrain.DRY_GRASS
				continue
			
			if roll < 0.65:
				terrain_map[pos] = Terrain.GRASS
			elif roll < 0.80:
				terrain_map[pos] = Terrain.DRY_GRASS
			elif roll < 0.90:
				terrain_map[pos] = Terrain.DIRT
			elif roll < 0.96:
				terrain_map[pos] = Terrain.BOULDER
			elif roll < 0.99:
				terrain_map[pos] = Terrain.SAND
			else:
				terrain_map[pos] = Terrain.WATER_POOL
	
	_create_boulder_clusters(8)
	_create_dirt_paths(3)

func _create_boulder_clusters(count: int) -> void:
	for i in range(count):
		var cluster_center = Vector2(
			randi_range(8, MAP_WIDTH - 8),
			randi_range(8, MAP_HEIGHT - 8)
		)
		
		var cluster_size = randi_range(3, 7)
		for j in range(cluster_size):
			var offset = Vector2(
				randi_range(-2, 2),
				randi_range(-2, 2)
			)
			var boulder_pos = cluster_center + offset
			if terrain_map.has(boulder_pos):
				terrain_map[boulder_pos] = Terrain.BOULDER

func _create_dirt_paths(count: int) -> void:
	for i in range(count):
		var start_x = 0 if randf() < 0.5 else MAP_WIDTH - 1
		var start_y = randi_range(5, MAP_HEIGHT - 5)
		var path_start = Vector2(start_x, start_y)
		
		var end_x = MAP_WIDTH - 1 if start_x == 0 else 0
		var end_y = randi_range(5, MAP_HEIGHT - 5)
		var path_end = Vector2(end_x, end_y)
		
		var steps = max(abs(end_x - start_x), abs(end_y - start_y))
		for step in range(steps):
			var t = float(step) / steps
			var path_pos = path_start.lerp(path_end, t)
			var grid_pos = Vector2(int(path_pos.x), int(path_pos.y))
			
			if terrain_map.has(grid_pos) and terrain_map[grid_pos] != Terrain.BOULDER:
				if randf() < 0.7:
					terrain_map[grid_pos] = Terrain.DIRT
				else:
					terrain_map[grid_pos] = Terrain.DRY_GRASS

# ─────────────────────────────────────────
# ENEMY SPAWNING
# ─────────────────────────────────────────
func _spawn_enemies() -> void:
	var spawn := GameData.get_spawn_position()
	var placed := 0
	var attempts := 0
	var max_enemies = enemy_count
	
	# Enemy type pool with weights
	var enemy_types = [
		{"name": "Lone Wanderer", "weight": 1.0, "level_mod": 0},
		{"name": "Ash-Born Scout", "weight": 0.9, "level_mod": 1},
		{"name": "Flats Drifter", "weight": 0.8, "level_mod": 1},
		{"name": "Route Survivor", "weight": 0.7, "level_mod": 2},
		{"name": "Border Watcher", "weight": 0.6, "level_mod": 2},
		{"name": "Salt Marsh Runner", "weight": 0.5, "level_mod": 3},
		{"name": "Steppe Straggler", "weight": 0.4, "level_mod": 3},
		{"name": "Iron Pass Exile", "weight": 0.3, "level_mod": 4}
	]
	
	while placed < max_enemies and attempts < 1000:
		attempts += 1
		var x := randi_range(1, MAP_WIDTH - 2)
		var y := randi_range(1, MAP_HEIGHT - 2)
		var pos := Vector2(x, y)
		
		if not _is_valid_enemy_spawn(pos, spawn):
			continue
		
		# Select enemy type based on weights and player level
		var selected_type = _select_enemy_type(enemy_types, GameData.player_level)
		var enemy_name = selected_type.name
		var level_modifier = selected_type.level_mod
		
		# Generate AI call asynchronously
		var generated_call = await GameData.generate_call(enemy_name, 1.0)
		if generated_call.is_empty():
			generated_call = "Hostile entity detected"
		
		# Generate unique name for this enemy instance
		var real_name = GameData.get_or_generate_enemy_name(pos)
		
		# Calculate stats based on player level and distance from spawn
		var dist_bonus = min(int(pos.distance_to(spawn) / 5), 5)
		var base_hp = 70 + (GameData.player_level * 5) + (dist_bonus * 3)
		var hp = randi_range(int(base_hp * 0.9), int(base_hp * 1.1))
		
		enemy_data.append({
			"pos": pos,
			"enemy_name": enemy_name,
			"real_name": real_name,
			"generated_call": generated_call,
			"enemy_type": _generate_enemy_affiliation(),
			"hp": hp,
			"max_hp": hp,
			"level": GameData.player_level + level_modifier,
			"alpha_type": _determine_alpha_type(),
			"name_revealed": false,
			"xp_value": _calculate_enemy_xp(GameData.player_level + level_modifier),
			"difficulty": _calculate_difficulty(dist_bonus)
		})
		
		placed += 1
	
	print("👾 Spawned %d/%d enemies" % [placed, max_enemies])

func _is_valid_enemy_spawn(pos: Vector2, spawn: Vector2) -> bool:
	return is_walkable(pos) \
		and terrain_map.get(pos) != Terrain.BOULDER \
		and terrain_map.get(pos) != Terrain.WATER_POOL \
		and pos.distance_to(spawn) > 6.0 \
		and not _enemy_at_position(pos)

func _select_enemy_type(types: Array, player_level: int) -> Dictionary:
	# Filter types appropriate for player level
	var valid_types: Array = []
	for t in types:
		if player_level >= t.level_mod:
			valid_types.append(t)
	
	if valid_types.is_empty():
		return types[0]
	
	# Weighted random selection
	var total_weight = 0.0
	for t in valid_types:
		total_weight += t.weight
	
	var roll = randf() * total_weight
	var cumulative = 0.0
	for t in valid_types:
		cumulative += t.weight
		if roll <= cumulative:
			return t
	
	return valid_types.back()

func _generate_enemy_affiliation() -> String:
	var affiliations = [
		"Unknown affiliation — unknown intent",
		"Wandering mercenary — hostile to all",
		"Exiled soldier — seeks redemption",
		"Tribal scout — defending territory",
		"Deserted conscript — desperate survivalist"
	]
	return affiliations[randi() % affiliations.size()]

func _calculate_enemy_xp(level: int) -> int:
	return int(GameData.XP_SCALING_FACTOR * level * 10 + 20)

func _calculate_difficulty(dist_bonus: int) -> String:
	if dist_bonus <= 1:
		return "Easy"
	elif dist_bonus <= 3:
		return "Normal"
	else:
		return "Hard"

func _enemy_at_position(pos: Vector2) -> bool:
	for enemy in enemy_data:
		if enemy.pos == pos:
			return true
	return false

func _determine_alpha_type() -> String:
	var roll = randf()
	if roll < 0.4:
		return "Risen"
	elif roll < 0.7:
		return "Remnant"
	elif roll < 0.9:
		return "Lone"
	else:
		return "Delegated"

# ─────────────────────────────────────────
# FOG OF WAR
# ─────────────────────────────────────────
func _reveal_around(center: Vector2) -> void:
	visible_tiles.clear()
	var new_tiles_explored := 0
	
	# Apply familiar environment bonus to sight radius
	var familiar_bonus = GameData.familiar_environment_bonus / 100.0
	var effective_radius = sight_radius + int(familiar_bonus * 2)
	
	for dx in range(-effective_radius, effective_radius + 1):
		for dy in range(-effective_radius, effective_radius + 1):
			var tile := Vector2(center.x + dx, center.y + dy)
			if terrain_map.has(tile):
				if Vector2(dx, dy).length() <= effective_radius:
					if not explored_tiles.has(tile):
						explored_tiles[tile] = true
						new_tiles_explored += 1
					
					visible_tiles[tile] = true
	
	if new_tiles_explored > 0:
		for i in range(new_tiles_explored):
			GameData.add_explored_tile()
		
		_show_exploration_notification(new_tiles_explored)

func get_movement_cost(grid_pos: Vector2) -> float:
	if not terrain_map.has(grid_pos):
		return 1.0
	var terrain: Terrain = terrain_map[grid_pos]
	return TERRAIN_PROPERTIES.get(terrain, {}).get("movement_cost", 1.0)

func get_defensive_bonus(grid_pos: Vector2) -> float:
	if not terrain_map.has(grid_pos):
		return 0.0
	var terrain: Terrain = terrain_map[grid_pos]
	return TERRAIN_PROPERTIES.get(terrain, {}).get("defensive_bonus", 0.0)

func get_encounter_rate_modifier(grid_pos: Vector2) -> float:
	if not terrain_map.has(grid_pos):
		return 1.0
	var terrain: Terrain = terrain_map[grid_pos]
	return TERRAIN_PROPERTIES.get(terrain, {}).get("encounter_rate", 1.0)

# ─────────────────────────────────────────
# DRAW
# ─────────────────────────────────────────
func _draw() -> void:
	for grid_pos in terrain_map:
		var world_pos: Vector2 = grid_pos * TILE_SIZE
		var rect := Rect2(world_pos, Vector2(TILE_SIZE, TILE_SIZE))

		if not explored_tiles.has(grid_pos):
			draw_rect(rect, FOG_COLOR)
		elif not visible_tiles.has(grid_pos):
			var base: Color = TERRAIN_COLORS[terrain_map[grid_pos]]
			var dimmed := Color(base.r * 0.45, base.g * 0.45, base.b * 0.45)
			draw_rect(rect, dimmed)
		else:
			draw_rect(rect, TERRAIN_COLORS[terrain_map[grid_pos]])
			
			var terrain = terrain_map[grid_pos]
			if terrain == Terrain.BOULDER:
				draw_circle(world_pos + Vector2(16, 16), 10, Color(0.35, 0.32, 0.30))
				draw_circle(world_pos + Vector2(14, 14), 4, Color(0.48, 0.45, 0.42))
				draw_rect(Rect2(world_pos + Vector2(20, 22), Vector2(8, 3)), Color(0, 0, 0, 0.2))
			elif terrain == Terrain.WATER_POOL:
				draw_circle(world_pos + Vector2(16, 16), 12, Color(0.30, 0.48, 0.55, 0.6))
				draw_circle(world_pos + Vector2(14, 14), 3, Color(0.6, 0.8, 1, 0.4))
			elif terrain == Terrain.DIRT:
				if hash(grid_pos) % 3 == 0:
					draw_rect(Rect2(world_pos + Vector2(8, 10), Vector2(3, 3)), Color(0.45, 0.38, 0.30))
				if hash(grid_pos) % 5 == 0:
					draw_rect(Rect2(world_pos + Vector2(20, 18), Vector2(2, 2)), Color(0.45, 0.38, 0.30))
			elif terrain == Terrain.DRY_GRASS:
				if hash(grid_pos) % 4 == 0:
					draw_line(world_pos + Vector2(10, 24), world_pos + Vector2(10, 20), Color(0.5, 0.4, 0.2), 2)
				if hash(grid_pos) % 4 == 1:
					draw_line(world_pos + Vector2(22, 24), world_pos + Vector2(22, 19), Color(0.5, 0.4, 0.2), 2)

	for enemy in enemy_data:
		if not visible_tiles.has(enemy.pos):
			continue
		
		var dist: float = _player_grid.distance_to(enemy.pos)
		var world_pos: Vector2 = enemy.pos * TILE_SIZE
		var difficulty_color = _get_difficulty_color(enemy.get("difficulty", "Normal"))

		if dist <= RANGE_ENCOUNTER:
			# Immediate threat - bright red with exclamation
			draw_rect(Rect2(world_pos + Vector2(4, 4), Vector2(24, 24)), Color(1.0, 0.15, 0.15))
			draw_string(
				ThemeDB.fallback_font,
				world_pos + Vector2(10, -2),
				"!",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1, 20,
				Color(1.0, 0.95, 0.0)
			)
			if encounter_log:
				encounter_log.text = "⚔ %s (%s) — '%s'" % [
					enemy.get("enemy_name", "Lone Wanderer"),
					enemy.get("difficulty", "Normal"),
					enemy.get("generated_call", "Unknown")
			]
		else:
			# Standard enemy indicator with difficulty-based color
			draw_rect(Rect2(world_pos + Vector2(4, 4), Vector2(24, 24)), difficulty_color)
			
			# Alpha type indicator
			var alpha_color = _get_alpha_color(enemy.get("alpha_type", "Risen"))
			draw_rect(Rect2(world_pos + Vector2(2, 2), Vector2(4, 4)), alpha_color)
			
			# Level indicator for higher level enemies
			var enemy_level = enemy.get("level", 1)
			if enemy_level > GameData.player_level + 1:
				draw_string(
					ThemeDB.fallback_font,
					world_pos + Vector2(6, 10),
					"Lv.%d" % enemy_level,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1, 10,
					Color(1.0, 0.3, 0.3)
				)

func _get_difficulty_color(difficulty: String) -> Color:
	match difficulty:
		"Easy": return Color(0.3, 0.8, 0.3)
		"Normal": return Color(0.9, 0.15, 0.15)
		"Hard": return Color(0.6, 0.1, 0.1)
		_: return Color(0.9, 0.15, 0.15)

func _get_alpha_color(alpha_type: String) -> Color:
	match alpha_type:
		"Risen": return Color(0.7, 0.5, 0.3)    # Orange-brown
		"Remnant": return Color(0.5, 0.5, 0.7)   # Blue-gray
		"Lone": return Color(0.7, 0.7, 0.5)      # Yellow-gray
		"Delegated": return Color(0.6, 0.4, 0.6) # Purple
		_: return Color(0.7, 0.5, 0.3)
# ─────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────
func update_enemy_visibility(player_grid: Vector2) -> void:
	_player_grid = player_grid
	_reveal_around(player_grid)
	_update_level_display()
	_update_terrain_info(player_grid)
	queue_redraw()

func get_terrain_at(grid_pos: Vector2) -> Terrain:
	return terrain_map.get(grid_pos, Terrain.GRASS)

func get_detection_level(player_grid: Vector2) -> String:
	var closest := INF
	for enemy in enemy_data:
		var d: float = player_grid.distance_to(enemy.pos)
		if d < closest:
			closest = d
	
	var familiar_bonus = GameData.familiar_environment_bonus / 100.0
	if closest <= RANGE_VISIBLE and randf() < familiar_bonus:
		return "safe"
	
	if closest <= RANGE_ENCOUNTER:
		return "encounter"
	elif closest <= RANGE_VISIBLE:
		return "visible"
	elif closest <= RANGE_WARNING:
		return "warning"
	return "safe"

func get_closest_enemy_distance(player_grid: Vector2) -> float:
	var closest := INF
	for enemy in enemy_data:
		var d: float = player_grid.distance_to(enemy.pos)
		if d < closest:
			closest = d
	return closest

func check_encounter(player_grid_pos: Vector2) -> bool:
	for i in range(enemy_data.size()):
		var enemy = enemy_data[i]
		if player_grid_pos.distance_to(enemy.pos) <= RANGE_ENCOUNTER:
			active_subdue_target = {
				"index": i,
				"name": enemy.get("enemy_name", "Lone Wanderer"),
				"real_name": enemy.get("real_name", "Unknown"),
				"call": enemy.get("generated_call", "Unknown"),
				"type": enemy.get("enemy_type", "Unknown affiliation"),
				"hp": enemy.hp,
				"max_hp": enemy.max_hp,
				"alpha_type": enemy.alpha_type
			}
			
			enemy_data.remove_at(i)
			GameData.clear_enemy_name(enemy.pos)
			queue_redraw()
			return true
	return false

func is_walkable(grid_pos: Vector2) -> bool:
	if not terrain_map.has(grid_pos):
		return false
	var terrain = terrain_map[grid_pos]
	return terrain != Terrain.BOULDER and terrain != Terrain.WATER_POOL

# ─────────────────────────────────────────
# SUBDUE SYSTEM
# ─────────────────────────────────────────
func get_active_subdue_target() -> Dictionary:
	return active_subdue_target

func finalize_subdue(success: bool) -> void:
	if success and active_subdue_target:
		print("✅ %s subdued and stored" % active_subdue_target.name)
	elif active_subdue_target:
		print("❌ %s escaped" % active_subdue_target.name)
	
	active_subdue_target.clear()

# ─────────────────────────────────────────
# ALPHA SYSTEM
# ─────────────────────────────────────────
func get_alpha_summary() -> Dictionary:
	var summary = {
		"risen": 0,
		"delegated": 0,
		"remnant": 0,
		"lone": 0,
		"inherited": 0
	}
	
	for enemy in enemy_data:
		if visible_tiles.has(enemy.pos):
			var alpha = enemy.get("alpha_type", "Risen")
			if alpha in summary:
				summary[alpha.to_lower()] += 1
	
	return summary

# ─────────────────────────────────────────
# LEVEL-UP EFFECTS
# ─────────────────────────────────────────
func check_for_level_up() -> void:
	if GameData.player_level > 1:
		_show_level_up_world_effect()

func _show_level_up_world_effect() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 0.9, 0.3, 0.2)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0, 0.4)
	tween.tween_callback(flash.queue_free)

# ─────────────────────────────────────────
# SAVE/LOAD SUPPORT
# ─────────────────────────────────────────
func get_save_data() -> Dictionary:
	return {

# ─────────────────────────────────────────
# SAVE/LOAD SUPPORT
# ─────────────────────────────────────────
func get_save_data() -> Dictionary:
return {
"terrain": terrain_map,
"enemies": enemy_data,
"explored": explored_tiles.keys(),
"player_grid": _player_grid,
"version": "1.1"
}

func load_save_data(save_data: Dictionary) -> void:
if save_data.has("terrain"):
terrain_map = save_data.terrain
if save_data.has("enemies"):
enemy_data = save_data.enemies
if save_data.has("explored"):
for pos in save_data.explored:
explored_tiles[pos] = true
if save_data.has("player_grid"):
_player_grid = save_data.player_grid

# Reconnect signals after loading
_connect_game_data_signals()

queue_redraw()
print("🗺 World loaded successfully (v%s)" % save_data.get("version", "1.0"))

# ─────────────────────────────────────────
# UTILITY FUNCTIONS
# ─────────────────────────────────────────
func get_enemy_at_position(pos: Vector2) -> Dictionary:
for enemy in enemy_data:
if enemy.pos == pos:
return enemy
return {}

func remove_enemy_at_position(pos: Vector2) -> bool:
for i in range(enemy_data.size()):
if enemy_data[i].pos == pos:
enemy_data.remove_at(i)
return true
return false

func get_all_visible_enemies() -> Array[Dictionary]:
var visible: Array[Dictionary] = []
for enemy in enemy_data:
if visible_tiles.has(enemy.pos):
visible.append(enemy)
return visible

func get_enemies_by_difficulty(difficulty: String) -> Array[Dictionary]:
var filtered: Array[Dictionary] = []
for enemy in enemy_data:
if enemy.get("difficulty", "") == difficulty:
filtered.append(enemy)
return filtered

func get_enemies_by_alpha_type(alpha_type: String) -> Array[Dictionary]:
var filtered: Array[Dictionary] = []
for enemy in enemy_data:
if enemy.get("alpha_type", "") == alpha_type:
filtered.append(enemy)
return filtered

func get_total_enemy_count() -> int:
return enemy_data.size()

func get_visible_enemy_count() -> int:
var count := 0
for enemy in enemy_data:
if visible_tiles.has(enemy.pos):
count += 1
return count
