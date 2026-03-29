extends Node2D
class_name WorldMap

const TILE_SIZE: int = 32
const MAP_WIDTH: int = 40
const MAP_HEIGHT: int = 40
const ENEMY_COUNT: int = 12

const RANGE_WARNING: float   = 10.0
const RANGE_VISIBLE: float   = 7.0
const RANGE_ENCOUNTER: float = 2.0

var tile_map: Dictionary = {}
var enemies: Array = []
var _player_grid: Vector2 = Vector2(-999, -999)

var daynight_overlay: ColorRect
var creature_node: Node2D

enum Tile { GRASS, DIRT, WALL, WATER, STONE, SAND }

const BASE_COLORS: Dictionary = {
	Tile.GRASS: Color(0.20, 0.54, 0.20),
	Tile.DIRT:  Color(0.60, 0.44, 0.26),
	Tile.WALL:  Color(0.24, 0.24, 0.26),
	Tile.WATER: Color(0.18, 0.34, 0.58),
	Tile.STONE: Color(0.38, 0.38, 0.40),
	Tile.SAND:  Color(0.72, 0.64, 0.42),
}
const SHADOW_COLORS: Dictionary = {
	Tile.GRASS: Color(0.10, 0.32, 0.10),
	Tile.DIRT:  Color(0.38, 0.26, 0.14),
	Tile.WALL:  Color(0.10, 0.10, 0.12),
	Tile.WATER: Color(0.08, 0.18, 0.34),
	Tile.STONE: Color(0.20, 0.20, 0.22),
	Tile.SAND:  Color(0.48, 0.42, 0.26),
}
const HIGHLIGHT_COLORS: Dictionary = {
	Tile.GRASS: Color(0.36, 0.72, 0.36),
	Tile.DIRT:  Color(0.76, 0.60, 0.40),
	Tile.WALL:  Color(0.38, 0.38, 0.42),
	Tile.WATER: Color(0.40, 0.58, 0.82),
	Tile.STONE: Color(0.56, 0.56, 0.60),
	Tile.SAND:  Color(0.88, 0.82, 0.60),
}

const LONE_WANDERER_NAMES: Dictionary = {
	"neutral": ["Road-Worn Traveler","Former Ironwind Outrider","Salt Marsh Drifter",
				"Sunfall Vagrant","Displaced Farmer","Steppe Exile"],
	"hostile": ["Route Hijacker","Barrens Raider","Flats Scavenger",
				"Succession War Remnant","Iron Pass Fugitive","Ashborn Deserter"]
}

func _ready() -> void:
	_generate_map()
	_smooth_map()
	_carve_paths()
	_spawn_enemies()
	_build_daynight_overlay()
	_spawn_creatures()
	queue_redraw()

func _generate_map() -> void:
	# FIX: Explicit type annotation
	var bias: String = GameData.get_tile_bias()
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			if x == 0 or y == 0 or x == MAP_WIDTH-1 or y == MAP_HEIGHT-1:
				tile_map[Vector2i(x,y)] = Tile.WALL
				continue
			tile_map[Vector2i(x,y)] = _tile_for_bias(bias)

func _tile_for_bias(bias: String) -> Tile:
	var r := randf()
	if bias == "grass":
		if r<0.72: return Tile.GRASS
		elif r<0.88: return Tile.DIRT
		elif r<0.94: return Tile.SAND
		return Tile.WALL
	elif bias == "stone" or bias == "rocky":
		if r<0.28: return Tile.GRASS
		elif r<0.44: return Tile.DIRT
		elif r<0.72: return Tile.STONE
		return Tile.WALL
	elif bias == "forest":
		if r<0.50: return Tile.GRASS
		elif r<0.62: return Tile.DIRT
		elif r<0.70: return Tile.STONE
		return Tile.WALL
	elif bias == "coastal":
		if r<0.44: return Tile.GRASS
		elif r<0.58: return Tile.SAND
		elif r<0.68: return Tile.STONE
		elif r<0.78: return Tile.WATER
		return Tile.WALL
	elif bias == "marsh":
		if r<0.36: return Tile.GRASS
		elif r<0.54: return Tile.DIRT
		elif r<0.70: return Tile.WATER
		elif r<0.80: return Tile.STONE
		return Tile.WALL
	elif bias == "barren":
		if r<0.24: return Tile.GRASS
		elif r<0.40: return Tile.DIRT
		elif r<0.66: return Tile.STONE
		return Tile.WALL
	else:
		if r<0.52: return Tile.GRASS
		elif r<0.74: return Tile.DIRT
		elif r<0.86: return Tile.STONE
		return Tile.WALL

