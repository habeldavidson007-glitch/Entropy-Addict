extends Control
# ═══════════════════════════════════════════════════════════
# PROLOGUE — Loading screen  →  Character Creation
# ═══════════════════════════════════════════════════════════

var bar_value: float  = 0.0
var stalled: bool     = false
var stall_timer: float = 2.8
var finishing: bool   = false
var done: bool        = false
var bar_fill: ColorRect
var bar_label: Label
var flash_overlay: ColorRect
var stars: Array = []
var _t: float = 0.0

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	for i in range(70):
		var d := ColorRect.new()
		d.size = Vector2(randi_range(1,3), randi_range(1,3))
		d.position = Vector2(randf_range(0,1140), randf_range(0,500))
		d.color = Color(1,1,1, randf_range(0.03,0.20))
		add_child(d)
		stars.append(d)
	var mt := Label.new()
	mt.text = "▲"
	mt.add_theme_font_size_override("font_size", 210)
	mt.modulate = Color(0.11,0.11,0.15)
	mt.position = Vector2(410, 90)
	add_child(mt)
	var tl := Label.new()
	tl.text = "ENTROPY ADDICT"
	tl.add_theme_font_size_override("font_size", 46)
	tl.modulate = Color(0.82,0.79,0.72)
	tl.position = Vector2(348, 472)
	add_child(tl)
	var sl := Label.new()
	sl.text = "a survival story dressed in the clothes of a power fantasy"
	sl.add_theme_font_size_override("font_size", 14)
	sl.modulate = Color(0.28,0.28,0.28)
	sl.position = Vector2(310, 530)
	add_child(sl)
	var bb := ColorRect.new()
	bb.color = Color(0.07,0.07,0.09)
	bb.size = Vector2(460, 3)
	bb.position = Vector2(386, 592)
	add_child(bb)
	bar_fill = ColorRect.new()
	bar_fill.color = Color(0.66,0.63,0.56)
	bar_fill.size = Vector2(0, 3)
	bar_fill.position = Vector2(386, 592)
	add_child(bar_fill)
	bar_label = Label.new()
	bar_label.text = "0%"
	bar_label.add_theme_font_size_override("font_size", 12)
	bar_label.modulate = Color(0.36,0.36,0.36)
	bar_label.position = Vector2(854, 583)
	add_child(bar_label)
	var gl := Label.new()
	gl.text = "Throne of the World"
	gl.add_theme_font_size_override("font_size", 11)
	gl.modulate = Color(0.18,0.18,0.18)
	gl.position = Vector2(386, 604)
	add_child(gl)
	flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1,1,1,0)
	flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash_overlay)

func _process(delta: float) -> void:
	_t += delta
	for i in range(stars.size()):
		stars[i].color.a = lerp(0.03, 0.20, (sin(_t*0.7 + i*0.38)+1.0)*0.5)
	if done: return
	if not stalled:
		bar_value = move_toward(bar_value, 97.0, delta*24.0)
		_upd()
		if bar_value >= 97.0: stalled = true
	elif not finishing:
		stall_timer -= delta
		if stall_timer <= 0.0: finishing = true
	else:
		bar_value = move_toward(bar_value, 100.0, delta*6.0)
		_upd()
		if bar_value >= 100.0:
			done = true
			_flash()

func _upd() -> void:
	bar_fill.size.x = (bar_value/100.0)*460.0
	bar_label.text = "%d%%" % int(bar_value)

func _flash() -> void:
	var tw := create_tween()
	tw.tween_property(flash_overlay,"color",Color(1,1,1,1),0.10)
	tw.tween_property(flash_overlay,"color",Color(1,1,1,0),0.10)
	tw.tween_property(flash_overlay,"color",Color(1,1,1,1),0.10)
	tw.tween_property(flash_overlay,"color",Color(1,1,1,0),0.10)
	tw.tween_property(flash_overlay,"color",Color(1,1,1,1),0.38)
	tw.tween_callback(func()->void: get_tree().change_scene_to_file("res://character_creation.tscn"))
