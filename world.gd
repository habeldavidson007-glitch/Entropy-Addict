extends Node2D

# ─────────────────────────────────────────
# WORLD — Map, enemies, fog of war, detection
# Attach this to the root Node2D of world.tscn
# ─────────────────────────────────────────

const TILE_SIZE: int = 32
const MAP_WIDTH: int = 40
const MAP_HEIGHT: int = 40
const ENEMY_COUNT: int = 15

# Detection ranges (in tiles)
const RANGE_WARNING: float   = 10.0
const RANGE_VISIBLE: float   = 7.0
const RANGE_ENCOUNTER: float = 2.0

# Tile types
enum Tile { GRASS, DIRT, WALL }

const TILE_COLORS: Dictionary = {
	Tile.GRASS: Color(0.18, 0.55, 0.18),
	Tile.DIRT:  Color(0.60, 0.45, 0.25),
	Tile.WALL:  Color(0.25, 0.25, 0.25),
}

# Fog of war — dark overlay color
const FOG_COLOR: Color       = Color(0.05, 0.05, 0.07)
const EXPLORED_TINT: Color   = Color(0.55, 0.55, 0.60, 1.0)

# Map state
var tile_map: Dictionary    = {}
var enemy_positions: Array  = []
var explored_tiles: Dictionary = {}   # Vector2 -> true when visited
var visible_tiles: Dictionary  = {}   # Vector2 -> true when in sight range this turn

# Player position tracked for draw
var _player_grid: Vector2 = Vector2(-999, -999)

# Sight radius for fog reveal (in tiles)
const SIGHT_RADIUS: int = 5

func _ready() -> void:
	_generate_map()
	_spawn_enemies()
	# Reveal tiles around spawn immediately
	var spawn := GameData.get_spawn_position()
	_reveal_around(spawn)
	queue_redraw()

# ─────────────────────────────────────────
# MAP GENERATION
# ─────────────────────────────────────────
func _generate_map() -> void:
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var roll := randf()
			if roll < 0.60:
				tile_map[Vector2(x, y)] = Tile.GRASS
			elif roll < 0.85:
				tile_map[Vector2(x, y)] = Tile.DIRT
			else:
				tile_map[Vector2(x, y)] = Tile.WALL

# ─────────────────────────────────────────
# ENEMY SPAWNING
# ─────────────────────────────────────────
func _spawn_enemies() -> void:
	var spawn := GameData.get_spawn_position()
	var placed := 0
	var attempts := 0
	while placed < ENEMY_COUNT and attempts < 1000:
		attempts += 1
		var x := randi_range(1, MAP_WIDTH - 2)
		var y := randi_range(1, MAP_HEIGHT - 2)
		var pos := Vector2(x, y)
		# Keep enemies away from spawn
		if tile_map.get(pos, Tile.WALL) != Tile.WALL \
		and pos.distance_to(spawn) > 6.0 \
		and pos not in enemy_positions:
			enemy_positions.append(pos)
			placed += 1

# ─────────────────────────────────────────
# FOG OF WAR
# ─────────────────────────────────────────
func _reveal_around(center: Vector2) -> void:
	visible_tiles.clear()
	for dx in range(-SIGHT_RADIUS, SIGHT_RADIUS + 1):
		for dy in range(-SIGHT_RADIUS, SIGHT_RADIUS + 1):
			var tile := Vector2(center.x + dx, center.y + dy)
			if tile_map.has(tile):
				if Vector2(dx, dy).length() <= SIGHT_RADIUS:
					explored_tiles[tile] = true
					visible_tiles[tile]  = true

# ─────────────────────────────────────────
# DRAW
# ─────────────────────────────────────────
func _draw() -> void:
	# Draw all tiles — fog / explored / visible
	for grid_pos in tile_map:
		var world_pos: Vector2 = grid_pos * TILE_SIZE
		var rect := Rect2(world_pos, Vector2(TILE_SIZE, TILE_SIZE))

		if not explored_tiles.has(grid_pos):
			# Unexplored — draw solid fog
			draw_rect(rect, FOG_COLOR)
		elif not visible_tiles.has(grid_pos):
			# Explored but not currently visible — dimmed
			var base: Color = TILE_COLORS[tile_map[grid_pos]]
			var dimmed := Color(base.r * 0.45, base.g * 0.45, base.b * 0.45)
			draw_rect(rect, dimmed)
		else:
			# Fully visible
			draw_rect(rect, TILE_COLORS[tile_map[grid_pos]])

	# Draw enemies — only if visible to player
	for epos in enemy_positions:
		if not visible_tiles.has(epos):
			continue
		var dist: float = _player_grid.distance_to(epos)
		var world_pos: Vector2 = epos * TILE_SIZE

		if dist <= RANGE_ENCOUNTER:
			# Very close — bright red + exclamation
			draw_rect(Rect2(world_pos + Vector2(4, 4), Vector2(24, 24)), Color(1.0, 0.15, 0.15))
			draw_string(
				ThemeDB.fallback_font,
				world_pos + Vector2(10, -2),
				"!",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1, 20,
				Color(1.0, 0.95, 0.0)
			)
		else:
			# Visible range — normal red
			draw_rect(Rect2(world_pos + Vector2(4, 4), Vector2(24, 24)), Color(0.9, 0.15, 0.15))

# ─────────────────────────────────────────
# PUBLIC API — called by character_body_2d
# ─────────────────────────────────────────
func update_enemy_visibility(player_grid: Vector2) -> void:
	_player_grid = player_grid
	_reveal_around(player_grid)
	queue_redraw()

func get_detection_level(player_grid: Vector2) -> String:
	var closest := INF
	for epos in enemy_positions:
		var d: float = player_grid.distance_to(epos)
		if d < closest:
			closest = d
	if closest <= RANGE_ENCOUNTER:
		return "encounter"
	elif closest <= RANGE_VISIBLE:
		return "visible"
	elif closest <= RANGE_WARNING:
		return "warning"
	return "safe"

func get_closest_enemy_distance(player_grid: Vector2) -> float:
	var closest := INF
	for epos in enemy_positions:
		var d: float = player_grid.distance_to(epos)
		if d < closest:
			closest = d
	return closest

func check_encounter(player_grid_pos: Vector2) -> bool:
	for epos in enemy_positions:
		if player_grid_pos.distance_to(epos) <= RANGE_ENCOUNTER:
			enemy_positions.erase(epos)
			queue_redraw()
			return true
	return false

func is_walkable(grid_pos: Vector2) -> bool:
	if not tile_map.has(grid_pos):
		return false
	return tile_map[grid_pos] != Tile.WALL
