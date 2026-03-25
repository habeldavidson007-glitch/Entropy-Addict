extends Node2D

# ─────────────────────────────────────────
# WORLD — Ashveld Flats Terrain System
# Canonical Reference: Entropy Addict Master Bible v3
# ─────────────────────────────────────────

const TILE_SIZE: int = 32
const MAP_WIDTH: int = 40
const MAP_HEIGHT: int = 40
const ENEMY_COUNT: int = 15

# Detection ranges (in tiles)
const RANGE_WARNING: float   = 10.0
const RANGE_VISIBLE: float   = 7.0
const RANGE_ENCOUNTER: float = 2.0

# Terrain types for Ashveld Flats (savannah/plains logic)
enum Terrain { 
	GRASS,
	DRY_GRASS,
	DIRT,
	BOULDER,
	SAND,
	WATER_POOL
}

const TERRAIN_COLORS: Dictionary = {
	Terrain.GRASS:      Color(0.52, 0.68, 0.28),
	Terrain.DRY_GRASS:  Color(0.68, 0.62, 0.32),
	Terrain.DIRT:       Color(0.55, 0.42, 0.28),
	Terrain.BOULDER:    Color(0.42, 0.38, 0.35),
	Terrain.SAND:       Color(0.76, 0.70, 0.52),
	Terrain.WATER_POOL: Color(0.25, 0.42, 0.48),
}

# Fog of war
const FOG_COLOR: Color = Color(0.05, 0.05, 0.07)

# Map state
var terrain_map: Dictionary = {}
var enemy_data: Array = []
var explored_tiles: Dictionary = {}
var visible_tiles: Dictionary  = {}
var _player_grid: Vector2 = Vector2(-999, -999)

const SIGHT_RADIUS: int = 5

# UI references
var level_label: Label
var xp_notification: Label
var terrain_info: Label
var encounter_log: Label

# Alpha/Subdue tracking
var active_subdue_target: Dictionary = {}

func _ready() -> void:
	_generate_ashveld_terrain()
	await _spawn_enemies()  # FIXED: Added await
	_setup_ui()
	
	GameData.total_map_tiles = terrain_map.size()
	print("🗺 Total map tiles: %d" % GameData.total_map_tiles)
	
	var spawn := GameData.get_spawn_position()
	_reveal_around(spawn)
	_update_level_display()
	queue_redraw()

# ─────────────────────────────────────────
# UI SETUP
# ─────────────────────────────────────────
func _setup_ui() -> void:
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.modulate = Color(0.9, 0.7, 0.3)
	level_label.position = Vector2(16, 16)
	add_child(level_label)
	
	terrain_info = Label.new()
	terrain_info.add_theme_font_size_override("font_size", 12)
	terrain_info.modulate = Color(0.7, 0.7, 0.7)
	terrain_info.position = Vector2(16, 40)
	add_child(terrain_info)
	
	xp_notification = Label.new()
	xp_notification.add_theme_font_size_override("font_size", 24)
	xp_notification.modulate = Color(1, 0.9, 0.3)
	xp_notification.visible = false
	xp_notification.position = Vector2(400, 100)
	add_child(xp_notification)
	
	encounter_log = Label.new()
	encounter_log.add_theme_font_size_override("font_size", 14)
	encounter_log.modulate = Color(0.6, 0.7, 0.9)
	encounter_log.position = Vector2(16, 60)
	encounter_log.custom_minimum_size = Vector2(300, 40)
	encounter_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(encounter_log)

func _update_level_display() -> void:
	if level_label:
		level_label.text = "★ Lv.%d | %d/%d XP" % [
			GameData.player_level,
			GameData.player_xp,
			GameData.xp_to_next_level
		]

