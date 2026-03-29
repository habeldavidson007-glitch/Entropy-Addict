extends Control
# ═══════════════════════════════════════════════════════════
# CHARACTER CREATION
# ═══════════════════════════════════════════════════════════

var selected_region: String  = ""
var selected_emoticon: String = "◈"
var habit_submitted: bool    = false
var is_loading: bool         = false

var emoticons: Array[String] = ["◈","◇","△","○","☽","✦","⬡","⬢","◉","⊕","❖","⚔","◬","⬖","✧","⌘","◐","◑","⊗","⟐"]

var name_input: LineEdit
var habit_input: LineEdit
var color_picker: ColorPickerButton
var status_label: Label
var continue_btn: Button
var habit_response_label: Label
var main_container: VBoxContainer
var emoticon_buttons: Array = []
var region_buttons: Array   = []

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04,0.04,0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	main_container = VBoxContainer.new()
	main_container.custom_minimum_size = Vector2(840,0)
	main_container.position = Vector2(156,0)
	main_container.add_theme_constant_override("separation",0)
	scroll.add_child(main_container)

	_sp(50); _h("WHO ARE YOU?"); _div(); _sp(14)
	_sub("Your name in this world. Not a title. Not a rank."); _sp(8)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter your name..."
	name_input.custom_minimum_size = Vector2(480,52)
	name_input.add_theme_font_size_override("font_size",20)
	main_container.add_child(name_input)
	_sp(24); _sub("Your color — how you appear on the map"); _sp(8)
	color_picker = ColorPickerButton.new()
	color_picker.color = Color(0.2,0.8,0.4)
	color_picker.custom_minimum_size = Vector2(220,50)
	main_container.add_child(color_picker)
	_sp(24); _sub("Your mark"); _sp(10)
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation",8)
	main_container.add_child(er)
	for e in emoticons:
		var btn := Button.new()
		btn.text = e; btn.custom_minimum_size = Vector2(48,48)
		btn.add_theme_font_size_override("font_size",20)
		btn.pressed.connect(_on_emot.bind(e,btn))
		er.add_child(btn); emoticon_buttons.append(btn)
		if e == "◈": btn.modulate = Color(0.3,1.0,0.5)

	_sp(54); _h("WHERE DO YOU BEGIN?"); _div(); _sp(8)
	_sub("Eight regions. Each has real advantages and real costs from the world's logic.")
	_sub("This is not a difficulty setting. It is a starting position. Everything follows from here.")
	_sp(18)
	for rn in GameData.regions:
		var d: Dictionary = GameData.regions[rn]
		var rb := Button.new()
		rb.custom_minimum_size = Vector2(840,120)
		rb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rb.add_theme_font_size_override("font_size",12)
		rb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		rb.text = "[%s]\n%s\n\n▲ %s\n▼ %s" % [rn,d["description"],d["plus"],d["minus"]]
		rb.pressed.connect(_on_region.bind(rn,rb))
		main_container.add_child(rb); region_buttons.append(rb); _sp(8)

	_sp(54); _h("YOUR FIRST MOMENT"); _div(); _sp(12)
	_sub("You are awake. The sky is the right shade of pale. The world is real.")
	_sub("The system is watching. It does not care what you do.")
	_sub("It only cares that you do something — with intent, with attention.")
	_sp(8); _sub("[ Any action repeated with intent becomes who you are. ]"); _sp(16)
	habit_input = LineEdit.new()
	habit_input.placeholder_text = "What will you do?"
	habit_input.custom_minimum_size = Vector2(640,52)
	habit_input.add_theme_font_size_override("font_size",18)
	main_container.add_child(habit_input); _sp(12)
	var db := Button.new()
	db.text = "Do it"; db.custom_minimum_size = Vector2(200,50)
	db.add_theme_font_size_override("font_size",16)
	db.modulate = Color(0.80,0.77,0.70)
	db.pressed.connect(_on_habit); main_container.add_child(db); _sp(18)
	habit_response_label = Label.new()
	habit_response_label.text = " "
	habit_response_label.add_theme_font_size_override("font_size",15)
	habit_response_label.modulate = Color(0.50,0.82,0.50)
	habit_response_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	habit_response_label.custom_minimum_size = Vector2(840,0)
	main_container.add_child(habit_response_label); _sp(28)
	status_label = Label.new(); status_label.text = " "
	status_label.modulate = Color(0.88,0.32,0.32)
	status_label.add_theme_font_size_override("font_size",14)
	main_container.add_child(status_label); _sp(18)
	continue_btn = Button.new()
	continue_btn.text = "Enter the world  →"
	continue_btn.custom_minimum_size = Vector2(340,62)
	continue_btn.add_theme_font_size_override("font_size",20)
	continue_btn.visible = false
	continue_btn.modulate = Color(0.28,0.98,0.48)
	continue_btn.pressed.connect(_on_continue)
	main_container.add_child(continue_btn); _sp(80)

