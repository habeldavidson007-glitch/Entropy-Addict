extends Control

var bar_value: float = 0.0
var stalled: bool = false
var stall_timer: float = 2.4
var finishing: bool = false
var done: bool = false
var bar_fill: ColorRect
var bar_label: Label
var flash_overlay: ColorRect

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var mountain := Label.new()
	mountain.text = "▲"
	mountain.add_theme_font_size_override("font_size", 160)
	mountain.modulate = Color(0.18, 0.18, 0.22)
	mountain.position = Vector2(480, 160)
	add_child(mountain)
	
	var title := Label.new()
	title.text = "ENTROPY ADDICT"
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = Color(0.82, 0.79, 0.72)
	title.position = Vector2(400, 490)
	add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "a survival story dressed in the clothes of a power fantasy"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.modulate = Color(0.4, 0.4, 0.4)
	subtitle.position = Vector2(348, 538)
	add_child(subtitle)
	
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.12, 0.12, 0.15)
	bar_bg.size = Vector2(400, 16)
	bar_bg.position = Vector2(440, 585)
	add_child(bar_bg)
	
	bar_fill = ColorRect.new()
	bar_fill.color = Color(0.82, 0.79, 0.72)
	bar_fill.size = Vector2(0, 16)
	bar_fill.position = Vector2(440, 585)
	add_child(bar_fill)
	
	bar_label = Label.new()
	bar_label.text = "0%"
	bar_label.add_theme_font_size_override("font_size", 13)
	bar_label.modulate = Color(0.5, 0.5, 0.5)
	bar_label.position = Vector2(848, 583)
	add_child(bar_label)
	
	flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash_overlay)

func _process(delta: float) -> void:
	if done:
		return
	if not stalled:
		bar_value = move_toward(bar_value, 97.0, delta * 32.0)
		_update_bar()
		if bar_value >= 97.0:
			stalled = true
	elif not finishing:
		stall_timer -= delta
		if stall_timer <= 0.0:
			finishing = true
	else:
		bar_value = move_toward(bar_value, 100.0, delta * 9.0)
		_update_bar()
		if bar_value >= 100.0:
			done = true
			_trigger_flash()

func _update_bar() -> void:
	bar_fill.size.x = (bar_value / 100.0) * 400.0
	bar_label.text = "%d%%" % int(bar_value)

func _trigger_flash() -> void:
	var tween := create_tween()
	tween.tween_property(flash_overlay, "color", Color(1, 1, 1, 1), 0.10)
	tween.tween_property(flash_overlay, "color", Color(1, 1, 1, 0), 0.10)
	tween.tween_property(flash_overlay, "color", Color(1, 1, 1, 1), 0.10)
	tween.tween_property(flash_overlay, "color", Color(1, 1, 1, 0), 0.10)
	tween.tween_property(flash_overlay, "color", Color(1, 1, 1, 1), 0.35)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://character_creation.tscn")
	)
