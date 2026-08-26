extends CharacterBody2D

# Movement Speeds
const WALK_SPEED = 120.0
const RUN_SPEED = 180.0
const CROUCH_SPEED = 60.0
const SLIDE_SPEED = 280.0
const DODGE_SPEED = 250
const AIR_DASH_SPEED = 400.0
const LUNGE_SPEED = 280.0
const CLIMB_SPEED = 100.0
const JUMP_VELOCITY = -300.0
const WALL_JUMP_VELOCITY = Vector2(250.0, -280.0)

# Camera Look-Ahead Settings
const LOOK_AHEAD_DISTANCE = 40.0
const LOOK_AHEAD_SPEED = 3.0

# ==============================================================================
# ANIMATION OFFSET DICTIONARY
# ==============================================================================
const ANIM_OFFSETS: Dictionary = {
	"idle": Vector2(0, 0),
	"walk": Vector2(0, -1),
	"run": Vector2(0, 5),
	"crouching": Vector2(0, 3),
	"slide": Vector2(0, 0),

	"jump": Vector2(0, 0),
	"double jump_forward": Vector2(0, 0),
	"double jump_vertical": Vector2(0, 0),
	"aerial_dash": Vector2(0, 0),

	"1x atk_merged": Vector2(-55, -3),
	"2x 1 atk_merged": Vector2(30, 0),
	"2x 2 atk_merged": Vector2(30, 0),
	"3x atk_merged": Vector2(-30, -15),

	"back_dodge": Vector2(0, 0),
	"dodge atk 1x_merged": Vector2(30, 0),
	"dodge atk 1x_merged2": Vector2(30, 0),
	"dodge atk 2x_merged": Vector2(30, 0),
	"dodge atk 3x_merged": Vector2(-5, -45),

	"jump atk 2x_merged": Vector2(-30, 0),
	"dodge atk 3x_fall loop1": Vector2(0, 0),
	"dodge atk 3x_fall loop2": Vector2(0, 0),

	"wall slide": Vector2(0, 0),
	"wall jump": Vector2(0, 0),
	"up": Vector2(0, 0),
	"02_ladder climb up": Vector2(0, 0),

	"normal hit": Vector2(0, 0),
	"hard hit": Vector2(0, 0),
	"healing_merged": Vector2(0, -12)
}

# State Machine
enum State { 
	NORMAL, CROUCH, SLIDE, ATTACK, DODGE, AIR_ATTACK, DODGE_ATTACK, 
	PLUNGE_ATTACK, AIR_DASH, WALL_SLIDE, LEDGE_HANG, LADDER, HURT, HEAL 
}
var current_state: State = State.NORMAL

var is_walking_toggle: bool = false
var exiting_crouch: bool = false
var can_double_jump: bool = true
var can_air_dash: bool = true

var combo_step: int = 0
var combo_timer: float = 0.0
const COMBO_WINDOW: float = 0.8
var attack_buffered_light: bool = false

var dodge_combo_step: int = 0
var recent_dodge_timer: float = 0.0
var dodge_direction: float = 1.0

var near_ladder: bool = false
var near_ledge: bool = false
var ledge_position: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

@onready var dash_fx_sprite: AnimatedSprite2D = get_node_or_null("DashFXSprite")
@onready var dash_smoke_sprite: AnimatedSprite2D = get_node_or_null("DashSmokeSprite")

func _ready() -> void:
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	
	floor_snap_length = 8.0
	apply_floor_snap()
	
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("walk_toggle"):
		is_walking_toggle = !is_walking_toggle

func _physics_process(delta: float) -> void:
	if combo_step > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_step = 0

	if recent_dodge_timer > 0.0:
		recent_dodge_timer -= delta
	else:
		if current_state != State.DODGE_ATTACK:
			dodge_combo_step = 0

	# --- INSTANT COMBO CANCEL (Light -> Heavy) ---
	if current_state in [State.ATTACK, State.DODGE_ATTACK]:
		if Input.is_action_just_pressed("attack_heavy"):
			perform_heavy_attack()
		elif Input.is_action_just_pressed("attack_light"):
			attack_buffered_light = true

	if not is_on_floor() and current_state not in [State.AIR_DASH, State.WALL_SLIDE, State.LEDGE_HANG, State.LADDER, State.PLUNGE_ATTACK]:
		velocity += get_gravity() * delta
	elif current_state == State.PLUNGE_ATTACK:
		velocity.y = 500.0

	if is_on_floor():
		can_double_jump = true
		can_air_dash = true

	match current_state:
		State.NORMAL:
			handle_normal_state(delta)
		State.CROUCH:
			handle_crouch_state(delta)
		State.SLIDE:
			handle_slide_state(delta)
		State.ATTACK:
			handle_attack_state(delta)
		State.DODGE:
			handle_dodge_state(delta)
		State.AIR_ATTACK:
			handle_air_attack_state(delta)
		State.DODGE_ATTACK:
			handle_dodge_attack_state(delta)
		State.PLUNGE_ATTACK:
			handle_plunge_attack_state(delta)
		State.AIR_DASH:
			handle_air_dash_state(delta)
		State.WALL_SLIDE:
			handle_wall_slide_state(delta)
		State.LEDGE_HANG:
			handle_ledge_hang_state(delta)
		State.LADDER:
			handle_ladder_state(delta)
		State.HURT:
			handle_hurt_state(delta)
		State.HEAL:
			handle_heal_state(delta)

	move_and_slide()

