extends Node2D

const TILE_SIZE = 32
const MAP_WIDTH = 40
const MAP_HEIGHT = 40
const ENEMY_COUNT = 15

const RANGE_WARNING = 10
const RANGE_VISIBLE = 7
const RANGE_ENCOUNTER = 2

var tile_map = {}
var enemy_positions = []
var _player_grid_for_draw = Vector2(-999, -999)

enum Tile { GRASS, DIRT, WALL }

const TILE_COLORS = {
	Tile.GRASS: Color(0.18, 0.55, 0.18),
	Tile.DIRT:  Color(0.6,  0.45, 0.25),
	Tile.WALL:  Color(0.25, 0.25, 0.25),
}

func _ready():
	_generate_map()
	_spawn_enemies()
	queue_redraw()

func _generate_map():
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var roll = randf()
			if roll < 0.6:
				tile_map[Vector2(x, y)] = Tile.GRASS
			elif roll < 0.85:
				tile_map[Vector2(x, y)] = Tile.DIRT
			else:
				tile_map[Vector2(x, y)] = Tile.WALL

func _spawn_enemies():
	var placed = 0
	while placed < ENEMY_COUNT:
		var x = randi_range(1, MAP_WIDTH - 2)
		var y = randi_range(1, MAP_HEIGHT - 2)
		var pos = Vector2(x, y)
		if tile_map[pos] != Tile.WALL and pos != Vector2(10, 7) and pos not in enemy_positions:
			enemy_positions.append(pos)
			placed += 1

func _draw():
	# Draw tiles
	for grid_pos in tile_map:
		var tile_type = tile_map[grid_pos]
		var world_pos = grid_pos * TILE_SIZE
		draw_rect(Rect2(world_pos, Vector2(TILE_SIZE, TILE_SIZE)), TILE_COLORS[tile_type])

	# Draw enemies based on detection range
	for epos in enemy_positions:
		var dist = _player_grid_for_draw.distance_to(epos)
		if dist <= RANGE_VISIBLE:
			var world_pos = epos * TILE_SIZE
			draw_rect(Rect2(world_pos + Vector2(4, 4), Vector2(24, 24)), Color(0.9, 0.1, 0.1))
			# Draw "!" if within encounter range
			if dist <= RANGE_ENCOUNTER:
				draw_string(
					ThemeDB.fallback_font,
					epos * TILE_SIZE + Vector2(10, -4),
					"!",
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					20,
					Color(1, 1, 0)
				)

func update_enemy_visibility(player_grid: Vector2):
	_player_grid_for_draw = player_grid
	queue_redraw()

func get_detection_level(player_grid: Vector2) -> String:
	var closest = INF
	for epos in enemy_positions:
		var dist = player_grid.distance_to(epos)
		if dist < closest:
			closest = dist
	if closest <= RANGE_ENCOUNTER:
		return "encounter"
	elif closest <= RANGE_VISIBLE:
		return "visible"
	elif closest <= RANGE_WARNING:
		return "warning"
	else:
		return "safe"

func get_closest_enemy_distance(player_grid: Vector2) -> float:
	var closest = INF
	for epos in enemy_positions:
		var dist = player_grid.distance_to(epos)
		if dist < closest:
			closest = dist
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
