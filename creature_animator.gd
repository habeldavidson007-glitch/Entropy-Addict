extends Node2D
# ═══════════════════════════════════════════════════════════
# CREATURE ANIMATOR
# ═══════════════════════════════════════════════════════════

const TILE_SIZE: int = 32

var creatures: Array = []
var _time: float = 0.0

const CREATURE_TYPES: Dictionary = {
	"hyena": {
		"body_color": Color(0.72, 0.65, 0.42), "spot_color": Color(0.38, 0.32, 0.18),
		"eye_color": Color(0.90, 0.75, 0.10), "size": 0.85, "faction": "hostile",
		"call": "Teeth That Wait", "pack": true,
	},
	"lion": {
		"body_color": Color(0.82, 0.70, 0.38), "mane_color": Color(0.42, 0.28, 0.08),
		"eye_color": Color(0.90, 0.70, 0.10), "size": 1.15, "faction": "hostile",
		"call": "The Weight of the Open Ground", "pack": false,
	},
	"wild_dog": {
		"body_color": Color(0.58, 0.50, 0.28), "spot_color": Color(0.22, 0.18, 0.08),
		"eye_color": Color(0.70, 0.88, 0.30), "size": 0.70, "faction": "hostile",
		"call": "Runs in the Shape of Others", "pack": true,
	},
	"vulture": {
		"body_color": Color(0.28, 0.25, 0.22), "wing_color": Color(0.18, 0.15, 0.12),
		"eye_color": Color(0.85, 0.20, 0.10), "size": 0.65, "faction": "neutral",
		"call": "Patient as the Ground", "pack": true,
	},
	"steppe_wolf": {
		"body_color": Color(0.68, 0.65, 0.60), "spot_color": Color(0.38, 0.35, 0.30),
		"eye_color": Color(0.75, 0.85, 0.95), "size": 0.90, "faction": "hostile",
		"call": "Cold Track", "pack": true,
	},
	"plains_boar": {
		"body_color": Color(0.45, 0.38, 0.28), "spot_color": Color(0.28, 0.22, 0.14),
		"eye_color": Color(0.62, 0.30, 0.08), "size": 0.85, "faction": "neutral",
		"call": "Rooted in the Ground It Defends", "pack": false,
	},
	"forest_cat": {
		"body_color": Color(0.58, 0.50, 0.30), "spot_color": Color(0.28, 0.22, 0.10),
		"eye_color": Color(0.30, 0.88, 0.30), "size": 0.72, "faction": "neutral",
		"call": "Seen Before It Is Heard", "pack": false,
	},
	"marsh_croc": {
		"body_color": Color(0.25, 0.38, 0.22), "belly_color": Color(0.55, 0.60, 0.38),
		"eye_color": Color(0.90, 0.75, 0.05), "size": 1.10, "faction": "hostile",
		"call": "Still Water", "pack": false,
	},
}

func _ready() -> void:
	_spawn_region_creatures()

func _spawn_region_creatures() -> void:
	var region_creatures: Array = GameData.get_region_creatures()
	var spawn: Vector2 = GameData.get_spawn_position()
	var map_w: int = 40
	var map_h: int = 40
	var count: int = 8 + randi_range(0, 6)

	for i in range(count):
		var attempts := 0
		while attempts < 60:
			attempts += 1
			var x := randi_range(2, map_w - 3)
			var y := randi_range(2, map_h - 3)
			var gp := Vector2(x, y)
			if gp.distance_to(spawn) < 6.0: continue
			
			var ctype: String = region_creatures[randi() % region_creatures.size()] as String
			var def: Dictionary = CREATURE_TYPES.get(ctype, CREATURE_TYPES["hyena"])
			
			creatures.append({
				"type": ctype, "pos": gp, "phase": randf() * TAU,
				"faction": def["faction"], "move_timer": randf_range(1.5, 4.0),
				"move_dir": Vector2.ZERO, "call": def["call"],
				"size": def.get("size", 1.0), "anim_frame": 0, "visible_to_player": false,
			})
			break

func _process(delta: float) -> void:
	_time += delta
	_update_creature_movement(delta)
	queue_redraw()

func _update_creature_movement(delta: float) -> void:
	for c in creatures:
		if c["faction"] == "neutral":
			c["move_timer"] -= delta
			if c["move_timer"] <= 0:
				c["move_timer"] = randf_range(2.0, 5.0)
				var dirs := [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1), Vector2.ZERO]
				c["move_dir"] = dirs[randi() % dirs.size()]
				var np: Vector2 = c["pos"] + c["move_dir"]
				np.x = clamp(np.x, 1, 38)
				np.y = clamp(np.y, 1, 38)
				c["pos"] = np

