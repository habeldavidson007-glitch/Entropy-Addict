extends Node

signal quest_completed(quest_id: String)

# ─────────────────────────────────────────
# PLAYER IDENTITY
# ─────────────────────────────────────────
var player_name: String = ""
var player_color: Color = Color(0.2, 0.8, 0.4)
var player_emoticon: String = "◈"
var starting_region: String = ""
var first_habit: String = ""

# ─────────────────────────────────────────
# GROQ API KEY
# ─────────────────────────────────────────
var groq_api_key: String = "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"
var groq_model: String = "llama-3.1-8b-instant"

# ─────────────────────────────────────────
# LEVEL & XP SYSTEM
# ─────────────────────────────────────────
var player_level: int = 1
var player_xp: int = 0
var xp_to_next_level: int = 150
var stat_points: int = 0

# ─────────────────────────────────────────
# ATTRIBUTES
# ─────────────────────────────────────────
var stats: Dictionary = {
	"physic": 5,
	"dexterity": 5,
	"intellect": 5,
	"luck": 5
}

const BASE_STAT_VALUE: int = 5
const STAT_POINTS_PER_LEVEL: int = 3
const XP_SCALING_FACTOR: float = 1.8

const STAT_POINT_DESCRIPTIONS: Dictionary = {
	"physic":    "HP +10, Damage +2, Defense +1 per point",
	"dexterity": "Initiative +5%, Evasion +3% per point",
	"intellect": "XP Gain +10%, Skill Power +5% per point",
	"luck":      "Crit +2%, Drop Rate +5%, Flee +3% per point"
}

# ─────────────────────────────────────────
# EXPLORATION SYSTEM
# ─────────────────────────────────────────
var total_map_tiles: int = 0
var explored_tiles_count: int = 0
var exploration_percentage: float = 0.0
var familiar_environment_bonus: int = 0
var last_milestone: int = 0
const EXPLORATION_XP_BASE: int = 1

# ─────────────────────────────────────────
# PARTY SYSTEM — NEW
# ─────────────────────────────────────────
var party_members: Array = []  # [{name, call, type, hp, max_hp, joined_date, battles_participated}]

func add_party_member(name: String, call: String, enemy_type: String, max_hp: int) -> void:
	party_members.append({
		"name": name,
		"call": call,
		"type": enemy_type,
		"hp": max_hp,
		"max_hp": max_hp,
		"joined_date": Time.get_unix_time_from_system(),
		"battles_participated": 0
	})
	print("[GameData] %s joined the party! Total members: %d" % [name, party_members.size()])
	_check_recruit_quest()

func get_party_members() -> Array:
	return party_members

func get_party_size() -> int:
	return party_members.size()

func remove_party_member(index: int) -> bool:
	if index >= 0 and index < party_members.size():
		party_members.remove_at(index)
		return true
	return false

func clear_party() -> void:
	party_members.clear()

# ─────────────────────────────────────────
# QUEST SYSTEM — NEW
# ─────────────────────────────────────────
var quests: Dictionary = {}

func init_quests() -> void:
	if not quests.has("recruit_nomad"):
		quests["recruit_nomad"] = {
			"title": "Nomad Party Recognition",
			"description": "Recruit more party members to be recognized as Nomad Party",
			"requirement": 3,
			"current": get_party_size(),
			"completed": false,
			"reward_xp": 200,
			"reward_title": "Nomad Leader"
		}

func _check_recruit_quest() -> void:
	if quests.has("recruit_nomad") and not quests["recruit_nomad"].completed:
		quests["recruit_nomad"].current = get_party_size()
		if get_party_size() >= quests["recruit_nomad"].requirement:
			_complete_quest("recruit_nomad")

func _complete_quest(quest_id: String) -> void:
	if quests.has(quest_id):
		quests[quest_id].completed = true
		var quest = quests[quest_id]
		print("[GameData] QUEST COMPLETE: %s" % quest.title)
		print("[GameData] Reward: %d XP, Title: %s" % [quest.reward_xp, quest.reward_title])
		add_xp(quest.reward_xp)
		emit_signal("quest_completed", quest_id)

func get_active_quests() -> Array:
	var active = []
	for id in quests:
		if not quests[id].completed:
			active.append(quests[id])
	return active

