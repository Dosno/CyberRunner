extends CharacterBody2D

# Movement Speeds
const WALK_SPEED = 130.0
const RUN_SPEED = 170.0
const JUMP_VELOCITY = -300.0

# Stats
var max_health: float = 100.0
var health: float = 100.0

var max_stamina: float = 100.0
var stamina: float = 100.0
const STAMINA_DRAIN_RATE = 25.0  # Depletes per second while running
const STAMINA_REGEN_RATE = 15.0  # Regens per second while resting

# Look-ahead settings
const LOOK_AHEAD_DISTANCE = 40.0
const LOOK_AHEAD_SPEED = 3.0

# Node References
@onready var animated_sprite = $AnimatedSprite2D
@onready var camera = $Camera2D
@onready var health_bar = $UI/HealthBar
@onready var stamina_bar = $UI/StaminaBar

func _ready() -> void:
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.process_callback = 0
	
	floor_snap_length = 8.0
	apply_floor_snap()
	
	# Initialize UI Progress Bars
	if health_bar and stamina_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		stamina_bar.max_value = max_stamina
		stamina_bar.value = stamina

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Input movement
	var direction := Input.get_axis("ui_left", "ui_right")

	# Stamina & Run Check
	var is_moving = direction != 0
	var is_trying_to_run = Input.is_action_pressed("run") and is_moving and stamina > 0
	var current_speed = WALK_SPEED

	if is_trying_to_run:
		current_speed = RUN_SPEED
		stamina = max(0.0, stamina - STAMINA_DRAIN_RATE * delta)
	else:
		# Regenerate stamina when not running
		if stamina < max_stamina:
			stamina = min(max_stamina, stamina + STAMINA_REGEN_RATE * delta)

	# Update Stamina Bar UI
	if stamina_bar:
		stamina_bar.value = stamina

	# Velocity movement
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
		animated_sprite.scale = Vector2(1.0, 1.0)
		animated_sprite.play("jump")
	elif abs(velocity.x) > 5.0:
		if is_trying_to_run:
			animated_sprite.scale = Vector2(1.12, 1.12)
			animated_sprite.play("run")
		else:
			animated_sprite.scale = Vector2(1.0, 1.0)
			animated_sprite.play("walk")
	else:
		animated_sprite.scale = Vector2(1.0, 1.0)
		animated_sprite.play("idle")

# Helper function to take damage
func take_damage(amount: float) -> void:
	health = max(0.0, health - amount)
	if health_bar:
		health_bar.value = health