func _update_terrain_info(grid_pos: Vector2) -> void:
	if terrain_info and terrain_map.has(grid_pos):
		var terrain = terrain_map[grid_pos]
		var names = {
			Terrain.GRASS: "Grassland",
			Terrain.DRY_GRASS: "Dry Grass",
			Terrain.DIRT: "Bare Earth",
			Terrain.BOULDER: "Boulder Field",
			Terrain.SAND: "Sandy Patch",
			Terrain.WATER_POOL: "Water Hole"
		}
		terrain_info.text = names.get(terrain, "Unknown")

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
	var message = "🌍 +%d tiles explored (%s)" % [tiles, percentage]
	
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
	
	var milestone = int(GameData.exploration_percentage / 10.0)
	if milestone > 0 and milestone * 10 == int(GameData.exploration_percentage):
		_show_milestone_notification(milestone * 10)

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
# ENEMY SPAWNING — FIXED with await
# ─────────────────────────────────────────
func _spawn_enemies() -> void:
	var spawn := GameData.get_spawn_position()
	var placed := 0
	var attempts := 0
	
	var enemy_names = [
		"Lone Wanderer", "Ash-Born Scout", "Flats Drifter", "Route Survivor",
		"Border Watcher", "Salt Marsh Runner", "Steppe Straggler", "Iron Pass Exile"
	]
	
	while placed < ENEMY_COUNT and attempts < 1000:
		attempts += 1
		var x := randi_range(1, MAP_WIDTH - 2)
		var y := randi_range(1, MAP_HEIGHT - 2)
		var pos := Vector2(x, y)
		
		if is_walkable(pos) \
		and terrain_map.get(pos) != Terrain.BOULDER \
		and terrain_map.get(pos) != Terrain.WATER_POOL \
		and pos.distance_to(spawn) > 6.0 \
		and not _enemy_at_position(pos):
			
			var enemy_name = enemy_names[randi_range(0, enemy_names.size() - 1)]  # FIXED: renamed from "name"
			var generated_call = await GameData.generate_call("Lone Wanderer", 1.0)  # FIXED: added await + renamed from "call"
			var enemy_type = "Unknown affiliation — unknown intent"
			var hp = randi_range(70, 90)
			var real_name = GameData.get_or_generate_enemy_name(pos)  # FIXED: Generate real name
			
			enemy_data.append({
				"pos": pos,
				"enemy_name": enemy_name,  # Generic: "Lone Wanderer"
				"real_name": real_name,     # Real name: "Ghiar"
				"generated_call": generated_call,
				"enemy_type": enemy_type,
				"hp": hp,
				"max_hp": 80,
				"alpha_type": _determine_alpha_type(),
				"name_revealed": false  # Track if name has been revealed
			})
			
			placed += 1

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
	
	for dx in range(-SIGHT_RADIUS, SIGHT_RADIUS + 1):
		for dy in range(-SIGHT_RADIUS, SIGHT_RADIUS + 1):
			var tile := Vector2(center.x + dx, center.y + dy)
			if terrain_map.has(tile):
				if Vector2(dx, dy).length() <= SIGHT_RADIUS:
					if not explored_tiles.has(tile):
						explored_tiles[tile] = true
						new_tiles_explored += 1
					
					visible_tiles[tile] = true
	
	if new_tiles_explored > 0:
		for i in range(new_tiles_explored):
			GameData.add_explored_tile()
		
		_show_exploration_notification(new_tiles_explored)

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

		if dist <= RANGE_ENCOUNTER:
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
				# FIXED: Use the correct key names
				encounter_log.text = "⚔ %s — '%s'" % [enemy.get("enemy_name", "Lone Wanderer"), enemy.get("generated_call", "Unknown")]
		else:
			draw_rect(Rect2(world_pos + Vector2(4, 4), Vector2(24, 24)), Color(0.9, 0.15, 0.15))
			
			var alpha_color = Color(0.7, 0.5, 0.3) if enemy.alpha_type == "Risen" else Color(0.5, 0.5, 0.7)
			draw_rect(Rect2(world_pos + Vector2(2, 2), Vector2(4, 4)), alpha_color)

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
		"terrain": terrain_map,
		"enemies": enemy_data,
		"explored": explored_tiles.keys(),
		"player_grid": _player_grid
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
	
	queue_redraw()