func get_completed_quests() -> Array:
	var completed = []
	for id in quests:
		if quests[id].completed:
			completed.append(quests[id])
	return completed

# ─────────────────────────────────────────
# ALPHA / SUBDUE SYSTEM
# ─────────────────────────────────────────
var subdued_enemies: Array = []
var alpha_recruits: Array = []
var generated_enemy_names: Dictionary = {}

const SUBDUE_MIN_HP: float = 0.10
const SUBDUE_MAX_HP: float = 0.30
const SUBDUE_BASE_CHANCE: float = 0.25
const SUBDUE_LUCK_BONUS: float = 0.03

# ─────────────────────────────────────────
# DERIVED STATS
# ─────────────────────────────────────────
func get_max_hp() -> int:
	return 80 + ((stats["physic"] - BASE_STAT_VALUE) * 10)

func get_base_damage() -> int:
	return 8 + ((stats["physic"] - BASE_STAT_VALUE) * 2)

func get_base_defense() -> int:
	return 2 + ((stats["physic"] - BASE_STAT_VALUE) * 1)

func get_initiative_bonus() -> float:
	return 0.0 + ((stats["dexterity"] - BASE_STAT_VALUE) * 0.05)

func get_evasion_chance() -> float:
	return 0.05 + ((stats["dexterity"] - BASE_STAT_VALUE) * 0.03)

func get_xp_bonus() -> float:
	return 0.0 + ((stats["intellect"] - BASE_STAT_VALUE) * 0.10)

func get_crit_chance() -> float:
	return 0.05 + ((stats["luck"] - BASE_STAT_VALUE) * 0.02)

func get_drop_bonus() -> float:
	return 0.0 + ((stats["luck"] - BASE_STAT_VALUE) * 0.05)

func get_flee_bonus() -> float:
	return 0.0 + ((stats["luck"] - BASE_STAT_VALUE) * 0.03)

func get_subdue_chance() -> float:
	var luck_bonus = max(0, stats["luck"] - BASE_STAT_VALUE) * SUBDUE_LUCK_BONUS
	return SUBDUE_BASE_CHANCE + luck_bonus

# ─────────────────────────────────────────
# XP & LEVEL FUNCTIONS
# ─────────────────────────────────────────
func add_xp(amount: int) -> bool:
	var bonus = int(amount * get_xp_bonus())
	player_xp += amount + bonus
	if player_xp >= xp_to_next_level:
		level_up()
		return true
	return false

func level_up() -> void:
	player_level += 1
	player_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * XP_SCALING_FACTOR)
	stat_points += STAT_POINTS_PER_LEVEL
	print("★ Level Up! Now level %d | Stat Points: %d" % [player_level, stat_points])

func get_xp_progress() -> float:
	if xp_to_next_level == 0:
		return 1.0
	return clamp(float(player_xp) / float(xp_to_next_level), 0.0, 1.0)

func can_increase_stat(_stat_name: String) -> bool:
	return stat_points > 0

func increase_stat(stat_name: String) -> bool:
	if can_increase_stat(stat_name):
		stats[stat_name] += 1
		stat_points -= 1
		return true
	return false

func decrease_stat(stat_name: String) -> bool:
	if stats.get(stat_name, BASE_STAT_VALUE) > BASE_STAT_VALUE:
		stats[stat_name] -= 1
		stat_points += 1
		return true
	return false

# ─────────────────────────────────────────
# EXPLORATION FUNCTIONS
# ─────────────────────────────────────────
func add_explored_tile() -> void:
	if total_map_tiles == 0:
		return
	explored_tiles_count += 1
	calculate_exploration_percentage()
	add_xp(EXPLORATION_XP_BASE)

func calculate_exploration_percentage() -> void:
	if total_map_tiles == 0:
		exploration_percentage = 0.0
		return
	exploration_percentage = (float(explored_tiles_count) / float(total_map_tiles)) * 100.0
	check_exploration_milestones()

func check_exploration_milestones() -> void:
	var current_milestone = int(exploration_percentage / 10.0)
	if current_milestone > last_milestone and current_milestone <= 10:
		familiar_environment_bonus += 10
		last_milestone = current_milestone
		print("🌍 FAMILIAR ENVIRONMENT BONUS: +%d" % 10)