# --- STATE HANDLERS ---

func handle_normal_state(delta: float) -> void:
	if InputMap.has_action("heal") and Input.is_action_just_pressed("heal") and is_on_floor():
		change_state(State.HEAL)
		return

	if near_ladder and Input.is_action_just_pressed("ui_up"):
		change_state(State.LADDER)
		return

	if InputMap.has_action("slide") and Input.is_action_just_pressed("slide") and is_on_floor():
		change_state(State.SLIDE)
		return

	if InputMap.has_action("crouch") and Input.is_action_pressed("crouch") and is_on_floor():
		change_state(State.CROUCH)
		return

	if Input.is_action_just_pressed("dodge") and not is_on_floor() and can_air_dash:
		change_state(State.AIR_DASH)
		return

	if not is_on_floor() and Input.is_action_just_pressed("attack_heavy") and Input.is_action_pressed("crouch"):
		change_state(State.PLUNGE_ATTACK)
		return

	if Input.is_action_just_pressed("attack_light") and not is_on_floor():
		change_state(State.AIR_ATTACK)
		return

	if Input.is_action_just_pressed("attack_heavy") and is_on_floor():
		if recent_dodge_timer > 0.0 or dodge_combo_step > 0:
			perform_dodge_attack_step()
		else:
			perform_heavy_attack()
		return

	if Input.is_action_just_pressed("attack_light") and is_on_floor():
		perform_light_attack_step()
		return

	if Input.is_action_just_pressed("dodge") and is_on_floor():
		change_state(State.DODGE)
		return

	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif can_double_jump:
			velocity.y = JUMP_VELOCITY
			can_double_jump = false
			play_animation("double jump_forward" if velocity.x != 0 else "double jump_vertical")

	if is_on_wall() and not is_on_floor() and velocity.y > 0:
		change_state(State.WALL_SLIDE)
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	var current_speed = WALK_SPEED if is_walking_toggle else RUN_SPEED

	if direction != 0:
		velocity.x = direction * current_speed
		update_facing_and_camera(direction, delta)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

	if not is_on_floor():
		if animated_sprite.animation not in ["double jump_forward", "double jump_vertical"]:
			play_animation("jump")
	elif abs(velocity.x) > 5.0:
		play_animation("walk" if is_walking_toggle else "run")
	else:
		play_animation("idle")

func handle_crouch_state(delta: float) -> void:
	if not exiting_crouch and (!Input.is_action_pressed("crouch") or !is_on_floor()):
		exiting_crouch = true
		animated_sprite.play("crouching")
		return

	if exiting_crouch:
		return

	if Input.is_action_just_pressed("attack_light"):
		exiting_crouch = false
		perform_light_attack_step()
		return
	elif Input.is_action_just_pressed("attack_heavy"):
		exiting_crouch = false
		perform_heavy_attack()
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * CROUCH_SPEED
		update_facing_and_camera(direction, delta)
	else:
		velocity.x = move_toward(velocity.x, 0, CROUCH_SPEED)

	if animated_sprite.animation == "crouching":
		if animated_sprite.frame >= 9 and not exiting_crouch:
			animated_sprite.frame = 9
			animated_sprite.pause()

func handle_slide_state(_delta: float) -> void:
	velocity.x = (1.0 if animated_sprite.flip_h else -1.0) * SLIDE_SPEED

func handle_attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED * 2.0 * delta)

func handle_dodge_state(_delta: float) -> void:
	if Input.is_action_just_pressed("attack_heavy") or Input.is_action_just_pressed("attack_light"):
		perform_dodge_attack_step()
		return
	velocity.x = dodge_direction * DODGE_SPEED

func handle_air_attack_state(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * WALK_SPEED, WALK_SPEED * delta)

func handle_dodge_attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, LUNGE_SPEED * 2.5 * delta)

func handle_plunge_attack_state(_delta: float) -> void:
	if is_on_floor() and animated_sprite.animation != "dodge atk 3x_merged":
		play_animation("dodge atk 3x_merged")

func handle_air_dash_state(_delta: float) -> void:
	velocity.y = 0
	velocity.x = (1.0 if animated_sprite.flip_h else -1.0) * AIR_DASH_SPEED

func handle_wall_slide_state(_delta: float) -> void:
	velocity.y = 60.0
	play_animation("wall slide")

	if Input.is_action_just_pressed("ui_accept"):
		var wall_dir = -1.0 if animated_sprite.flip_h else 1.0
		velocity = Vector2(WALL_JUMP_VELOCITY.x * wall_dir, WALL_JUMP_VELOCITY.y)
		play_animation("wall jump")
		change_state(State.NORMAL)

	if is_on_floor() or not is_on_wall():
		change_state(State.NORMAL)

