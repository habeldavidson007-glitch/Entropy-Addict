extends Control

var stat_labels: Dictionary = {}
var stat_values: Dictionary = {}
var plus_buttons: Dictionary = {}
var minus_buttons: Dictionary = {}
var points_label: Label
var confirm_button: Button

signal stats_confirmed

func _ready() -> void:
	_setup_ui()
	_update_display()

func _setup_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(550, 450)
	panel.position = Vector2(300, 100)
	add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	
	var title := Label.new()
	title.text = "★ LEVEL UP! ★"
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color(1, 0.9, 0.3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "Allocate your stat points"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.modulate = Color(0.7, 0.7, 0.7)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	
	points_label = Label.new()
	points_label.text = "Points Available: %d" % GameData.stat_points
	points_label.add_theme_font_size_override("font_size", 20)
	points_label.modulate = Color(0.9, 0.9, 0.3)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(points_label)
	
	var stats_container := VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 12)
	vbox.add_child(stats_container)
	
	var stat_names = ["physic", "dexterity", "intellect", "luck"]
	var stat_colors = {
		"physic": Color(0.9, 0.3, 0.3),
		"dexterity": Color(0.3, 0.9, 0.3),
		"intellect": Color(0.3, 0.3, 0.9),
		"luck": Color(0.9, 0.9, 0.3)
	}
	
	for stat in stat_names:
		var row = _create_stat_row(stat, stat_colors[stat])
		stats_container.add_child(row)
	
	var info := Label.new()
	info.text = "Base stat value: %d | 3 points per level" % GameData.BASE_STAT_VALUE
	info.add_theme_font_size_override("font_size", 12)
	info.modulate = Color(0.5, 0.5, 0.5)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)
	
	confirm_button = Button.new()
	confirm_button.text = "Confirm & Continue"
	confirm_button.custom_minimum_size = Vector2(200, 50)
	confirm_button.add_theme_font_size_override("font_size", 18)
	confirm_button.pressed.connect(_on_confirm)
	_style_button(confirm_button, Color(0.3, 0.7, 0.3))
	vbox.add_child(confirm_button)

func _create_stat_row(stat: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	
	var lbl := Label.new()
	lbl.text = GameData.get_stat_display_name(stat)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.modulate = color
	lbl.custom_minimum_size = Vector2(50, 0)
	row.add_child(lbl)
	
	var val := Label.new()
	val.text = "%d" % GameData.stats[stat]
	val.add_theme_font_size_override("font_size", 18)
	val.modulate = Color(1, 1, 1)
	val.custom_minimum_size = Vector2(40, 0)
	row.add_child(val)
	stat_values[stat] = val
	
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(35, 35)
	minus.pressed.connect(_on_minus_pressed.bind(stat))
	_style_button(minus, Color(0.5, 0.5, 0.5))
	row.add_child(minus)
	minus_buttons[stat] = minus
	
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(35, 35)
	plus.pressed.connect(_on_plus_pressed.bind(stat))
	_style_button(plus, color)
	row.add_child(plus)
	plus_buttons[stat] = plus
	
	var desc := Label.new()
	desc.text = GameData.STAT_POINT_DESCRIPTIONS[stat]
	desc.add_theme_font_size_override("font_size", 11)
	desc.modulate = Color(0.6, 0.6, 0.6)
	desc.custom_minimum_size = Vector2(250, 0)
	row.add_child(desc)
	
	return row

func _style_button(btn: Button, col: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = col.darkened(0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := style.duplicate()
	hover_style.bg_color = col
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var disabled_style := style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3)
	btn.add_theme_stylebox_override("disabled", disabled_style)

func _on_plus_pressed(stat: String) -> void:
	if GameData.increase_stat(stat):
		_update_display()

func _on_minus_pressed(stat: String) -> void:
	if GameData.decrease_stat(stat):
		_update_display()

func _on_confirm() -> void:
	emit_signal("stats_confirmed")
	queue_free()

func _update_display() -> void:
	if points_label:
		points_label.text = "Points Available: %d" % GameData.stat_points
		if GameData.stat_points > 0:
			points_label.modulate = Color(0.9, 0.9, 0.3)
		else:
			points_label.modulate = Color(0.5, 0.7, 0.5)
	
	for stat in stat_values:
		stat_values[stat].text = "%d" % GameData.stats[stat]
	
	for stat in plus_buttons:
		plus_buttons[stat].disabled = GameData.stat_points <= 0
		minus_buttons[stat].disabled = GameData.stats[stat] <= GameData.BASE_STAT_VALUE
