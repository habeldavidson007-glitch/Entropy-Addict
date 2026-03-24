extends Control

var selected_region: String = ""
var selected_emoticon: String = "◈"
var habit_submitted: bool = false
var is_loading: bool = false
var emoticons: Array[String] = ["◈", "◇", "△", "○", "☽", "✦", "⬡", "⬢", "", "⊕", "", "⚔"]

var name_input: LineEdit
var habit_input: LineEdit
var color_picker: ColorPickerButton
var status_label: Label
var continue_btn: Button
var habit_response_label: Label
var main_container: VBoxContainer
var emoticon_buttons: Array = []
var region_buttons: Array = []

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	
	main_container = VBoxContainer.new()
	main_container.custom_minimum_size = Vector2(780, 0)
	main_container.position = Vector2(186, 0)
	main_container.add_theme_constant_override("separation", 0)
	scroll.add_child(main_container)
	
	_spacer(40)
	_heading("WHO ARE YOU?")
	_spacer(16)
	_sublabel("Your name in this world")
	_spacer(6)
	
	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter your name..."
	name_input.custom_minimum_size = Vector2(420, 46)
	name_input.add_theme_font_size_override("font_size", 18)
	main_container.add_child(name_input)
	
	_spacer(22)
	_sublabel("Your color — this is how you appear on the map")
	_spacer(6)
	
	color_picker = ColorPickerButton.new()
	color_picker.color = Color(0.2, 0.8, 0.4)
	color_picker.custom_minimum_size = Vector2(200, 46)
	main_container.add_child(color_picker)
	
	_spacer(22)
	_sublabel("Your mark — choose one")
	_spacer(8)
	
	var emoticon_row := HBoxContainer.new()
	emoticon_row.add_theme_constant_override("separation", 6)
	main_container.add_child(emoticon_row)
	
	for e in emoticons:
		var btn := Button.new()
		btn.text = e
		btn.custom_minimum_size = Vector2(54, 54)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_on_emoticon_selected.bind(e, btn))
		emoticon_row.add_child(btn)
		emoticon_buttons.append(btn)
		if e == "◈":
			btn.modulate = Color(0.3, 1.0, 0.5)
	
	_spacer(40)
	_heading("WHERE DO YOU BEGIN?")
	_spacer(6)
	_sublabel("Each region has advantages and costs. Read carefully. This shapes everything.")
	_spacer(14)
	
	for region_name in GameData.regions:
		var data: Dictionary = GameData.regions[region_name]
		var region_btn := Button.new()
		region_btn.custom_minimum_size = Vector2(780, 100)
		region_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		region_btn.add_theme_font_size_override("font_size", 12)
		region_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var display: String = "[%s]\n%s\n\n+ %s\n- %s" % [region_name, data["description"], data["plus"], data["minus"]]
		region_btn.text = display
		region_btn.pressed.connect(_on_region_selected.bind(region_name, region_btn))
		main_container.add_child(region_btn)
		region_buttons.append(region_btn)
		_spacer(6)
	
	_spacer(40)
	_heading("YOUR FIRST MOMENT")
	_spacer(8)
	_sublabel("You are awake. The world is real. The system is watching.")
	_sublabel("Do something. Any action repeated with intent becomes who you are.")
	_spacer(12)
	
	habit_input = LineEdit.new()
	habit_input.placeholder_text = "What will you do?"
	habit_input.custom_minimum_size = Vector2(620, 46)
	habit_input.add_theme_font_size_override("font_size", 18)
	main_container.add_child(habit_input)
	
	_spacer(10)
	
	var do_btn := Button.new()
	do_btn.text = "Do it"
	do_btn.custom_minimum_size = Vector2(180, 46)
	do_btn.add_theme_font_size_override("font_size", 16)
	do_btn.pressed.connect(_on_habit_submitted)
	main_container.add_child(do_btn)
	
	_spacer(14)
	
	habit_response_label = Label.new()
	habit_response_label.text = " "
	habit_response_label.add_theme_font_size_override("font_size", 15)
	habit_response_label.modulate = Color(0.65, 0.92, 0.65)
	habit_response_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	habit_response_label.custom_minimum_size = Vector2(780, 0)
	main_container.add_child(habit_response_label)
	
	_spacer(24)
	
	status_label = Label.new()
	status_label.text = " "
	status_label.modulate = Color(0.95, 0.4, 0.4)
	status_label.add_theme_font_size_override("font_size", 14)
	main_container.add_child(status_label)
	
	_spacer(16)
	
	continue_btn = Button.new()
	continue_btn.text = "Enter the world"
	continue_btn.custom_minimum_size = Vector2(300, 56)
	continue_btn.add_theme_font_size_override("font_size", 20)
	continue_btn.visible = false
	continue_btn.modulate = Color(0.3, 1.0, 0.5)
	continue_btn.pressed.connect(_on_continue)
	main_container.add_child(continue_btn)
	
	_spacer(60)