func handle_ledge_hang_state(_delta: float) -> void:
	velocity = Vector2.ZERO
	if Input.is_action_just_pressed("ui_up"):
		play_animation("up")
	elif Input.is_action_just_pressed("crouch"):
		change_state(State.NORMAL)

func handle_ladder_state(_delta: float) -> void:
	var climb_dir := Input.get_axis("ui_up", "ui_down")
	velocity.y = climb_dir * CLIMB_SPEED
	velocity.x = 0

	if climb_dir != 0:
		play_animation("02_ladder climb up")
	else:
		animated_sprite.pause()

	if not near_ladder or is_on_floor():
		change_state(State.NORMAL)

func handle_hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED * delta)

func handle_heal_state(_delta: float) -> void:
	velocity.x = 0

func take_damage(_amount: int, is_heavy: bool = false) -> void:
	change_state(State.HURT)
	play_animation("hard hit" if is_heavy else "normal hit")

# --- ATTACK ROUTINES ---

func perform_light_attack_step() -> void:
	current_state = State.ATTACK
	attack_buffered_light = false

	var anim = "1x atk_merged"
	if combo_step == 1:
		anim = "2x 1 atk_merged"
	elif combo_step == 2:
		anim = "2x 2 atk_merged"

	play_animation(anim)

	combo_step = (combo_step + 1) % 3
	combo_timer = COMBO_WINDOW

func perform_heavy_attack() -> void:
	current_state = State.ATTACK
	attack_buffered_light = false

	play_animation("3x atk_merged")
	combo_step = 0

func perform_dodge_attack_step() -> void:
	current_state = State.DODGE_ATTACK
	attack_buffered_light = false

	var facing_dir = 1.0 if animated_sprite.flip_h else -1.0
	velocity.x = facing_dir * LUNGE_SPEED

	var anim = "dodge atk 1x_merged"
	if dodge_combo_step == 1:
		anim = "dodge atk 2x_merged"
	elif dodge_combo_step == 2:
		anim = "dodge atk 3x_merged"

	play_animation(anim)

	dodge_combo_step = (dodge_combo_step + 1) % 3
	recent_dodge_timer = 0.6

# --- HELPERS & STATE MANAGEMENT ---

func update_facing_and_camera(direction: float, delta: float) -> void:
	if direction < 0:
		animated_sprite.flip_h = false
		camera.offset = camera.offset.lerp(Vector2(-LOOK_AHEAD_DISTANCE, 0), LOOK_AHEAD_SPEED * delta)
	elif direction > 0:
		animated_sprite.flip_h = true
		camera.offset = camera.offset.lerp(Vector2(LOOK_AHEAD_DISTANCE, 0), LOOK_AHEAD_SPEED * delta)

	apply_animation_offset(animated_sprite.animation)

func play_animation(anim_name: String) -> void:
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		return

	if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
		animated_sprite.stop()
		animated_sprite.frame = 0
		apply_animation_offset(anim_name)
		animated_sprite.play(anim_name)

func apply_animation_offset(anim_name: String) -> void:
	if ANIM_OFFSETS.has(anim_name):
		var target_offset: Vector2 = ANIM_OFFSETS[anim_name]
		animated_sprite.offset.x = -target_offset.x if animated_sprite.flip_h else target_offset.x
		animated_sprite.offset.y = target_offset.y
	else:
		animated_sprite.offset = Vector2.ZERO

func change_state(new_state: State) -> void:
	current_state = new_state

	match current_state:
		State.ATTACK:
			perform_light_attack_step()

		State.DODGE:
			dodge_direction = -1.0 if animated_sprite.flip_h else 1.0
			play_animation("back_dodge")
			recent_dodge_timer = 0.45

		State.SLIDE:
			play_animation("slide")

		State.AIR_DASH:
			can_air_dash = false
			play_animation("aerial_dash")
			
			if dash_fx_sprite:
				dash_fx_sprite.flip_h = animated_sprite.flip_h
				dash_fx_sprite.play("aerial_dashFX")
			if dash_smoke_sprite:
				dash_smoke_sprite.flip_h = animated_sprite.flip_h
				dash_smoke_sprite.play("aerial_dashSMOKE")

		State.DODGE_ATTACK:
			perform_dodge_attack_step()

		State.AIR_ATTACK:
			play_animation("jump atk 2x_merged")

		State.PLUNGE_ATTACK:
			play_animation("dodge atk 3x_fall loop1")

		State.HEAL:
			play_animation("healing_merged")

		State.CROUCH:
			exiting_crouch = false
			play_animation("crouching")

func _on_animation_finished() -> void:
	if current_state == State.ATTACK:
		if attack_buffered_light:
			perform_light_attack_step()
		else:
			change_state(State.NORMAL)
	elif current_state == State.DODGE_ATTACK:
		if attack_buffered_light:
			perform_dodge_attack_step()
		else:
			change_state(State.NORMAL)
	elif current_state in [State.DODGE, State.AIR_ATTACK, State.PLUNGE_ATTACK, State.SLIDE, State.AIR_DASH, State.HURT, State.HEAL]:
		change_state(State.NORMAL)
	elif current_state == State.CROUCH and exiting_crouch:
		exiting_crouch = false
		change_state(State.NORMAL)
