extends Node

var player_name: String = "Traveler"
var player_color: Color = Color(0.2, 0.8, 0.4)
var player_emoticon: String = "◈"
var starting_region: String = ""
var first_habit: String = ""
var groq_api_key: String = "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"

var regions: Dictionary = {
	"Ashveld Flats": {
		"description": "A barren, wind-swept plain. Dangerous but open.",
		"plus": "Visibility +20%",
		"minus": "Cover -10%"
	},
	"Iron Spire": {
		"description": "Ruins of an ancient industrial complex.",
		"plus": "Defense +1",
		"minus": "Movement -1 Tile"
	},
	"Whispering Woods": {
		"description": "Dense forest where sound carries strangely.",
		"plus": "Stealth +1",
		"minus": "Detection Range -2"
	},
	"Neon District": {
		"description": "Remnants of the old city. High tech, high risk.",
		"plus": "Hack Chance +10%",
		"minus": "Enemy Aggro +15%"
	}
}

func get_spawn_position() -> Vector2:
	return Vector2(20, 20)