func update_visibility(player_grid: Vector2) -> void:
	for c in creatures:
		c["visible_to_player"] = player_grid.distance_to(c["pos"]) <= 8.0
	queue_redraw()

func get_creature_at(grid_pos: Vector2) -> Dictionary:
	for c in creatures:
		if c["pos"].distance_to(grid_pos) < 1.5: return c
	return {}

func remove_creature_at(grid_pos: Vector2) -> void:
	for i in range(creatures.size() - 1, -1, -1):
		if creatures[i]["pos"].distance_to(grid_pos) < 1.5:
			creatures.remove_at(i)
			return

func _draw() -> void:
	var brightness: float = GameData.get_ambient_brightness()
	for c in creatures:
		if not c["visible_to_player"]: continue
		_draw_creature(c, brightness)

func _draw_creature(c: Dictionary, brightness: float) -> void:
	var wp: Vector2 = c["pos"] * TILE_SIZE
	var ctype: String = c["type"]
	var def: Dictionary = CREATURE_TYPES.get(ctype, CREATURE_TYPES["hyena"])
	var scl: float = c["size"]
	var phase: float = c["phase"] + _time
	var cx: float = wp.x + TILE_SIZE * 0.5
	var cy: float = wp.y + TILE_SIZE * 0.5

	_draw_ellipse_shape(Vector2(cx + 3, cy + 4), Vector2(10 * scl, 5 * scl), Color(0,0,0,0.30))

	match ctype:
		"hyena", "wild_dog", "steppe_wolf":
			_draw_canine(cx, cy, def, scl, phase, brightness, ctype == "wild_dog")
		"lion":
			_draw_lion(cx, cy, def, scl, phase, brightness)
		"vulture":
			_draw_vulture(cx, cy, def, scl, phase, brightness)
		"plains_boar", "forest_cat":
			_draw_generic_quad(cx, cy, def, scl, phase, brightness)
		"marsh_croc":
			_draw_croc(cx, cy, def, scl, phase, brightness)
		_:
			_draw_generic_quad(cx, cy, def, scl, phase, brightness)

	if c["faction"] == "hostile":
		_draw_ellipse_shape(Vector2(cx, cy - 12 * scl), Vector2(3, 3), Color(0.9, 0.15, 0.15, 0.8))
	elif c["faction"] == "neutral":
		_draw_ellipse_shape(Vector2(cx, cy - 12 * scl), Vector2(3, 3), Color(0.6, 0.8, 0.3, 0.6))

func _draw_canine(cx: float, cy: float, def: Dictionary, scl: float, phase: float, b: float, is_small: bool) -> void:
	var walk := sin(phase * 3.0) * 1.5
	var bc: Color = def["body_color"] * b
	var sc: Color = def.get("spot_color", Color(0.3,0.3,0.1)) * b
	var ec: Color = def["eye_color"]
	var s := scl * (0.80 if is_small else 1.0)

	_draw_ellipse_shape(Vector2(cx, cy + walk), Vector2(9*s, 6*s), bc)
	_draw_ellipse_shape(Vector2(cx + 8*s, cy - 1 + walk), Vector2(5*s, 4*s), bc)
	_draw_ellipse_shape(Vector2(cx + 12*s, cy - 0.5 + walk), Vector2(3*s, 2*s), sc)
	_draw_triangle(Vector2(cx + 7*s, cy - 4*s + walk), Vector2(cx + 5*s, cy - 8*s + walk), Vector2(cx + 9*s, cy - 7*s + walk), bc * Color(0.85,0.85,0.85,1))
	_draw_triangle(Vector2(cx + 9*s, cy - 4*s + walk), Vector2(cx + 7*s, cy - 8*s + walk), Vector2(cx + 11*s, cy - 7*s + walk), bc * Color(0.85,0.85,0.85,1))
	_draw_ellipse_shape(Vector2(cx + 10*s, cy - 2 + walk), Vector2(1.5*s, 1.5*s), ec)
	
	var l1 := sin(phase * 4.0) * 3
	var l2 := sin(phase * 4.0 + PI) * 3
	draw_line(Vector2(cx - 4*s, cy + 4*s + walk), Vector2(cx - 4*s, cy + 9*s + l1 + walk), bc, 2.0)
	draw_line(Vector2(cx, cy + 4*s + walk), Vector2(cx, cy + 9*s + l2 + walk), bc, 2.0)
	draw_line(Vector2(cx + 4*s, cy + 4*s + walk), Vector2(cx + 4*s, cy + 9*s + l1 + walk), bc, 2.0)
	draw_line(Vector2(cx + 7*s, cy + 3*s + walk), Vector2(cx + 7*s, cy + 8*s + l2 + walk), bc, 2.0)
	
	var tail_wag := sin(phase * 2.5) * 4
	draw_line(Vector2(cx - 7*s, cy + walk), Vector2(cx - 12*s, cy - 4*s + tail_wag + walk), bc, 1.5)
	
	if def.has("spot_color"):
		for i in range(3):
			var sx := cx - 2 + i * 4
			_draw_ellipse_shape(Vector2(sx * s + (cx * (1-s)), cy + 1 + walk), Vector2(1.5*s, 1.5*s), sc)

