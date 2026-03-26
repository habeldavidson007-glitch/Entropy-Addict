extends Control

var title_label: Label
var subtitle_label: Label
var new_game_btn: Button
var continue_btn: Button
var quit_btn: Button
var save_info_label: Label

func _ready():
	print("[MainMenu] Loading...")
	
	# Create background
	var background = ColorRect.new()
	background.color = Color("#1a1a1a")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Create center container
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	# Create VBox for vertical layout
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center_container.add_child(vbox)
	
	# Create Title
	title_label = Label.new()
	title_label.text = "ENTROPY ADDICT"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color("#d4af37"))
	vbox.add_child(title_label)
	
	# Create Subtitle
	subtitle_label = Label.new()
	subtitle_label.text = "A Roguelike Survival Game"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color("#888888"))
	vbox.add_child(subtitle_label)
	
	# Add spacing
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer1)
	
	# Create New Game Button
	new_game_btn = _create_button("🎮 New Game")
	new_game_btn.name = "NewGameBtn"
	new_game_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_game_btn)
	
	# Create Continue Button
	continue_btn = _create_button("▶ Continue")
	continue_btn.name = "ContinueBtn"
	continue_btn.pressed.connect(_on_continue)
	vbox.add_child(continue_btn)
	
	# Create Quit Button
	quit_btn = _create_button("✕ Quit")
	quit_btn.name = "QuitBtn"
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)
	
	# Add spacing
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)
	
	# Create Save Info Label
	save_info_label = Label.new()
	save_info_label.text = ""
	save_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_info_label.add_theme_font_size_override("font_size", 12)
	save_info_label.add_theme_color_override("font_color", Color("#66aa66"))
	save_info_label.visible = false
	vbox.add_child(save_info_label)
	
	# Check for save file
	_check_save_file()
	
	print("[MainMenu] Ready!")

func _create_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(250, 50)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	
	# Style the button
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#333333")
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color("#444444")
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = Color("#555555")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	return btn

func _check_save_file():
	if FileAccess.file_exists("user://save.dat"):
		save_info_label.text = "■ Saved: Level 5 | Ashveld Flats"
		save_info_label.visible = true
		continue_btn.disabled = false
	else:
		continue_btn.disabled = true
		continue_btn.text = "▶ Continue (No Save)"

func _on_new_game():
	print("[MainMenu] Starting new game...")
	get_tree().change_scene_to_file("res://character_creation.tscn")

func _on_continue():
	print("[MainMenu] Loading game...")
	if FileAccess.file_exists("user://save.dat"):
		if GameData:
			GameData.load_game()
		get_tree().change_scene_to_file("res://world.tscn")
	else:
		print("[MainMenu] No save file!")

func _on_quit():
	print("[MainMenu] Quitting...")
	get_tree().quit()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