func get_exploration_display() -> String:
	return "%.1f%%" % exploration_percentage

func reset_exploration() -> void:
	explored_tiles_count = 0
	exploration_percentage = 0.0
	familiar_environment_bonus = 0
	last_milestone = 0

# ─────────────────────────────────────────
# CALL SYSTEM
# ─────────────────────────────────────────
func generate_call(enemy_type: String, enemy_hp_percent: float) -> String:
	if groq_api_key == "":
		return _get_fallback_call(enemy_type, enemy_hp_percent)

	var prompt = """You are a game system generating short, poetic character labels called "Calls".
Rules:
- Return ONLY the Call text, nothing else
- Format: "Short phrase, short phrase" (max 6 words total)
- Tone: dry, grounded, slightly melancholic
- Based on: {enemy_type} at {hp}% health
Examples:
- "Strong body, weak mind"
- "Eyes that miss nothing"
- "Hands that remember war"
- "Feet that know the road"
Generate one Call:""".format({
		"enemy_type": enemy_type,
		"hp": int(enemy_hp_percent * 100)
	})

	var url = "https://api.groq.com/openai/v1/chat/completions"
	var headers = [
		"Authorization: Bearer " + groq_api_key,
		"Content-Type: application/json"
	]
	var body = JSON.stringify({
		"model": groq_model,
		"messages": [{"role": "user", "content": prompt}],
		"temperature": 0.7,
		"max_tokens": 30
	})

	var http = HTTPRequest.new()
	add_child(http)
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	var result = await http.request_completed

	if result[1] == 200:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			var response = json.get_data()
			var generated_call = response.get("choices", [{}])[0].get("message", {}).get("content", "").strip_edges()
			generated_call = generated_call.trim_prefix('"').trim_suffix('"')
			http.queue_free()
			return generated_call if generated_call != "" else _get_fallback_call(enemy_type, enemy_hp_percent)

	http.queue_free()
	return _get_fallback_call(enemy_type, enemy_hp_percent)

func _get_fallback_call(_enemy_type: String, _hp_percent: float) -> String:
	var calls = [
		"Strong body, weak mind",
		"Hands that know the blade",
		"Feet that never rest",
		"Scars that tell no tales",
		"Strength without direction",
		"A will that bends, not breaks",
		"Eyes that watch the wind",
		"Silent steps, loud intent",
		"The quiet before the storm",
		"Watches more than speaks",
		"Born to wander, destined to fall",
		"Outlived three winters",
		"The road made them hard",
		"Survival is their only craft",
		"Trusts no one, needs everyone",
		"Remembers every loss",
		"Fights for something lost",
		"Carries a name they won't share",
		"Hides more than shows",
		"The past follows close",
		"Not who they appear"
	]
	return calls[randi() % calls.size()]

# ─────────────────────────────────────────
# ENEMY NAME GENERATION
# ─────────────────────────────────────────
func generate_enemy_real_name() -> String:
	var first_names = [
		"Ghiar", "Maren", "Voss", "Kael", "Ryn", "Tessa", "Durn", "Hals",
		"Varek", "Senne", "Renk", "Bran", "Essa", "Tom", "Ille", "Deva",
		"Jarger", "Maret", "Ossel", "Ferren", "Rogic", "Vorren", "Orren",
		"Halvec", "Ash", "Rel", "Dun", "Vas", "Mert", "Cur"
	]
	var last_names = [
		"of the Flats", "Ash-born", "the Wanderer", "the Broken",
		"the Silent", "the Watcher", "the Lost", "the Survivor",
		"of the Road", "the Exile", "the Remnant", "the Lone",
		"the Unnamed", "the Forgotten", "the Last", "the First"
	]
	var first = first_names[randi() % first_names.size()]
	var last = last_names[randi() % last_names.size()]
	if randf() < 0.3:
		return first
	return first + " " + last

func get_or_generate_enemy_name(pos: Vector2) -> String:
	if generated_enemy_names.has(pos):
		return generated_enemy_names[pos]
	var new_name = generate_enemy_real_name()
	generated_enemy_names[pos] = new_name
	return new_name

func clear_enemy_name(pos: Vector2) -> void:
	generated_enemy_names.erase(pos)

