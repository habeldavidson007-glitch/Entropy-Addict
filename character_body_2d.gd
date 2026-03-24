extends CharacterBody2D

# --- SETUP ---
const TILE_SIZE = 32
const MOVE_SPEED = 200.0

var color_rect: ColorRect
var collision_shape: CollisionShape2D

func _ready():
	# Set player starting position
	position = Vector2(320, 240)
	
	# Setup ColorRect (visual placeholder for Jarger)
	color_rect = ColorRect.new()
	color_rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	color_rect.position = Vector2(-TILE_SIZE / 2, -TILE_SIZE / 2)
	color_rect.color = Color(0.2, 0.8, 0.4)  # green placeholder
	add_child(color_rect)
	
	# Setup CollisionShape2D
	collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(TILE_SIZE, TILE_SIZE)
	collision_shape.shape = shape
	add_child(collision_shape)

# --- MOVEMENT ---
func _physics_process(delta):
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	
	velocity = direction.normalized() * MOVE_SPEED
	move_and_slide()
