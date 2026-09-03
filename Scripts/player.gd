extends CharacterBody2D

# Movement Speeds
const WALK_SPEED = 120.0
const RUN_SPEED = 180.0
const CROUCH_SPEED = 60.0
const SLIDE_SPEED = 280.0
const DODGE_SPEED = 280.0
const AIR_DASH_SPEED = 300.0
const LUNGE_SPEED = 280.0
const CLIMB_SPEED = 100.0
const JUMP_VELOCITY = -300.0
const WALL_JUMP_VELOCITY = Vector2(250.0, -280.0)

# Health Stats & Invincibility
@export var max_health: int = 5
var current_health: int
const INVINCIBILITY_TIME: float = 1.0
var invincibility_timer: float = 0.0

var hurt_timer: float = 0.0
const HURT_DURATION: float = 0.25

# Heal Cooldown Variables
const HEAL_COOLDOWN_TIME: float = 5.0
var heal_cooldown_timer: float = 0.0

# Dash Cooldown Variables
const DASH_COOLDOWN_TIME: float = 3.0
var dash_cooldown_timer: float = 0.0

# Attack Damage Variable
var current_attack_damage: int = 10

# Camera Look-Ahead Settings
const LOOK_AHEAD_DISTANCE = 40.0
const LOOK_AHEAD_SPEED = 3.0

# Menu Camera & Zoom Settings
var menu_hover_timer: float = 0.0
const MENU_ZOOM = Vector2(4.9, 4.9)
const NORMAL_ZOOM = Vector2(3.5, 3.5)

# Screen Shake Variables
var shake_intensity: float = 0.0
var shake_decay: float = 15.0

# Respawn & Checkpoint Variables
var stage_start_position: Vector2 = Vector2.ZERO
var active_checkpoint: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false
var is_respawning: bool = false

# ==============================================================================
# ANIMATION OFFSET DICTIONARY
# ==============================================================================
const ANIM_OFFSETS: Dictionary = {
	"idle": Vector2(0, 0),
	"walk": Vector2(0, -1),
	"run": Vector2(0, 5),
	"crouching": Vector2(0, 3),
	"slide": Vector2(0, -5),

	"jump": Vector2(0, 0),
	"double jump_forward": Vector2(0, 0),
	"double jump_vertical": Vector2(0, 0),
	"aerial_dash": Vector2(0, 0),

	"1x atk_merged": Vector2(-55, -3),
	"2x 1 atk_merged": Vector2(-40, -10),
	"2x 2 atk_merged": Vector2(-40, -10),
	"3x atk_merged": Vector2(-30, -15),

	"back_dodge": Vector2(0, 0),
	"dodge atk 1x_merged": Vector2(30, 0),
	"dodge atk 1x_merged2": Vector2(30, 0),
	"dodge atk 2x_merged": Vector2(30, 0),
	"dodge atk 3x_merged": Vector2(-30, -45),

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
	MENU, NORMAL, CROUCH, SLIDE, ATTACK, DODGE, AIR_ATTACK, DODGE_ATTACK,
	PLUNGE_ATTACK, AIR_DASH, WALL_SLIDE, LEDGE_HANG, LADDER, HURT, HEAL, DEAD
}
var current_state: State = State.MENU

var is_walking_toggle: bool = false
var exiting_crouch: bool = false
var can_double_jump: bool = true
var can_air_dash: bool = true

# Coyote Time
const COYOTE_TIME: float = 0.15
var coyote_timer: float = 0.0

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

# Hitbox & Collision Shape References
@onready var sword_hitbox: Area2D = get_node_or_null("Hitbox")
@onready var hitbox_right: CollisionShape2D = get_node_or_null("Hitbox/CollisionShapeRight")
@onready var hitbox_left: CollisionShape2D = get_node_or_null("Hitbox/CollisionShapeLeft")

func _ready() -> void:
	current_health = max_health
	stage_start_position = global_position
	add_to_group("player")
	
	# Detect active scene file
	var current_scene_file = ""
	if get_tree().current_scene:
		current_scene_file = get_tree().current_scene.scene_file_path.get_file()

	# Only start in MENU state if loading game.tscn
	if current_scene_file == "game.tscn":
		current_state = State.MENU
		camera.zoom = MENU_ZOOM
	else:
		current_state = State.NORMAL
		camera.zoom = NORMAL_ZOOM

	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 3.0
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	
	floor_snap_length = 8.0
	apply_floor_snap()
	
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

	if sword_hitbox:
		disable_sword_hitbox()
		if not sword_hitbox.body_entered.is_connected(_on_sword_hitbox_body_entered):
			sword_hitbox.body_entered.connect(_on_sword_hitbox_body_entered)
		if not sword_hitbox.area_entered.is_connected(_on_sword_hitbox_area_entered):
			sword_hitbox.area_entered.connect(_on_sword_hitbox_area_entered)

	# Initialize HUD on spawn
	update_hud_display()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("walk_toggle"):
		is_walking_toggle = !is_walking_toggle

