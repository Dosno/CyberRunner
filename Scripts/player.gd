extends CharacterBody2D

const WALK_SPEED = 130.0
const RUN_SPEED = 220.0
const JUMP_VELOCITY = -300.0

# Look-ahead settings
const LOOK_AHEAD_DISTANCE = 40.0
const LOOK_AHEAD_SPEED = 3.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var camera = $Camera2D

func _ready() -> void:
	# Enable camera position smoothing
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.process_callback = 0 # 0 = Physics
	
	# Snap the player to slopes up to 8 pixels deep
	floor_snap_length = 8.0
	apply_floor_snap()

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get left/right input
	var direction := Input.get_axis("ui_left", "ui_right")

	# Check for sprint
	var current_speed = WALK_SPEED
	if Input.is_action_pressed("run"):
		current_speed = RUN_SPEED

	# Movement
	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

	# Flip character & shift camera look-ahead
	if direction < 0:
		animated_sprite.flip_h = false
		var target_offset = Vector2(-LOOK_AHEAD_DISTANCE, 0)
		camera.offset = camera.offset.lerp(target_offset, LOOK_AHEAD_SPEED * delta)
	elif direction > 0:
		animated_sprite.flip_h = true
		var target_offset = Vector2(LOOK_AHEAD_DISTANCE, 0)
		camera.offset = camera.offset.lerp(target_offset, LOOK_AHEAD_SPEED * delta)

	move_and_slide()

	# -------------------------
	# ANIMATION
	# -------------------------
	
	if not is_on_floor():
		animated_sprite.play("jump")
	elif abs(velocity.x) > 5.0:
		if Input.is_action_pressed("run"):
			animated_sprite.play("run")
		else:
			animated_sprite.play("walk")
	else:
		animated_sprite.play("idle")
