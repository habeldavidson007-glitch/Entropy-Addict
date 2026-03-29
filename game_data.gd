extends Node
class_name GameDataManager

signal party_updated
signal quest_completed(quest_id: String)
signal level_up(new_level: int)

var player_name: String    = "Traveler"
var player_color: Color    = Color(0.2, 0.8, 0.4)
var player_emoticon: String = "◈"
var starting_region: String = "Ashveld Flats"
var first_habit: String    = ""
var first_habit_name: String = ""
var groq_api_key: String   = "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"

var player_hp: int      = 100
var player_max_hp: int  = 100
var player_level: int   = 1
var player_xp: int      = 0
var enemies_defeated: int = 0
var tiles_explored: int   = 0
var terrain_familiarity: float = 0.0

var attr_str: int    = 5
var attr_int: int    = 5
var attr_dex: int    = 5
var attr_luck: int   = 5
var attr_points: int = 0

var primary_mastery: String   = ""
var secondary_mastery: String = ""
var field_role: String        = ""

var habit_log: Dictionary = {}
var codex_active: Array[String] = ["","",""]
var codex_passive: Array[String] = ["","",""]
var subdued_enemies: Array[Dictionary] = []

var call_title: String = "Silent Call"
var call_tier: int     = 0

var party_stage: String = "lone"
var party_members: Array[Dictionary] = []

var explored_tiles: Dictionary = {}

var active_quests: Array    = []
var completed_quests: Array = []

var world_time: float = 0.30
var time_speed: float = 0.00050
var days_survived: int = 1

var encounter_enemy: Dictionary = {}

var regions: Dictionary = {
	"Ashveld Flats": {
		"description": "The ungovernable interior.",
		"plus": "Maximum freedom.",
		"minus": "No allies.",
		"spawn": Vector2i(20, 20), "tile_bias": "mixed",
		"creatures": ["hyena","lion","wild_dog","vulture"]
	},
	"North — Steppe Shelf": {
		"description": "High plateau. Cold winds.",
		"plus": "Fractured Ironwind access.",
		"minus": "Cold punishes slow builds.",
		"spawn": Vector2i(20, 3), "tile_bias": "stone",
		"creatures": ["steppe_wolf","hawk","snow_leopard"]
	},
	"South — Sunfall Plains": {
		"description": "Fertile. Rich.",
		"plus": "Food surplus.",
		"minus": "Flat terrain.",
		"spawn": Vector2i(20, 37), "tile_bias": "grass",
		"creatures": ["plains_boar","grazing_deer","fox"]
	},
	"West — Iron Pass": {
		"description": "Mountain range.",
		"plus": "Best equipment.",
		"minus": "Food dependency.",
		"spawn": Vector2i(3, 20), "tile_bias": "rocky",
		"creatures": ["mountain_goat","cave_bear","eagle"]
	},
	"East — Deep Forest": {
		"description": "The Pale Witness lives here.",
		"plus": "Unmatched information.",
		"minus": "Complete isolation.",
		"spawn": Vector2i(37, 20), "tile_bias": "forest",
		"creatures": ["forest_cat","wild_boar","owl"]
	},
	"Northeast — Coastal Shelf": {
		"description": "Tidecallers see what arrives first.",
		"plus": "Rare goods.",
		"minus": "Challengers further along.",
		"spawn": Vector2i(37, 3), "tile_bias": "coastal",
		"creatures": ["sea_bird","coastal_wolf","crab_spawn"]
	},
	"Northwest — High Barrens": {
		"description": "Exposed highland.",
		"plus": "Best fighters.",
		"minus": "Almost no goods.",
		"spawn": Vector2i(3, 3), "tile_bias": "barren",
		"creatures": ["barren_wolf","carrion_bird","sand_snake"]
	},
	"Southwest — Salt Marsh": {
		"description": "Brine Walkers hold salt.",
		"plus": "Universal trade leverage.",
		"minus": "Seasonal flooding.",
		"spawn": Vector2i(3, 37), "tile_bias": "marsh",
		"creatures": ["marsh_croc","water_snake","ibis"]
	}
}

func get_spawn_position() -> Vector2i:
	if starting_region in regions:
		var spawn_data = regions[starting_region]["spawn"]
		if spawn_data is Vector2i:
			return spawn_data
		return Vector2i(spawn_data)
	return Vector2i(20, 20)

func get_tile_bias() -> String:
	return regions.get(starting_region, {}).get("tile_bias", "mixed")

func get_region_creatures() -> Array:
	return regions.get(starting_region, {}).get("creatures", ["hyena"])

func mark_explored(grid_pos: Vector2) -> void:
	var key := Vector2i(grid_pos)
	if key in explored_tiles:
		return
	explored_tiles[key] = true
	tiles_explored += 1
	var new_familiarity := float(tiles_explored) / 16.0
	if new_familiarity - terrain_familiarity >= 0.1:
		terrain_familiarity = new_familiarity
		_check_quests()

