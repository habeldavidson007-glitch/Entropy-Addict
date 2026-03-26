extends Resource
class_name CharacterProfile

# Identity
@export var character_name: String = "Jarger Schamer"
@export var call_title: String = "Silent Call"
@export var fate_title: String = "Sovereign Tide"
@export var field_role: String = "Striker"

# Level & XP
@export var level: int = 1
@export var xp: int = 0
@export var xp_to_next_level: int = 100

# Masteries (Master Bible Part IV)
@export var mastery_1_name: String = "Mind"
@export var mastery_1_level: int = 0
@export var mastery_2_name: String = "Weapon"
@export var mastery_2_level: int = 0

# Root System (Habit → Routine → Custom → Skill)
@export var root_progress: int = 0
@export var root_stage: String = "Habit"

# Codex (6 slots: 3 Active, 3 Passive)
@export var skill_slots_active: Array[String] = ["", "", ""]
@export var skill_slots_passive: Array[String] = ["", "", ""]

# Habit Log
@export var current_habit_log: Array[String] = []

# Stats
@export var health: int = 100
@export var health_max: int = 100
@export var stamina: int = 100
@export var stamina_max: int = 100

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level:
		level_up()

func level_up() -> void:
	level += 1
	xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * 1.5)

func add_root_progress(amount: int) -> void:
	root_progress += amount
	if root_progress >= 100:
		root_progress = 0
		advance_root_stage()

func advance_root_stage() -> void:
	match root_stage:
		"Habit": root_stage = "Routine"
		"Routine": root_stage = "Custom"
		"Custom": root_stage = "Skill"

func get_xp_percentage() -> float:
	if xp_to_next_level == 0:
		return 0.0
	return float(xp) / float(xp_to_next_level)
