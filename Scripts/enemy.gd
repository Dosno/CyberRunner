extends CharacterBody2D

@export_group("Enemy Identity")
## Set this in the Inspector to match your SpriteFrames animation prefixes
## Example: "Blood Monster_A_" or "Demon_A_"
@export var anim_prefix: String = "Blood Monster_A_"

@export_group("Combat & Stats")
@export var max_health: int = 3
@export var speed: float = 80.0
@export var patrol_distance: float = 120.0

var current_health: int
var direction: float = 1.0
var start_position_x: float
const GRAVITY: float = 900.0

enum State { PATROL, CHASE, ATTACK, HURT, DEAD }
var current_state: State = State.PATROL

var player_ref: Node2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea

func _ready() -> void:
	current_health = max_health
	start_position_x = global_position.x
	
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
		
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)

	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match current_state:
		State.PATROL:
			handle_patrol()
		State.CHASE:
			handle_chase()
		State.ATTACK:
			velocity.x = 0
		State.HURT:
			velocity.x = move_toward(velocity.x, 0, speed * delta)

	move_and_slide()

# --- STATE LOGIC ---

func handle_patrol() -> void:
	velocity.x = direction * speed
	
	if abs(global_position.x - start_position_x) >= patrol_distance or is_on_wall():
		direction *= -1.0
		
	update_sprite_facing(direction)
	play_enemy_anim("Walk")

func handle_chase() -> void:
	if not is_instance_valid(player_ref):
		current_state = State.PATROL
		return
		
	var dir_to_player = sign(player_ref.global_position.x - global_position.x)
	if dir_to_player != 0:
		direction = dir_to_player
		velocity.x = direction * (speed * 1.25)
		update_sprite_facing(direction)
		play_enemy_anim("Walk") # Uses Walk if no distinct Run clip exists

func take_damage(amount: int) -> void:
	if current_state == State.DEAD:
		return
		
	current_health -= amount
	if current_health <= 0:
		current_state = State.DEAD
		velocity.x = 0
		play_enemy_anim("Death")
	else:
		current_state = State.HURT
		velocity.x = -direction * 120.0 # Knockback
		play_enemy_anim("Hurt")

func play_enemy_anim(anim_suffix: String) -> void:
	var full_anim_name = anim_prefix + anim_suffix
	if sprite.sprite_frames.has_animation(full_anim_name):
		sprite.play(full_anim_name)

func update_sprite_facing(dir: float) -> void:
	if dir < 0:
		sprite.flip_h = true
	elif dir > 0:
		sprite.flip_h = false

# --- SIGNALS & COLLISIONS ---

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_ref = body
		if current_state != State.HURT:
			current_state = State.CHASE

func _on_detection_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null
		if current_state not in [State.DEAD, State.HURT]:
			current_state = State.PATROL
			start_position_x = global_position.x

func _on_attack_area_body_entered(body: Node2D) -> void:
	if (body.is_in_group("player") or body.name == "Player") and current_state not in [State.HURT, State.DEAD]:
		current_state = State.ATTACK
		# Alternates between Attack01 and Attack02 randomly
		var attack_type = "Attack01" if randf() > 0.5 else "Attack02"
		play_enemy_anim(attack_type)

func _on_animation_finished() -> void:
	if current_state in [State.HURT, State.ATTACK]:
		current_state = State.CHASE if player_ref else State.PATROL
	elif current_state == State.DEAD:
		queue_free()