func _physics_process(delta: float) -> void:
	# --- MAIN MENU STATE OVERRIDE ---
	if current_state == State.MENU:
		handle_menu_state(delta)
		return

	# --- SCREEN SHAKE PROCESSING ---
	if shake_intensity > 0.0:
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
		camera.offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)

	if current_state == State.DEAD or is_respawning:
		return

	# Handle Cooldown Timers
	if heal_cooldown_timer > 0.0:
		heal_cooldown_timer -= delta

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	# Handle Invincibility Blinking
	if invincibility_timer > 0.0:
		invincibility_timer -= delta
		animated_sprite.visible = fmod(invincibility_timer, 0.2) > 0.1
	else:
		animated_sprite.visible = true

	# Handle Hurt State Timer Recovery
	if current_state == State.HURT:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			change_state(State.NORMAL)

	# Combo window timer countdown
	if combo_step > 0 and current_state != State.ATTACK:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_step = 0

	if recent_dodge_timer > 0.0:
		recent_dodge_timer -= delta
	else:
		if current_state != State.DODGE_ATTACK:
			dodge_combo_step = 0

	# Input Buffering
	if current_state in [State.ATTACK, State.DODGE_ATTACK]:
		if Input.is_action_just_pressed("attack_heavy"):
			perform_heavy_attack()
		elif Input.is_action_just_pressed("attack_light"):
			attack_buffered_light = true

	# Gravity
	if not is_on_floor() and current_state not in [State.AIR_DASH, State.WALL_SLIDE, State.LEDGE_HANG, State.LADDER, State.PLUNGE_ATTACK]:
		velocity += get_gravity() * delta
	elif current_state == State.PLUNGE_ATTACK:
		velocity.y = 500.0

	# Ground Checks
	if is_on_floor():
		can_double_jump = true
		if dash_cooldown_timer <= 0.0:
			can_air_dash = true
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta

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

# --- MAIN MENU ROUTINES ---

func handle_menu_state(delta: float) -> void:
	play_animation("idle")
	velocity = Vector2.ZERO

	# Camera hover sway around player
	menu_hover_timer += delta * 1.5
	var hover_offset = Vector2(
		cos(menu_hover_timer) * 15.0,
		sin(menu_hover_timer * 0.8) * 10.0
	)
	camera.offset = camera.offset.lerp(hover_offset, 2.0 * delta)

	# Press Spacebar to Start Game
	if Input.is_action_just_pressed("ui_accept"):
		start_game_from_menu()

func start_game_from_menu() -> void:
	# 1. Reveal HUD CanvasLayer when entering gameplay
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud and hud.has_method("show_hud"):
		hud.show_hud()

	# 2. Fade out the CyberRunner logo
	var logo_node = get_node_or_null("../CanvasLayer/CyberRunnerLogo")
	if not logo_node:
		logo_node = get_tree().root.find_child("CyberRunnerLogo", true, false)
	
	if logo_node and logo_node.has_method("fade_out_and_hide"):
		logo_node.fade_out_and_hide()

	# 3. Trigger City Sign banner display on Spacebar press
	var city_sign_mgr = get_node_or_null("../CanvasLayer/CitySignManager")
	if not city_sign_mgr:
		city_sign_mgr = get_tree().root.find_child("CitySignManager", true, false)
	
	if city_sign_mgr and city_sign_mgr.has_method("show_city"):
		city_sign_mgr.show_city("AETHEL DUSK")

	# 4. Smoothly zoom out camera to normal gameplay view
	var tween = create_tween().set_parallel(true)
	tween.tween_property(camera, "zoom", NORMAL_ZOOM, 1.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "offset", Vector2.ZERO, 1.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	await tween.finished
	change_state(State.NORMAL)

	# 5. Trigger Objective Banner (White text, custom positioning)
	if hud and hud.has_method("show_objective"):
		hud.show_objective("REACH THE LAST PORTAL TO ESCAPE", 4.0)

# --- STATE HANDLERS ---

func handle_normal_state(delta: float) -> void:
	# Trigger Heal State via Input 'heal' (E key) when damaged, grounded, and off cooldown
	if InputMap.has_action("heal") and Input.is_action_just_pressed("heal") and is_on_floor() and current_health < max_health and heal_cooldown_timer <= 0.0:
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

	if Input.is_action_just_pressed("dodge") and not is_on_floor() and can_air_dash and dash_cooldown_timer <= 0.0:
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
			change_state(State.DODGE_ATTACK)
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
		if is_on_floor() or coyote_timer > 0.0:
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0.0
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
		play_animation("crouching")
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
	var facing_dir = 1.0 if animated_sprite.flip_h else -1.0
	velocity.x = facing_dir * SLIDE_SPEED

func handle_attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED * 2.0 * delta)

