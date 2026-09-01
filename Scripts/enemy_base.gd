extends CharacterBody2D

# Preload damage number scene from your Scenes folder
const DAMAGE_NUMBER_SCENE = preload("res://Scenes/damage_number.tscn")

# Stats
@export var max_health: int = 50
var current_health: int
@export var speed: float = 80.0

@export var anim_prefix: String = ""
@export var attack_impact_frame: int = 1

# Cooldown between monster attacks
var attack_cooldown_timer: float = 0.0
const ATTACK_COOLDOWN: float = 1.2

# State Machine
enum State { IDLE, CHASE, ATTACK, HURT, DEAD }
var current_state: State = State.IDLE

var player_ref: CharacterBody2D = null

# Node References
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var attack_area: Area2D = get_node_or_null("AttackArea")
@onready var attack_shape_right: CollisionShape2D = get_node_or_null("AttackArea/CollisionShapeRight")
@onready var attack_shape_left: CollisionShape2D = get_node_or_null("AttackArea/CollisionShapeLeft")
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")

func _ready() -> void:
	current_health = max_health
	add_to_group("enemy")

	if anim_prefix.is_empty():
		var clean_node_name = RegEx.create_from_string("[0-9]+$").sub(name, "")
		anim_prefix = clean_node_name + "_"

	enable_attack_shapes()

	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
		if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
			animated_sprite.frame_changed.connect(_on_frame_changed)

	if detection_area:
		if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
			detection_area.body_entered.connect(_on_detection_area_body_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
			detection_area.body_exited.connect(_on_detection_area_body_exited)

	if attack_area:
		if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
			attack_area.body_entered.connect(_on_attack_area_body_entered)

func _physics_process(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if current_state in [State.DEAD, State.HURT, State.ATTACK]:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 5.0)
		move_and_slide()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if current_state == State.CHASE and player_ref:
		var dir = (player_ref.global_position.x - global_position.x)
		if abs(dir) > 10.0:
			velocity.x = sign(dir) * speed
			update_facing(dir)
			play_enemy_anim("Walk")
		else:
			velocity.x = 0
			play_enemy_anim("Idle")
			
		_check_in_attack_range()
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		if current_state == State.IDLE:
			play_enemy_anim("Idle")

	move_and_slide()

# --- DAMAGE & HEALTH ---

func take_damage(amount: int = 10) -> void:
	if current_state == State.DEAD:
		return

	current_health -= amount

	# Spawn Damage Number above the monster
	if DAMAGE_NUMBER_SCENE:
		var dmg_num = DAMAGE_NUMBER_SCENE.instantiate()
		get_tree().root.add_child(dmg_num)
		dmg_num.global_position = global_position + Vector2(randf_range(-8, 8), -25)
		dmg_num.setup(amount, amount >= 18)
	
	if current_health <= 0:
		current_state = State.DEAD
		velocity = Vector2.ZERO
		play_enemy_anim("Death")
	else:
		current_state = State.HURT
		var knockback_dir = -1.0 if (animated_sprite and animated_sprite.flip_h) else 1.0
		velocity.x = knockback_dir * 120.0
		play_enemy_anim("Hurt")

# --- SIGNALS & HELPERS ---

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player") or body.name.begins_with("player"):
		player_ref = body as CharacterBody2D
		if current_state != State.DEAD:
			current_state = State.CHASE

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null
		if current_state != State.DEAD:
			current_state = State.IDLE

func _on_attack_area_body_entered(body: Node2D) -> void:
	if (body.is_in_group("player") or body.name.begins_with("Player") or body.name.begins_with("player")) and current_state not in [State.HURT, State.DEAD]:
		trigger_attack()

func _check_in_attack_range() -> void:
	if attack_area and attack_cooldown_timer <= 0.0 and current_state not in [State.ATTACK, State.HURT, State.DEAD]:
		for body in attack_area.get_overlapping_bodies():
			if body.is_in_group("player") or body.name.begins_with("Player") or body.name.begins_with("player"):
				trigger_attack()
				break

func trigger_attack() -> void:
	if attack_cooldown_timer <= 0.0:
		current_state = State.ATTACK
		velocity.x = 0
		play_enemy_anim("Attack01")

func _on_frame_changed() -> void:
	if current_state == State.ATTACK and animated_sprite and animated_sprite.frame == attack_impact_frame:
		if attack_area:
			for body in attack_area.get_overlapping_bodies():
				if (body.is_in_group("player") or body.name.begins_with("Player") or body.name.begins_with("player")) and body.has_method("take_damage"):
					body.take_damage(1, global_position)

func enable_attack_shapes() -> void:
	if attack_shape_left: attack_shape_left.disabled = false
	if attack_shape_right: attack_shape_right.disabled = false

func update_facing(dir: float) -> void:
	if animated_sprite:
		if dir < 0:
			animated_sprite.flip_h = true
		elif dir > 0:
			animated_sprite.flip_h = false

func play_enemy_anim(action: String) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	var full_anim_name = anim_prefix + action
	if not animated_sprite.sprite_frames.has_animation(full_anim_name):
		full_anim_name = action

	if animated_sprite.sprite_frames.has_animation(full_anim_name):
		if animated_sprite.animation != full_anim_name or not animated_sprite.is_playing():
			animated_sprite.play(full_anim_name)

func _on_animation_finished() -> void:
	if current_state == State.DEAD:
		queue_free()
	elif current_state == State.ATTACK:
		attack_cooldown_timer = ATTACK_COOLDOWN
		if player_ref:
			current_state = State.CHASE
		else:
			current_state = State.IDLE
	elif current_state == State.HURT:
		if player_ref:
			current_state = State.CHASE
		else:
			current_state = State.IDLE
