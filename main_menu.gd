extends Control

@onready var new_game_btn = $MarginContainer/VBoxContainer/NewGameBtn
@onready var continue_btn = $MarginContainer/VBoxContainer/ContinueBtn
@onready var quit_btn = $MarginContainer/VBoxContainer/QuitBtn
@onready var save_info_label = $MarginContainer/VBoxContainer/SaveInfoLabel

func _ready():
	# Connect buttons
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	
	# Check if save exists
	_check_save_file()

func _check_save_file():
	if FileAccess.file_exists("user://save.dat"):
		continue_btn.disabled = false
		continue_btn.text = "▶ Continue (Lv.5)"
		save_info_label.text = "■ Saved: Level 5 | Ashveld Flats | 0h"
		save_info_label.visible = true
	else:
		continue_btn.disabled = true
		continue_btn.text = "▶ Continue (No Save)"
		save_info_label.text = ""
		save_info_label.visible = false

func _on_new_game_pressed():
	print("Starting new game...")
	get_tree().change_scene_to_file("res://character_creation.tscn")

func _on_continue_pressed():
	if FileAccess.file_exists("user://save.dat"):
		print("Loading save game...")
		GameData.load_game()
		get_tree().change_scene_to_file("res://world.tscn")
	else:
		print("No save file found!")

func _on_quit_pressed():
	get_tree().quit()