func _h(t:String)->void:
	var l:=Label.new();l.text=t;l.add_theme_font_size_override("font_size",28);l.modulate=Color(0.82,0.79,0.72);main_container.add_child(l)
func _sub(t:String)->void:
	var l:=Label.new();l.text=t;l.add_theme_font_size_override("font_size",13);l.modulate=Color(0.46,0.46,0.46);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size=Vector2(840,0);main_container.add_child(l)
func _div()->void:
	var l:=ColorRect.new();l.color=Color(0.16,0.16,0.18);l.custom_minimum_size=Vector2(840,1);main_container.add_child(l);_sp(6)
func _sp(h:int)->void:
	var s:=Control.new();s.custom_minimum_size=Vector2(0,h);main_container.add_child(s)

func _on_emot(e:String,btn:Button)->void:
	selected_emoticon=e
	for b in emoticon_buttons: b.modulate=Color(1,1,1)
	btn.modulate=Color(0.3,1.0,0.5)

func _on_region(rn:String,btn:Button)->void:
	selected_region=rn
	for b in region_buttons: b.modulate=Color(1,1,1)
	btn.modulate=Color(0.3,1.0,0.5)
	status_label.text=""

func _on_habit()->void:
	var action:=habit_input.text.strip_edges()
	if action.length()<3: status_label.text="Type something. Anything at all."; return
	if is_loading: return
	is_loading=true; habit_response_label.text="[ SYSTEM ] Processing..."; status_label.text=""
	_call_groq(action)

func _call_groq(action:String)->void:
	var http:=HTTPRequest.new(); add_child(http)
	http.request_completed.connect(_on_groq_resp.bind(http,action))
	var p:="You are the SYSTEM in Entropy Addict. Player's first action: \"%s\"\nRespond EXACTLY:\n[ SYSTEM ] Habit In Development: [2-4 word name] +1\n[One cold dry sentence.]" % action
	var body:=JSON.stringify({"model":"llama3-8b-8192","messages":[{"role":"user","content":p}],"max_tokens":100,"temperature":0.85})
	var err:=http.request("https://api.groq.com/openai/v1/chat/completions",
		["Content-Type: application/json","Authorization: Bearer "+GameData.groq_api_key],HTTPClient.METHOD_POST,body)
	if err!=OK: _fallback(action); http.queue_free()

func _on_groq_resp(_r:int,code:int,_h:PackedStringArray,body:PackedByteArray,http:HTTPRequest,action:String)->void:
	http.queue_free(); is_loading=false
	if code!=200: _fallback(action); return
	var json:=JSON.new()
	if json.parse(body.get_string_from_utf8())!=OK: _fallback(action); return
	var d=json.get_data()
	if not d is Dictionary or not d.has("choices"): _fallback(action); return
	var text:String=d["choices"][0]["message"]["content"].strip_edges()
	habit_response_label.text=text
	var s:=text.find("Development: "); var e:=text.find(" +1")
	if s!=-1 and e!=-1: GameData.first_habit_name=text.substr(s+13,e-s-13)
	GameData.first_habit=action; habit_submitted=true; continue_btn.visible=true

func _fallback(action:String)->void:
	habit_response_label.text="[ SYSTEM ] Habit In Development: Survival Instinct +1\nThe system registers the action. It does not forget."
	GameData.first_habit=action; GameData.first_habit_name="Survival Instinct"
	habit_submitted=true; continue_btn.visible=true

func _on_continue()->void:
	status_label.text=""
	if name_input.text.strip_edges().length()<1: status_label.text="You need a name."; return
	if selected_region=="": status_label.text="Choose a region."; return
	if not habit_submitted: status_label.text="Do something first."; return
	GameData.player_name=name_input.text.strip_edges()
	GameData.player_color=color_picker.color
	GameData.player_emoticon=selected_emoticon
	GameData.starting_region=selected_region
	GameData.add_habit(GameData.first_habit_name)
	var flash:=ColorRect.new(); flash.color=Color(1,1,1,0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(flash)
	var tw:=create_tween()
	tw.tween_property(flash,"color",Color(1,1,1,1),0.38)
	tw.tween_callback(func()->void: get_tree().change_scene_to_file("res://world.tscn"))
