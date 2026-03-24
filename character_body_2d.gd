extends CharacterBody2D

const TILE_SIZE = 32
const MOVE_DURATION = 0.15

var color_rect: ColorRect
var collision_shape: CollisionShape2D

var dice_result = 0
var is_moving = false
var tiles_remaining = 0
var move_direction = Vector2.ZERO
var target_position = Vector2.ZERO
var blocked_direction = ""

var ui_layer: CanvasLayer
var dice_label: Label
var direction_buttons: Control
var buttons = {}

var world
var camera: Camera2D

var shake_intensity = 0.0
var shake_duration = 0.0
var shake_timer = 0.0

var flash_overlay: ColorRect
var is_transitioning = false

func _ready():
	position = Vector2(10, 7) * TILE_SIZE
	target_position = position

	color_rect = ColorRect.new()
	color_rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	color_rect.position = Vector2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0)
	color_rect.color = Color(0.2, 0.8, 0.4)
	add_child(color_rect)

	collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(TILE_SIZE, TILE_SIZE)
	collision_shape.shape = shape
	add_child(collision_shape)

	camera = Camera2D.new()
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	add_child(camera)

	_setup_ui()
	world = get_parent()

func _setup_ui():
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.size = Vector2(1152, 648)
	flash_overlay.position = Vector2(-576, -324)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(flash_overlay)

	dice_label = Label.new()
	dice_label.position = Vector2(20, 20)
	dice_label.text = "Press SPACE to roll the dice!"
	dice_label.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(dice_label)

	direction_buttons = Control.new()
	direction_buttons.visible = false
	ui_layer.add_child(direction_buttons)

	_make_button("▲ Up",    Vector2(200, 100), "up")
	_make_button("▼ Down",  Vector2(200, 180), "down")
	_make_button("◄ Left",  Vector2(110, 140), "left")
	_make_button("► Right", Vector2(290, 140), "right")

func _make_button(label: String, pos: Vector2, dir: String):
	var btn = Button.new()
	btn.text = label
	btn.position = pos
	btn.size = Vector2(80, 40)
	btn.pressed.connect(_on_direction_chosen.bind(dir))
	direction_buttons.add_child(btn)
	buttons[dir] = btn

func _show_direction_buttons(blocked: String = ""):
	direction_buttons.visible = true
	for dir in buttons:
		buttons[dir].visible = (dir != blocked)

func _input(event):
	if is_transitioning:
		return
	if event.is_action_pressed("ui_accept") and not is_moving and dice_result == 0 and tiles_remaining == 0:
		_roll_dice()
		return
	if direction_buttons.visible and not is_moving:
		if event.is_action_pressed("ui_up") and blocked_direction != "up":
			_on_direction_chosen("up")
		elif event.is_action_pressed("ui_down") and blocked_direction != "down":
			_on_direction_chosen("down")
		elif event.is_action_pressed("ui_left") and blocked_direction != "left":
			_on_direction_chosen("left")
		elif event.is_action_pressed("ui_right") and blocked_direction != "right":
			_on_direction_chosen("right")

func _roll_dice():
	var die1 = randi_range(1, 6)
	var die2 = randi_range(1, 6)
	dice_result = die1 + die2
	blocked_direction = ""
	dice_label.text = "Rolled: %d + %d = %d — Choose direction!" % [die1, die2, dice_result]
	_show_direction_buttons()

func _on_direction_chosen(dir: String):
	direction_buttons.visible = false
	if dice_result > 0:
		tiles_remaining = dice_result
		dice_result = 0
	match dir:
		"up":    move_direction = Vector2(0, -TILE_SIZE)
		"down":  move_direction = Vector2(0, TILE_SIZE)
		"left":  move_direction = Vector2(-TILE_SIZE, 0)
		"right": move_direction = Vector2(TILE_SIZE, 0)
	blocked_direction = ""
	_move_next_tile()

func _move_next_tile():
	if tiles_remaining <= 0:
		var grid_pos = position / TILE_SIZE
		_check_detection(grid_pos)
		if world.check_encounter(grid_pos):
			_trigger_battle_transition()
		else:
			is_moving = false
		return

	var next_pos = position + move_direction
	var next_grid = next_pos / TILE_SIZE

	if not world.is_walkable(next_grid):
		if move_direction == Vector2(0, -TILE_SIZE): blocked_direction = "up"
		elif move_direction == Vector2(0, TILE_SIZE): blocked_direction = "down"
		elif move_direction == Vector2(-TILE_SIZE, 0): blocked_direction = "left"
		elif move_direction == Vector2(TILE_SIZE, 0): blocked_direction = "right"
		is_moving = false
		dice_label.text = "🧱 Wall ahead! %d moves left — pick another direction." % tiles_remaining
		_show_direction_buttons(blocked_direction)
		return

	is_moving = true
	target_position = next_pos
	tiles_remaining -= 1

func _check_detection(grid_pos: Vector2):
	world.update_enemy_visibility(grid_pos)
	var level = world.get_detection_level(grid_pos)
	var dist = world.get_closest_enemy_distance(grid_pos)
	match level:
		"encounter":
			dice_label.text = "❗ Enemy is right here!"
		"visible":
			dice_label.text = "⚠ Enemy close! %.0f tiles away — stay sharp!" % dist
			_start_shake(2.0, 0.3)
		"warning":
			dice_label.text = "👁 Detected a presence! %.0f tiles away — be aware!" % dist
		"safe":
			dice_label.text = "Press SPACE to roll the dice!"

func _trigger_battle_transition():
	is_transitioning = true
	dice_label.text = "⚔ Enemy encountered!"
	_start_shake(8.0, 0.6)
	var tween = create_tween()
	tween.tween_property(flash_overlay, "color", Color(1, 1, 1, 1), 0.15)
	tween.tween_property(flash_overlay, "color", Color(1, 1, 1, 0), 0.15)
	tween.tween_property(flash_overlay, "color", Color(1, 1, 1, 1), 0.15)
	tween.tween_property(flash_overlay, "color", Color(1, 1, 1, 0), 0.15)
	tween.tween_property(flash_overlay, "color", Color(1, 1, 1, 1), 0.3)
	tween.tween_callback(func():
		flash_overlay.color = Color(1, 1, 1, 0)
		is_transitioning = false
		is_moving = false
		dice_label.text = "⚔ Battle! (Combat scene coming soon...)"
	)

func _start_shake(intensity: float, duration: float):
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = duration

func _process(delta):
	if shake_timer > 0:
		shake_timer -= delta
		var amount = (shake_timer / shake_duration) * shake_intensity
		camera.offset = Vector2(
			randf_range(-amount, amount),
			randf_range(-amount, amount)
		)
	else:
		camera.offset = Vector2.ZERO

	if is_moving and not is_transitioning:
		position = position.move_toward(target_position, TILE_SIZE / MOVE_DURATION * delta)
		if position == target_position:
			_move_next_tile()