func handle_dodge_state(_delta: float) -> void:
	if Input.is_action_just_pressed("attack_heavy") or Input.is_action_just_pressed("attack_light"):
		change_state(State.DODGE_ATTACK)
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
		trigger_hit_impact(6.0, 0.03)

func handle_air_dash_state(_delta: float) -> void:
	velocity.y = 0
	var facing_dir = 1.0 if animated_sprite.flip_h else -1.0
	velocity.x = facing_dir * AIR_DASH_SPEED

func handle_wall_slide_state(_delta: float) -> void:
	velocity.y = 60.0
	play_animation("wall slide")

	if Input.is_action_just_pressed("ui_accept"):
		var wall_dir = 1.0 if animated_sprite.flip_h else -1.0
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
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED * 6.0 * delta)

func handle_heal_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED * 4.0 * delta)

func update_hud_display() -> void:
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud and hud.has_method("update_health_display"):
		hud.update_health_display(current_health)

func take_damage(amount: int = 1, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if current_state in [State.HURT, State.DEAD] or invincibility_timer > 0.0 or is_respawning:
		return

	trigger_hit_impact(5.0, 0.0)

	invincibility_timer = INVINCIBILITY_TIME
	hurt_timer = HURT_DURATION
	current_health -= amount
	
	# Keep HUD updated
	update_hud_display()

	if current_health <= 0:
		current_state = State.DEAD
		velocity = Vector2.ZERO
		play_animation("hard hit")
		start_death_respawn_sequence()
	else:
		change_state(State.HURT)
		
		var knock_dir = 1.0
		if attacker_pos != Vector2.ZERO:
			knock_dir = sign(global_position.x - attacker_pos.x)
			if knock_dir == 0:
				knock_dir = -1.0 if animated_sprite.flip_h else 1.0
		else:
			knock_dir = -1.0 if animated_sprite.flip_h else 1.0

		velocity.x = knock_dir * 300.0
		velocity.y = -150.0
		play_animation("normal hit")

# --- RESPAWN & FADE SEQUENCE ---

func start_death_respawn_sequence() -> void:
	is_respawning = true
	
	var fade_rect: ColorRect = get_node_or_null("../CanvasLayer/FadeRect")
	if not fade_rect:
		fade_rect = get_tree().root.find_child("FadeRect", true, false)

	# 1. Fade screen to Black
	if fade_rect:
		var tween = create_tween()
		tween.tween_property(fade_rect, "modulate:a", 1.0, 1.2)
		await tween.finished
	else:
		await get_tree().create_timer(1.2).timeout

	# 2. Respawn at active Portal Checkpoint
	if has_checkpoint:
		global_position = active_checkpoint
	else:
		global_position = stage_start_position

	velocity = Vector2.ZERO
	current_health = max_health
	heal_cooldown_timer = 0.0
	dash_cooldown_timer = 0.0
	update_hud_display()

	# 3. Fade screen back to Transparent
	if fade_rect:
		var tween_in = create_tween()
		tween_in.tween_property(fade_rect, "modulate:a", 0.0, 0.8)

	# 4. Perform Character Blinks
	for i in range(5):
		animated_sprite.visible = false
		await get_tree().create_timer(0.12).timeout
		animated_sprite.visible = true
		await get_tree().create_timer(0.12).timeout

	is_respawning = false
	change_state(State.NORMAL)

# --- ATTACK ROUTINES ---

func perform_light_attack_step() -> void:
	current_state = State.ATTACK
	attack_buffered_light = false

	var anim = "1x atk_merged"
	current_attack_damage = 10

	if combo_step == 1:
		anim = "2x 1 atk_merged"
		current_attack_damage = 12
	elif combo_step == 2:
		anim = "2x 2 atk_merged"
		current_attack_damage = 18

	play_animation(anim, true)
	enable_sword_hitbox()

	combo_step = (combo_step + 1) % 3
	combo_timer = COMBO_WINDOW

func perform_heavy_attack() -> void:
	current_state = State.ATTACK
	attack_buffered_light = false

	current_attack_damage = 20
	play_animation("3x atk_merged", true)
	enable_sword_hitbox()
	combo_step = 0
	trigger_hit_impact(2.0, 0.0)

func perform_dodge_attack_step() -> void:
	current_state = State.DODGE_ATTACK
	attack_buffered_light = false

	var facing_dir = 1.0 if animated_sprite.flip_h else -1.0
	velocity.x = facing_dir * LUNGE_SPEED

	var anim = "dodge atk 1x_merged"
	current_attack_damage = 12

	if dodge_combo_step == 1:
		anim = "dodge atk 2x_merged"
		current_attack_damage = 15
	elif dodge_combo_step == 2:
		anim = "dodge atk 3x_merged"
		current_attack_damage = 25

	play_animation(anim, true)
	enable_sword_hitbox()

	dodge_combo_step = (dodge_combo_step + 1) % 3
	recent_dodge_timer = 0.6

# --- HITBOX MANAGEMENT ---

func enable_sword_hitbox() -> void:
	if sword_hitbox:
		sword_hitbox.monitoring = true
		if animated_sprite.flip_h:
			if hitbox_left: hitbox_left.disabled = true
			if hitbox_right: hitbox_right.disabled = false
		else:
			if hitbox_left: hitbox_left.disabled = false
			if hitbox_right: hitbox_right.disabled = true

func disable_sword_hitbox() -> void:
	if sword_hitbox:
		sword_hitbox.monitoring = false
	if hitbox_left: hitbox_left.disabled = true
	if hitbox_right: hitbox_right.disabled = true

func _on_sword_hitbox_body_entered(body: Node2D) -> void:
	_apply_damage_to_target(body)

func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	_apply_damage_to_target(area)
	_apply_damage_to_target(area.get_parent())

func trigger_hit_impact(intensity: float = 4.0, freeze_duration: float = 0.05) -> void:
	shake_intensity = intensity

	if freeze_duration > 0.0:
		Engine.time_scale = 0.05
		await get_tree().create_timer(freeze_duration * 0.05, true, false, true).timeout
		Engine.time_scale = 1.0

func _apply_damage_to_target(target: Node) -> void:
	if target and target != self and target.has_method("take_damage"):
		target.take_damage(current_attack_damage)
		var shake = 3.0 if current_attack_damage < 18 else 7.0
		var freeze = 0.04 if current_attack_damage < 18 else 0.08
		trigger_hit_impact(shake, freeze)

# --- HELPERS ---

func update_facing_and_camera(direction: float, delta: float) -> void:
	if direction < 0:
		animated_sprite.flip_h = false
		camera.offset = camera.offset.lerp(Vector2(-LOOK_AHEAD_DISTANCE, 0), LOOK_AHEAD_SPEED * delta)
	elif direction > 0:
		animated_sprite.flip_h = true
		camera.offset = camera.offset.lerp(Vector2(LOOK_AHEAD_DISTANCE, 0), LOOK_AHEAD_SPEED * delta)

	apply_animation_offset(animated_sprite.animation)

func play_animation(anim_name: String, force_restart: bool = false) -> void:
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		return

	if animated_sprite.animation != anim_name or not animated_sprite.is_playing() or force_restart:
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
	if current_state == new_state:
		return

	disable_sword_hitbox()
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
			dash_cooldown_timer = DASH_COOLDOWN_TIME # Start 3-second dash cooldown
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
	disable_sword_hitbox()

	if current_state == State.HEAL:
		if current_health < max_health:
			current_health = min(current_health + 1, max_health)
			update_hud_display()
		# Start 5-second cooldown timer after heal finishes
		heal_cooldown_timer = HEAL_COOLDOWN_TIME
		change_state(State.NORMAL)
	elif current_state == State.ATTACK:
		if attack_buffered_light:
			perform_light_attack_step()
		else:
			change_state(State.NORMAL)
	elif current_state == State.DODGE_ATTACK:
		if attack_buffered_light:
			perform_dodge_attack_step()
		else:
			change_state(State.NORMAL)
	elif current_state in [State.HURT, State.DODGE, State.AIR_ATTACK, State.PLUNGE_ATTACK, State.SLIDE, State.AIR_DASH]:
		change_state(State.NORMAL)
	elif current_state == State.CROUCH and exiting_crouch:
		exiting_crouch = false
		change_state(State.NORMAL)