func _smooth_map() -> void:
	var copy := tile_map.duplicate()
	for x in range(1, MAP_WIDTH-1):
		for y in range(1, MAP_HEIGHT-1):
			var walls := 0
			for dx in range(-1,2):
				for dy in range(-1,2):
					if copy.get(Vector2i(x+dx,y+dy), Tile.WALL) == Tile.WALL:
						walls += 1
			if walls >= 6: tile_map[Vector2i(x,y)] = Tile.WALL
			elif walls <= 2 and copy[Vector2i(x,y)] == Tile.WALL: tile_map[Vector2i(x,y)] = Tile.DIRT

func _carve_paths() -> void:
	var mx: int = int(MAP_WIDTH / 2.0)
	var my: int = int(MAP_HEIGHT / 2.0)
	
	for x in range(1, MAP_WIDTH-1):
		var pos := Vector2i(x, my)
		if tile_map.has(pos) and tile_map[pos] == Tile.WALL:
			tile_map[pos] = Tile.DIRT
			
	for y in range(1, MAP_HEIGHT-1):
		var pos := Vector2i(mx, y)
		if tile_map.has(pos) and tile_map[pos] == Tile.WALL:
			tile_map[pos] = Tile.DIRT
			
	# Clear spawn zone
	# FIX: Explicit type annotation
	var sp: Vector2i = GameData.get_spawn_position()
	for dx in range(-2,3):
		for dy in range(-2,3):
			var p := Vector2i(sp.x+dx, sp.y+dy)
			if tile_map.has(p) and tile_map[p] in [Tile.WALL, Tile.WATER]:
				tile_map[p] = Tile.DIRT

func _spawn_enemies() -> void:
	# FIX: Explicit type annotation
	var sp: Vector2i = GameData.get_spawn_position()
	var placed := 0
	var attempts := 0
	while placed < ENEMY_COUNT and attempts < 600:
		attempts += 1
		var x := randi_range(2, MAP_WIDTH-3)
		var y := randi_range(2, MAP_HEIGHT-3)
		var pos := Vector2i(x,y)
		if tile_map.get(pos, Tile.WALL) in [Tile.WALL, Tile.WATER]: continue
		if pos.distance_to(sp) < 5.0: continue
		if _enemy_at(pos): continue
		
		var faction := "hostile" if randf() < 0.60 else "neutral"
		var type_pool: Array = LONE_WANDERER_NAMES[faction]
		var enemy_level := randi_range(1, GameData.player_level + 2)
		enemies.append({
			"pos": pos,
			"faction": faction,
			"hp": 40 + enemy_level * 8,
			"max_hp": 40 + enemy_level * 8,
			"level": enemy_level,
			"name": type_pool[randi() % type_pool.size()],
			"subdued": false,
			"type": "lone_wanderer",
			"is_alpha": false,
		})
		placed += 1

func _enemy_at(pos: Vector2i) -> bool:
	for e in enemies:
		if e["pos"] == pos: return true
	return false

func _spawn_creatures() -> void:
	var ca := load("res://creature_animator.gd")
	if ca == null: return
	creature_node = Node2D.new()
	creature_node.set_script(ca)
	add_child(creature_node)

func _build_daynight_overlay() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 2
	add_child(cl)
	daynight_overlay = ColorRect.new()
	daynight_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	daynight_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	daynight_overlay.color = Color(0,0,0,0)
	cl.add_child(daynight_overlay)