# ─────────────────────────────────────────
# SUBDUE SYSTEM
# ─────────────────────────────────────────
func can_subdue(enemy_hp_percent: float) -> bool:
	return enemy_hp_percent >= SUBDUE_MIN_HP and enemy_hp_percent <= SUBDUE_MAX_HP

func attempt_subdue(enemy_name: String, enemy_call: String, enemy_type: String) -> bool:
	var roll = randf()
	var chance = get_subdue_chance()
	if roll < chance:
		subdued_enemies.append({
			"name": enemy_name,
			"call": enemy_call,
			"type": enemy_type,
			"subdued_at_level": player_level,
			"potential_alpha": randf() < 0.3
		})
		print("✅ Subdued: %s — '%s'" % [enemy_name, enemy_call])
		return true
	else:
		print("❌ Subdue failed — enemy escapes")
		return false

func add_subdued_enemy(enemy_id: String, name: String, call: String, enemy_type: String) -> void:
	subdued_enemies.append({
		"id": enemy_id,
		"name": name,
		"call": call,
		"type": enemy_type,
		"subdued_at_level": player_level
	})
	print("[GameData] Subdued: %s" % name)

func get_subdued_enemies() -> Array:
	return subdued_enemies

func recruit_as_alpha(enemy_data: Dictionary) -> bool:
	if enemy_data.get("potential_alpha", false):
		alpha_recruits.append(enemy_data)
		subdued_enemies.erase(enemy_data)
		print("🎯 %s joins as Delegated Alpha" % enemy_data.get("name", "Unknown"))
		return true
	return false

# ─────────────────────────────────────────
# REGIONS
# ─────────────────────────────────────────
var regions: Dictionary = {
	"Ashveld Flats": {
		"description": "The ungovernable interior. Where exiles, survivors, and the desperate end up. No faction controls it. No faction ever has.",
		"plus": "Maximum freedom. No faction pressures you at start. Highest enemy variety — you build fast or die fast.",
		"minus": "No allies. No safety net. Every party you meet is a potential threat. Hardest start in the game.",
		"spawn": Vector2(20, 20)
	},
	"North — Steppe Shelf": {
		"description": "High plateau. Cold winds. The Ironwind Riders control the routes — and their succession conflict is fracturing them. The heir is dead. No one has filled the gap.",
		"plus": "Early Ironwind faction access. Strong Breaker recruits. Mounted movement advantage on open plateau.",
		"minus": "Three-way succession conflict means allies may collapse. Harsh terrain punishes slow builds.",
		"spawn": Vector2(20, 4)
	},
	"South — Sunfall Plains": {
		"description": "Fertile. Rich. The only working currency in the world. A leader who knows he is not enough. He sent an envoy to the Flats six months ago. The envoy has not returned.",
		"plus": "Food surplus from day one. Economic advantage through grain tokens. Easiest early survival.",
		"minus": "Completely flat — impossible to defend. No natural cover. Political complexity arrives early.",
		"spawn": Vector2(20, 36)
	},
	"West — Iron Pass": {
		"description": "Mountain range. The Iron Chorus makes everything the world needs. Their unity is a fiction they maintain because the alternative is worse. Halvec Ash-Rel has studied an unnamed metal vein for eleven years without touching it.",
		"plus": "Best equipment access in the game. Strong production chain. Halvec Ash-Rel is the key forge relationship.",
		"minus": "The Iron Chorus cannot feed itself. Food dependency is a structural vulnerability from day one.",
		"spawn": Vector2(3, 20)
	},
	"East — Deep Forest": {
		"description": "The Pale Witness lives here. They have recorded everything in this world since before the named regions existed. They already know you arrived.",
		"plus": "Unmatched information advantage. Unique lore access. No faction pressure at start.",
		"minus": "Completely isolated. Dense terrain blocks movement. No trade routes near your position.",
		"spawn": Vector2(37, 20)
	},
	"Northeast — Coastal Shelf": {
		"description": "The Tidecallers see what arrives before anyone else. Something landed on the northeastern coast four months ago. They have told nobody.",
		"plus": "First access to goods from beyond the known world. Best information broker network.",
		"minus": "Challengers are already building alternate routes. Your advantage has a shrinking window.",
		"spawn": Vector2(34, 4)
	},
	"Northwest — High Barrens": {
		"description": "Exposed highland. Extreme wind. Scarce water. The Ashborn endure here because no one else can. Something has been going wrong here for two seasons. They are not saying what.",
		"plus": "Best fighters for recruitment anywhere. Survival-tested people who have already been through the worst.",
		"minus": "Extreme isolation. Almost no goods. You inherit an unknown problem the Ashborn will not name.",
		"spawn": Vector2(4, 4)
	},
	"Southwest — Salt Marsh": {
		"description": "The Brine Walkers hold salt. Every region needs salt. A senior Brine Walker family has been asking specific questions about Flats party movements. They are looking for someone.",
		"plus": "Universal trade leverage. Salt means every faction deals with you. Rare preservation knowledge available.",
		"minus": "Seasonal flooding limits movement. Extraction pressure building. You may be who they are looking for.",
		"spawn": Vector2(4, 36)
	}
}

