extends Node

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
# Get yours free at: console.groq.com/keys
# ─────────────────────────────────────────
var groq_api_key: String = "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"

# ─────────────────────────────────────────
# ALL 8 REGIONS — MASTER BIBLE CANONICAL
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
			"habit": first_habit
		}
		file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists("user://save.dat"):
		return
	var file := FileAccess.open("user://save.dat", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Dictionary = json.get_data()
		player_name     = data.get("name",     player_name)
		player_color    = Color.html(data.get("color", player_color.to_html()))
		player_emoticon = data.get("emoticon", player_emoticon)
		starting_region = data.get("region",   starting_region)
		first_habit     = data.get("habit",    first_habit)

# ─────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────
func get_spawn_position() -> Vector2:
	if starting_region in regions:
		return regions[starting_region]["spawn"]
	return Vector2(20, 20)