func _process(delta: float) -> void:
	GameData.advance_time(delta)
	# FIX: Explicit type annotations
	var b: float = GameData.get_ambient_brightness()
	var sky: Color = GameData.get_sky_color()
	if is_instance_valid(daynight_overlay):
		daynight_overlay.color = Color(sky.r*0.35, sky.g*0.25, sky.b*0.45, (1.0-b)*0.78)
	if is_instance_valid(creature_node):
		creature_node.update_visibility(_player_grid)
	queue_redraw()

func _draw() -> void:
	# FIX: Explicit type annotation
	var b: float = GameData.get_ambient_brightness()
	_draw_tiles(b)
	_draw_explored_overlay()
	_draw_enemy_shadows()
	_draw_enemies(b)

func _draw_tiles(b: float) -> void:
	for gp in tile_map:
		var tt: Tile = tile_map[gp]
		var wp: Vector2 = gp * TILE_SIZE
		var base: Color = BASE_COLORS[tt] * b
		draw_rect(Rect2(wp, Vector2(TILE_SIZE, TILE_SIZE)), base)
		if tt == Tile.WALL or tt == Tile.STONE:
			draw_rect(Rect2(wp, Vector2(TILE_SIZE, 3)), HIGHLIGHT_COLORS[tt]*b)
			draw_rect(Rect2(wp, Vector2(3, TILE_SIZE)), HIGHLIGHT_COLORS[tt]*b)
			draw_rect(Rect2(wp+Vector2(0,TILE_SIZE-3), Vector2(TILE_SIZE,3)), SHADOW_COLORS[tt]*b)
			draw_rect(Rect2(wp+Vector2(TILE_SIZE-3,0), Vector2(3,TILE_SIZE)), SHADOW_COLORS[tt]*b)
		elif tt == Tile.WATER:
			var t_ms := Time.get_ticks_msec() * 0.001
			var sh := 0.16 + 0.07 * sin(t_ms + gp.x*0.3)
			draw_rect(Rect2(wp+Vector2(4,6),  Vector2(TILE_SIZE-8,2)), Color(0.5,0.75,1.0,sh))
			draw_rect(Rect2(wp+Vector2(8,14), Vector2(TILE_SIZE-12,2)), Color(0.5,0.75,1.0,sh*0.6))
			draw_rect(Rect2(wp+Vector2(3,22), Vector2(TILE_SIZE-6,2)), Color(0.5,0.75,1.0,sh*0.35))
		elif tt == Tile.GRASS:
			if (int(gp.x)*7+int(gp.y)*13)%5 == 0:
				draw_rect(Rect2(wp+Vector2(6,8), Vector2(8,8)), SHADOW_COLORS[tt]*b*0.7)

func _draw_explored_overlay() -> void:
	for gp in tile_map:
		if not GameData.explored_tiles.has(gp) and _player_grid.distance_to(gp) > RANGE_VISIBLE + 1:
			draw_rect(Rect2(gp*TILE_SIZE, Vector2(TILE_SIZE,TILE_SIZE)), Color(0,0,0,0.55))

func _draw_enemy_shadows() -> void:
	for e in enemies:
		if _player_grid.distance_to(e["pos"]) > RANGE_VISIBLE: continue
		if e["subdued"]: continue
		var wp: Vector2 = e["pos"] * TILE_SIZE
		var pts := PackedVector2Array()
		for i in range(12):
			var a := i * TAU / 12
			pts.append(wp + Vector2(18, 22) + Vector2(cos(a)*11, sin(a)*5))
		draw_colored_polygon(pts, Color(0,0,0,0.35))