# ─────────────────────────────────────────
# SAVE / LOAD
# ─────────────────────────────────────────
func save_game() -> void:
	var file := FileAccess.open("user://save.dat", FileAccess.WRITE)
	if file:
		var data := {
			"name": player_name,
			"color": player_color.to_html(),
			"emoticon": player_emoticon,
			"region": starting_region,
			"habit": first_habit,
			"level": player_level,
			"xp": player_xp,
			"xp_next": xp_to_next_level,
			"stat_points": stat_points,
			"stats": stats,
			"explored_tiles": explored_tiles_count,
			"total_tiles": total_map_tiles,
			"familiar_bonus": familiar_environment_bonus,
			"last_milestone": last_milestone,
			"subdued_enemies": subdued_enemies,
			"alpha_recruits": alpha_recruits,
			"party_members": party_members,
			"quests": quests,
			"groq_key_saved": groq_api_key != ""
		}
		file.store_string(JSON.stringify(data))
		print("💾 Game saved.")

func load_game() -> void:
	if not FileAccess.file_exists("user://save.dat"):
		return
	var file := FileAccess.open("user://save.dat", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Dictionary = json.get_data()
		player_name             = data.get("name",           player_name)
		player_color            = Color.html(data.get("color", player_color.to_html()))
		player_emoticon         = data.get("emoticon",       player_emoticon)
		starting_region         = data.get("region",         starting_region)
		first_habit             = data.get("habit",          first_habit)
		player_level            = data.get("level",          1)
		player_xp               = data.get("xp",             0)
		xp_to_next_level        = data.get("xp_next",        150)
		stat_points             = data.get("stat_points",    0)
		stats                   = data.get("stats", {
			"physic":     BASE_STAT_VALUE,
			"dexterity":  BASE_STAT_VALUE,
			"intellect":  BASE_STAT_VALUE,
			"luck":       BASE_STAT_VALUE
		})
		explored_tiles_count    = data.get("explored_tiles", 0)
		total_map_tiles         = data.get("total_tiles",    0)
		familiar_environment_bonus = data.get("familiar_bonus", 0)
		last_milestone          = data.get("last_milestone", 0)
		subdued_enemies         = data.get("subdued_enemies", [])
		alpha_recruits          = data.get("alpha_recruits",  [])
		party_members           = data.get("party_members", [])
		quests                  = data.get("quests", {})
		calculate_exploration_percentage()
		print("📂 Game loaded — Level %d, %s, Party: %d members" % [player_level, starting_region, party_members.size()])

# ─────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────
func get_spawn_position() -> Vector2:
	if starting_region in regions:
		return regions[starting_region]["spawn"]
	return Vector2(20, 20)

func get_stat_display_name(stat: String) -> String:
	match stat:
		"physic":    return "PHY"
		"dexterity": return "DEX"
		"intellect": return "INT"
		"luck":      return "LCK"
	return stat

func reset_stats_to_base() -> void:
	stats = {
		"physic":    BASE_STAT_VALUE,
		"dexterity": BASE_STAT_VALUE,
		"intellect": BASE_STAT_VALUE,
		"luck":      BASE_STAT_VALUE
	}
	stat_points = 0
	subdued_enemies.clear()
	alpha_recruits.clear()
	party_members.clear()
	quests.clear()