func get_dodge_bonus() -> float:
	return terrain_familiarity * 0.01 + attr_dex * 0.005

func get_flee_chance() -> float:
	return 0.40 + get_dodge_bonus() + attr_luck * 0.005

func spend_attr_point(attr: String) -> bool:
	if attr_points <= 0:
		return false
	match attr:
		"str":  attr_str  += 1
		"int":  attr_int  += 1
		"dex":  attr_dex  += 1
		"luck": attr_luck += 1
		_: return false
	attr_points -= 1
	return true

func get_damage_bonus() -> int:
	return int(attr_str * 0.8)

func get_persuade_bonus() -> float:
	return attr_int * 0.02

func add_xp(amount: int) -> void:
	player_xp += amount
	var needed := player_level * 120
	if player_xp >= needed:
		player_xp -= needed
		player_level += 1
		player_max_hp += 12
		player_hp = player_max_hp
		attr_points += 2
		# FIX: Integer division warning resolved by explicit int() cast if needed, 
		# but min() handles float/int mix fine. Keeping logic clean.
		call_tier = min(int(player_level / 5), 3)
		emit_signal("level_up", player_level)
		_check_quests()

func add_habit(habit_name: String) -> void:
	habit_log[habit_name] = habit_log.get(habit_name, 0) + 1
	_try_crystallise_skill(habit_name)

func get_habit_stage(habit_name: String) -> String:
	var c: int = habit_log.get(habit_name, 0)
	if c >= 20: return "Skill"
	elif c >= 10: return "Custom"
	elif c >= 5:  return "Routine"
	elif c >= 1:  return "Habit"
	return ""

func _try_crystallise_skill(habit_name: String) -> void:
	var stage := get_habit_stage(habit_name)
	if stage != "Skill":
		return
	for i in range(3):
		if codex_active[i] == "" or codex_active[i] == habit_name:
			codex_active[i] = habit_name
			return
	for i in range(3):
		if codex_passive[i] == "" or codex_passive[i] == habit_name:
			codex_passive[i] = habit_name
			return

func recruit_member(member: Dictionary) -> void:
	party_members.append(member)
	enemies_defeated += 1
	_check_party_stage()
	_check_quests()
	emit_signal("party_updated")

func _check_party_stage() -> void:
	if party_stage == "lone" and party_members.size() >= 2:
		party_stage = "nomad_party"
		_add_quest("grow_party", "Recruit More — Build Your Formation",
			"You are no longer alone.", {"members_needed": 5})
		emit_signal("party_updated")

func get_party_turn_order() -> Array:
	var order := party_members.duplicate()
	order.sort_custom(func(a, b): return a.get("level", 1) > b.get("level", 1))
	return order

func get_formation_status() -> Dictionary:
	var roles := {"breaker": false, "striker": false, "anchor": false, "auxiliary_count": 0}
	for m in party_members:
		match m.get("role", ""):
			"breaker": roles["breaker"] = true
			"striker": roles["striker"] = true
			"anchor":  roles["anchor"]  = true
			"auxiliary": roles["auxiliary_count"] += 1
	return roles

func _add_quest(id: String, title: String, desc: String, req: Dictionary) -> void:
	for q in active_quests:
		if q["id"] == id:
			return
	active_quests.append({"id": id, "title": title, "desc": desc, "req": req, "progress": {}})

func _check_quests() -> void:
	for q in active_quests.duplicate():
		if _quest_complete(q):
			active_quests.erase(q)
			completed_quests.append(q)
			emit_signal("quest_completed", q["id"])

func _quest_complete(q: Dictionary) -> bool:
	match q["id"]:
		"grow_party":
			return party_members.size() >= q["req"].get("members_needed", 5)
		"explore_10pct":
			return terrain_familiarity >= 10.0
		_:
			return false

func trigger_formation_quest() -> void:
	_add_quest("grow_party", "Build Your Party", "You have taken your first recruit.", {"members_needed": 5})

func trigger_explore_quest() -> void:
	_add_quest("explore_10pct", "Map the Flats", "Explore 10% of your starting region.", {})

func advance_time(delta: float) -> void:
	var prev := world_time
	world_time = fmod(world_time + delta * time_speed, 1.0)
	if prev > 0.22 and world_time <= 0.22:
		days_survived += 1

func get_time_label() -> String:
	var t := world_time
	if t < 0.08 or t > 0.92:  return "Night"
	elif t < 0.22: return "Late Night"
	elif t < 0.30: return "Dawn"
	elif t < 0.48: return "Morning"
	elif t < 0.55: return "Noon"
	elif t < 0.68: return "Afternoon"
	elif t < 0.80: return "Dusk"
	return "Evening"