func _heading(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.modulate = Color(0.82, 0.79, 0.72)
	main_container.add_child(lbl)

func _sublabel(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(0.5, 0.5, 0.5)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(780, 0)
	main_container.add_child(lbl)

func _spacer(height: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	main_container.add_child(s)

func _on_emoticon_selected(e: String, btn: Button) -> void:
	selected_emoticon = e
	for b in emoticon_buttons:
		b.modulate = Color(1, 1, 1)
	btn.modulate = Color(0.3, 1.0, 0.5)

func _on_region_selected(region_name: String, btn: Button) -> void:
	selected_region = region_name
	for b in region_buttons:
		b.modulate = Color(1, 1, 1)
	btn.modulate = Color(0.3, 1.0, 0.5)
	status_label.text = ""

func _on_habit_submitted() -> void:
	var action: String = habit_input.text.strip_edges()
	if action.length() < 3:
		status_label.text = "Type something. Anything at all."
		return
	if is_loading:
		return
	is_loading = true
	habit_response_label.text = "[ SYSTEM ] Reading your action..."
	status_label.text = ""
	_call_groq(action)

func _call_groq(action: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_groq_response.bind(http, action))
	var system_prompt: String = """You are the SYSTEM in Entropy Addict. Player action: "%s". Respond: [ SYSTEM ] Habit In Development: [Name] +1 [One sentence.]""" % action
	var body: String = JSON.stringify({"model": "llama3-8b-8192", "messages": [{"role": "user", "content": system_prompt}], "max_tokens": 100, "temperature": 0.88})
	var headers: Array[String] = ["Content-Type: application/json", "Authorization: Bearer " + GameData.groq_api_key]
	var err: Error = http.request("https://api.groq.com/openai/v1/chat/completions", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_groq_fallback(action)
		http.queue_free()

func _on_groq_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, action: String) -> void:
	http.queue_free()
	is_loading = false
	if response_code != 200:
		_groq_fallback(action)
		return
	var json := JSON.new()
	var parse_err: Error = json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		_groq_fallback(action)
		return
	var data: Dictionary = json.get_data()
	if not data.has("choices"):
		_groq_fallback(action)
		return
	var response_text: String = data["choices"][0]["message"]["content"].strip_edges()
	habit_response_label.text = response_text
	GameData.first_habit = action
	habit_submitted = true
	continue_btn.visible = true

func _groq_fallback(action: String) -> void:
	habit_response_label.text = "[ SYSTEM ] Habit In Development: Survival Instinct +1\nThe system registers your action."
	GameData.first_habit = action
	habit_submitted = true
	continue_btn.visible = true

func _on_continue() -> void:
	status_label.text = ""
	if name_input.text.strip_edges().length() < 1:
		status_label.text = "You need a name."
		return
	if selected_region == "":
		status_label.text = "Choose a region. It matters."
		return
	if not habit_submitted:
		status_label.text = "Do something first."
		return
	
	GameData.player_name = name_input.text.strip_edges()
	GameData.player_color = color_picker.color
	GameData.player_emoticon = selected_emoticon
	GameData.starting_region = selected_region
	
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	
	var tween := create_tween()
	tween.tween_property(flash, "color", Color(1, 1, 1, 1), 0.35)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://world.tscn")
	)
