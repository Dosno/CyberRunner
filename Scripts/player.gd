extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0

@onready var animated_sprite = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get left/right input
	var direction := Input.get_axis("ui_left", "ui_right")

	# Movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Flip character
	if direction < 0:
		animated_sprite.flip_h = false
	elif direction > 0:
		animated_sprite.flip_h = true

	# -------------------------
	# ANIMATION
	# -------------------------

	# Jumping / falling
	if not is_on_floor():
		animated_sprite.play("jump")

	# Walking
	elif direction != 0:
		animated_sprite.play("walk")

	# Standing still
	else:
		animated_sprite.play("idle")

	move_and_slide()