func get_sky_color() -> Color:
	var t := world_time
	var night := Color(0.03, 0.03, 0.08)
	var dawn  := Color(0.50, 0.25, 0.12)
	var day   := Color(0.90, 0.88, 0.80)
	var dusk  := Color(0.42, 0.18, 0.22)
	if t < 0.25:   return night.lerp(dawn,  t / 0.25)
	elif t < 0.40: return dawn.lerp(day,   (t-0.25)/0.15)
	elif t < 0.60: return day
	elif t < 0.75: return day.lerp(dusk,   (t-0.60)/0.15)
	else:          return dusk.lerp(night, (t-0.75)/0.25)

func get_ambient_brightness() -> float:
	var t := world_time
	if t < 0.25:   return lerp(0.14, 0.38, t/0.25)
	elif t < 0.40: return lerp(0.38, 1.00, (t-0.25)/0.15)
	elif t < 0.60: return 1.00
	elif t < 0.75: return lerp(1.00, 0.38, (t-0.60)/0.15)
	else:          return lerp(0.38, 0.14, (t-0.75)/0.25)

func is_night() -> bool:
	return world_time < 0.22 or world_time > 0.82

func recalculate_derived_stats() -> void:
	# FIX: Line 173 - Explicit int cast for integer division
	var calculated_max_hp := int(100 + (attr_str * 5) + ((player_level - 1) * 10))
	if calculated_max_hp != player_max_hp:
		var hp_ratio := float(player_hp) / float(player_max_hp) if player_max_hp > 0 else 1.0
		player_max_hp = calculated_max_hp
		player_hp = int(player_max_hp * hp_ratio)

func get_all_derived_stats() -> Dictionary:
	return {
		"max_hp": player_max_hp,
		"base_damage": get_damage_bonus(),
		"base_defense": int(attr_dex * 0.5),
		"initiative": int(attr_dex * 1.5),
		"evasion_chance": min(0.75, attr_dex * 0.008),
		"crit_chance": min(0.5, attr_luck * 0.005),
		"subdue_chance": attr_luck * 0.012
	}

func add_to_codex(enemy_name: String, enemy_call: String, enemy_stats: Dictionary, lore_text: String = "") -> void:
	var existing_index := -1
	for i in range(subdued_enemies.size()):
		if subdued_enemies[i]["name"] == enemy_name:
			existing_index = i
			break
	
	if existing_index >= 0:
		subdued_enemies[existing_index]["count"] = subdued_enemies[existing_index].get("count", 1) + 1
	else:
		var new_entry := {
			"name": enemy_name,
			"call": enemy_call,
			"stats": enemy_stats,
			"lore": lore_text,
			"count": 1,
			"first_subdued_day": days_survived
		}
		subdued_enemies.append(new_entry)

func get_subdued_enemies() -> Array:
	return subdued_enemies

func save_game() -> Error:
	var save_data: Dictionary = {
		"version": 1,
		"player": {
			"name": player_name,
			"level": player_level,
			"xp": player_xp,
			"stats": {"str": attr_str, "int": attr_int, "dex": attr_dex, "luck": attr_luck},
			"hp": player_hp,
			"max_hp": player_max_hp
		},
		"world": {
			"days": days_survived,
			"time": world_time,
			"explored": explored_tiles
		},
		"party": party_members,
		"codex": subdued_enemies
	}
	
	var file := FileAccess.open("user://savegame.save", FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing")
		return FileAccess.get_open_error()
	
	file.store_var(save_data)
	file.close()
	print("Game Saved successfully.")
	return OK

func load_game() -> Error:
	if not FileAccess.file_exists("user://savegame.save"):
		return ERR_FILE_NOT_FOUND
	
	var file := FileAccess.open("user://savegame.save", FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	
	# FIX: Line 274 - Corrected syntax from "var save_ Dictionary" to valid declaration
	var save_data: Dictionary = file.get_var() as Dictionary
	file.close()
	
	if save_data.has("player"):
		var p: Dictionary = save_data["player"]
		player_name = p.get("name", player_name)
		player_level = p.get("level", 1)
		player_xp = p.get("xp", 0)
		var stats: Dictionary = p.get("stats", {})
		attr_str = stats.get("str", 5)
		attr_int = stats.get("int", 5)
		attr_dex = stats.get("dex", 5)
		attr_luck = stats.get("luck", 5)
		player_hp = p.get("hp", 100)
		player_max_hp = p.get("max_hp", 100)
	
	if save_data.has("world"):
		var w: Dictionary = save_data["world"]
		days_survived = w.get("days", 1)
		world_time = w.get("time", 0.0)
		var explored_raw = w.get("explored", [])
		explored_tiles.clear()
		for pos in explored_raw:
			if pos is Vector2i:
				explored_tiles[pos] = true
			elif pos is Vector2:
				explored_tiles[Vector2i(pos)] = true
	
	if save_data.has("party"):
		party_members = save_data["party"]
	
	if save_data.has("codex"):
		subdued_enemies = save_data["codex"]
	
	recalculate_derived_stats()
	print("Game Loaded successfully.")
	return OK