func _draw_lion(cx: float, cy: float, def: Dictionary, scl: float, phase: float, b: float) -> void:
	var walk := sin(phase * 2.0) * 1.2
	var bc: Color = def["body_color"] * b
	var mc: Color = def["mane_color"] * b
	var ec: Color = def["eye_color"]
	var s := scl

	_draw_ellipse_shape(Vector2(cx, cy + walk), Vector2(13*s, 8*s), bc)
	_draw_ellipse_shape(Vector2(cx + 9*s, cy - 2 + walk), Vector2(8*s, 7*s), mc)
	_draw_ellipse_shape(Vector2(cx + 9*s, cy - 1 + walk), Vector2(6*s, 5*s), bc)
	_draw_ellipse_shape(Vector2(cx + 14*s, cy + 0.5 + walk), Vector2(2*s, 1.5*s), mc)
	_draw_ellipse_shape(Vector2(cx + 11*s, cy - 2 + walk), Vector2(1.8*s, 1.8*s), ec)
	
	var l1 := sin(phase * 3.5) * 2.5
	var l2 := sin(phase * 3.5 + PI) * 2.5
	draw_line(Vector2(cx - 5*s, cy + 6*s + walk), Vector2(cx - 5*s, cy + 12*s + l1 + walk), bc, 2.5)
	draw_line(Vector2(cx, cy + 6*s + walk), Vector2(cx, cy + 12*s + l2 + walk), bc, 2.5)
	draw_line(Vector2(cx + 5*s, cy + 5*s + walk), Vector2(cx + 5*s, cy + 11*s + l1 + walk), bc, 2.5)
	draw_line(Vector2(cx + 9*s, cy + 4*s + walk), Vector2(cx + 9*s, cy + 10*s + l2 + walk), bc, 2.5)
	
	var tail_wag := sin(phase * 2.0) * 5
	draw_line(Vector2(cx - 11*s, cy + walk), Vector2(cx - 17*s, cy - 6*s + tail_wag + walk), bc, 2.0)
	_draw_ellipse_shape(Vector2(cx - 17*s, cy - 7*s + tail_wag + walk), Vector2(2.5*s, 2.5*s), mc)

func _draw_vulture(cx: float, cy: float, def: Dictionary, scl: float, phase: float, b: float) -> void:
	var bc: Color = def["body_color"] * b
	var wc: Color = def.get("wing_color", Color(0.15,0.12,0.10)) * b
	var ec: Color = def["eye_color"]
	var s := scl
	var circle_r := 6.0
	var ox := sin(phase * 0.8) * circle_r
	var oy := cos(phase * 0.8) * circle_r * 0.4
	var wcx := cx + ox
	var wcy := cy + oy
	var wing_flap := sin(phase * 2.5) * 3
	
	_draw_triangle(Vector2(wcx, wcy), Vector2(wcx - 12*s, wcy - 5*s + wing_flap), Vector2(wcx - 8*s, wcy + 3*s), wc)
	_draw_triangle(Vector2(wcx, wcy), Vector2(wcx + 12*s, wcy - 5*s + wing_flap), Vector2(wcx + 8*s, wcy + 3*s), wc)
	_draw_ellipse_shape(Vector2(wcx, wcy), Vector2(4*s, 3*s), bc)
	_draw_ellipse_shape(Vector2(wcx + 3*s, wcy - 3*s), Vector2(2*s, 3*s), Color(0.75, 0.55, 0.40) * b)
	_draw_ellipse_shape(Vector2(wcx + 4*s, wcy - 5*s), Vector2(2.5*s, 2*s), Color(0.75, 0.55, 0.40) * b)
	draw_line(Vector2(wcx + 6*s, wcy - 5*s), Vector2(wcx + 9*s, wcy - 6*s), Color(0.60, 0.48, 0.08) * b, 1.5)
	_draw_ellipse_shape(Vector2(wcx + 5.5*s, wcy - 5.5*s), Vector2(1.2*s, 1.2*s), ec)

