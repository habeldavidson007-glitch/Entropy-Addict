extends Control

var new_game_btn: Button
var continue_btn: Button
var quit_btn: Button
var save_info_label: Label

func _ready():
	_build_ui()
	_check_save_file()

func _build_ui():
	var background = ColorRect.new()
	background.color = Color(0.07, 0.06, 0.09)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var mountain := Label.new()
	mountain.text = "▲"
	mountain.add_theme_font_size_override("font_size", 160)
	mountain.modulate = Color(0.12, 0.12, 0.16)
	mountain.position = Vector2(480, 100)
	add_child(mountain)

	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center_container.add_child(vbox)

	var title_label = Label.new()
	title_label.text = "ENTROPY ADDICT"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.modulate = Color(0.82, 0.79, 0.72)
	vbox.add_child(title_label)

	var subtitle_label = Label.new()
	subtitle_label.text = "a survival story dressed in the clothes of a power fantasy"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.modulate = Color(0.35, 0.35, 0.35)
	vbox.add_child(subtitle_label)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer1)

	new_game_btn = _create_button("New Game")
	new_game_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_game_btn)

	continue_btn = _create_button("Continue")
	continue_btn.pressed.connect(_on_continue)
	vbox.add_child(continue_btn)

	quit_btn = _create_button("Quit")
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)

	save_info_label = Label.new()
	save_info_label.text = ""
	save_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_info_label.add_theme_font_size_override("font_size", 12)
	save_info_label.modulate = Color(0.5, 0.7, 0.5)
	save_info_label.visible = false
	vbox.add_child(save_info_label)

func _create_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 52)
	btn.add_theme_font_size_override("font_size", 20)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.16, 0.22)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.28, 0.26, 0.34)
	btn.add_theme_stylebox_override("hover", hover_style)

	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.12, 0.12, 0.14)
	btn.add_theme_stylebox_override("disabled", disabled_style)

	return btn

func _check_save_file():
	if FileAccess.file_exists("user://save.dat"):
		# FIX: Read actual save data instead of hardcoded "Level 5"
		var file := FileAccess.open("user://save.dat", FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data: Dictionary = json.get_data()
				var saved_level = data.get("level", 1)
				var saved_region = data.get("region", "Unknown")
				var saved_name = data.get("name", "Traveler")
				var party_count = data.get("party_members", []).size()

				continue_btn.text = "Continue  %s  Lv.%d" % [saved_name, saved_level]
				var party_txt = "  · Party: %d" % party_count if party_count > 0 else ""
				save_info_label.text = "%s%s" % [saved_region, party_txt]
				save_info_label.visible = true
				continue_btn.disabled = false
				return

		continue_btn.disabled = false
	else:
		continue_btn.disabled = true
		continue_btn.text = "Continue  (no save)"

func _on_new_game():
	get_tree().change_scene_to_file("res://prologue.tscn")

func _on_continue():
	if FileAccess.file_exists("user://save.dat"):
		GameData.load_game()
		get_tree().change_scene_to_file("res://world.tscn")

func _on_quit():
	get_tree().quit()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