func _draw_enemies(b: float) -> void:
	for e in enemies:
		var dist: float = _player_grid.distance_to(e["pos"])
		if dist > RANGE_VISIBLE: continue
		if e["subdued"]: continue
		var wp: Vector2 = e["pos"] * TILE_SIZE
		var t_ms := Time.get_ticks_msec() * 0.001
		var bob := sin(t_ms * 2.0 + e["pos"].x) * 1.2

		var body_col: Color
		var top_col: Color
		if e["faction"] == "hostile":
			body_col = Color(0.80, 0.14, 0.14) * b
			top_col  = Color(1.0, 0.45, 0.45) * b
		else:
			body_col = Color(0.24, 0.60, 0.74) * b
			top_col  = Color(0.55, 0.82, 0.92) * b

		draw_rect(Rect2(wp+Vector2(5,5+bob), Vector2(22,22)), body_col)
		draw_rect(Rect2(wp+Vector2(5,5+bob), Vector2(22,3)), top_col)
		draw_rect(Rect2(wp+Vector2(5,5+bob), Vector2(3,22)), top_col)
		draw_rect(Rect2(wp+Vector2(5,24+bob), Vector2(22,3)), body_col*Color(0.5,0.5,0.5,1))
		draw_rect(Rect2(wp+Vector2(24,5+bob), Vector2(3,22)), body_col*Color(0.5,0.5,0.5,1))
		
		for lv in range(min(e["level"], 5)):
			draw_rect(Rect2(wp+Vector2(7+lv*4, 8+bob), Vector2(2,2)), Color(1,1,1,0.7))
			
		if dist <= RANGE_ENCOUNTER:
			draw_rect(Rect2(wp+Vector2(2,-24), Vector2(TILE_SIZE-4,20)), Color(0.95,0.88,0.10,0.88))
			draw_string(ThemeDB.fallback_font, wp+Vector2(13,-7), "!", HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(0.08,0.08,0.08))
		elif dist <= RANGE_WARNING and dist > RANGE_VISIBLE - 0.5:
			var pulse := 0.28 + 0.18*sin(t_ms*4.0)
			draw_rect(Rect2(wp+Vector2(2,2), Vector2(TILE_SIZE-4,TILE_SIZE-4)), Color(1.0,0.6,0.1,pulse), false, 1.5)
			
		if e["faction"] == "neutral":
			draw_string(ThemeDB.fallback_font, wp+Vector2(4,2+bob), "?", HORIZONTAL_ALIGNMENT_LEFT,-1,12, Color(0.8,1.0,0.4))

func update_enemy_visibility(player_grid: Vector2) -> void:
	_player_grid = player_grid
	for dx in range(-int(RANGE_VISIBLE)-1, int(RANGE_VISIBLE)+2):
		for dy in range(-int(RANGE_VISIBLE)-1, int(RANGE_VISIBLE)+2):
			var gp := player_grid + Vector2(dx, dy)
			if gp.distance_to(player_grid) <= RANGE_VISIBLE:
				GameData.mark_explored(gp)
	queue_redraw()

func get_detection_level(player_grid: Vector2) -> String:
	var closest := INF
	var closest_faction := "hostile"
	for e in enemies:
		if e["subdued"]: continue
		var d: float = player_grid.distance_to(e["pos"])
		if d < closest:
			closest = d
			closest_faction = e["faction"]
	if GameData.party_stage == "nomad_party" and closest_faction == "neutral":
		return "safe"
	if closest <= RANGE_ENCOUNTER: return "encounter"
	elif closest <= RANGE_VISIBLE:  return "visible"
	elif closest <= RANGE_WARNING:  return "warning"
	return "safe"

func get_closest_enemy_distance(player_grid: Vector2) -> float:
	var closest := INF
	for e in enemies:
		if e["subdued"]: continue
		var d: float = player_grid.distance_to(e["pos"])
		if d < closest: closest = d
	return closest

func get_encounter_data(player_grid: Vector2) -> Dictionary:
	for e in enemies:
		if e["subdued"]: continue
		if player_grid.distance_to(e["pos"]) <= RANGE_ENCOUNTER:
			return e
	return {}

func check_encounter(player_grid_pos: Vector2) -> bool:
	var ed := get_encounter_data(player_grid_pos)
	if ed.is_empty(): return false
	GameData.encounter_enemy = ed
	return true

func resolve_encounter(enemy_data: Dictionary, outcome: String) -> void:
	for i in range(enemies.size()):
		if enemies[i]["pos"] == enemy_data["pos"]:
			match outcome:
				"defeated": enemies.remove_at(i)
				"subdued": enemies[i]["subdued"] = true
				"fled": pass
			break
	queue_redraw()

func is_walkable(grid_pos: Vector2) -> bool:
	var key := Vector2i(grid_pos)
	if not tile_map.has(key): return false
	return tile_map[key] not in [Tile.WALL, Tile.WATER]