func _draw_generic_quad(cx: float, cy: float, def: Dictionary, scl: float, phase: float, b: float) -> void:
	var walk := sin(phase * 3.5) * 1.2
	var bc: Color = def["body_color"] * b
	var sc: Color = def.get("spot_color", def["body_color"] * Color(0.7,0.7,0.7,1)) * b
	var ec: Color = def["eye_color"]
	var s := scl
	
	_draw_ellipse_shape(Vector2(cx, cy + walk), Vector2(8*s, 5.5*s), bc)
	_draw_ellipse_shape(Vector2(cx + 7*s, cy - 0.5 + walk), Vector2(4.5*s, 3.5*s), bc)
	_draw_ellipse_shape(Vector2(cx + 11*s, cy + 0.5 + walk), Vector2(2.5*s, 1.5*s), sc)
	_draw_ellipse_shape(Vector2(cx + 9.5*s, cy - 2 + walk), Vector2(1.5*s, 1.5*s), ec)
	
	var l1 := sin(phase * 4.5) * 2.5
	var l2 := sin(phase * 4.5 + PI) * 2.5
	draw_line(Vector2(cx - 3*s, cy + 4*s + walk), Vector2(cx - 3*s, cy + 8*s + l1 + walk), bc, 1.8)
	draw_line(Vector2(cx + 2*s, cy + 4*s + walk), Vector2(cx + 2*s, cy + 8*s + l2 + walk), bc, 1.8)
	draw_line(Vector2(cx + 5*s, cy + 3.5*s + walk), Vector2(cx + 5*s, cy + 7.5*s + l1 + walk), bc, 1.8)
	draw_line(Vector2(cx + 9*s, cy + 3*s + walk), Vector2(cx + 9*s, cy + 7*s + l2 + walk), bc, 1.8)

# FIX: Corrected parameters (removed leading underscores so they are used)
func _draw_croc(cx: float, cy: float, def: Dictionary, scl: float, phase: float, b: float) -> void:
	var tail_wave := sin(phase * 1.5) * 3.0
	var bc: Color = def["body_color"] * b
	var belly: Color = def.get("belly_color", Color(0.55,0.60,0.38)) * b
	var ec: Color = def["eye_color"]
	var s := scl
	
	_draw_ellipse_shape(Vector2(cx, cy), Vector2(14*s, 6*s), bc)
	_draw_ellipse_shape(Vector2(cx, cy + 1), Vector2(12*s, 3*s), belly)
	
	draw_line(Vector2(cx - 12*s, cy), Vector2(cx - 18*s, cy + tail_wave), bc, 4.0*s)
	draw_line(Vector2(cx - 18*s, cy + tail_wave), Vector2(cx - 22*s, cy + tail_wave * 1.5), bc, 2.5*s)
	
	_draw_ellipse_shape(Vector2(cx + 12*s, cy - 1), Vector2(6*s, 3.5*s), bc)
	draw_rect(Rect2(cx + 16*s, cy - 1.5, 8*s, 3*s), bc)
	
	for i in range(4):
		draw_rect(Rect2(cx + 17*s + i*2*s, cy - 2.5, s, 2*s), Color(0.95, 0.92, 0.80) * b)
	
	_draw_ellipse_shape(Vector2(cx + 14*s, cy - 3), Vector2(1.8*s, 1.8*s), ec)
	
	draw_line(Vector2(cx - 4*s, cy + 5), Vector2(cx - 4*s + 3, cy + 9), bc, 3.0*s)
	draw_line(Vector2(cx + 4*s, cy + 5), Vector2(cx + 4*s + 3, cy + 9), bc, 3.0*s)
	draw_line(Vector2(cx - 8*s, cy + 4), Vector2(cx - 8*s - 3, cy + 8), bc, 3.0*s)
	draw_line(Vector2(cx + 8*s, cy + 4), Vector2(cx + 8*s - 3, cy + 8), bc, 3.0*s)
	
	for i in range(5):
		_draw_ellipse_shape(Vector2(cx - 8*s + i * 4*s, cy - 5), Vector2(2*s, 1.5*s), bc * Color(0.7,0.7,0.7,1))

func _draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color, segments: int = 16) -> void:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := i * TAU / segments
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _draw_triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c]), color)
