extends Area2D

@onready var controls_panel: Control = get_node_or_null("../ControlCanvas/ControlsPanel")
@onready var prompt_icon: Control = get_node_or_null("PromptIcon")

var start_y: float = 0.0
var time_passed: float = 0.0
var game_started: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if prompt_icon:
		start_y = prompt_icon.position.y
		prompt_icon.hide() # Keep hidden during Main Menu

	if controls_panel:
		controls_panel.modulate.a = 0.0
		controls_panel.hide()

func _process(delta: float) -> void:
	if prompt_icon and prompt_icon.visible:
		time_passed += delta * 4.0
		prompt_icon.position.y = start_y + sin(time_passed) * 4.0

func enable_mailbox_indicator() -> void:
	game_started = true
	# Only show '!' if player is not already standing inside the mailbox trigger
	if prompt_icon and not overlaps_body(get_tree().get_first_node_in_group("player")):
		prompt_icon.show()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body is CharacterBody2D:
		if prompt_icon:
			prompt_icon.hide()

		if controls_panel:
			controls_panel.show()
			var tween = create_tween()
			tween.tween_property(controls_panel, "modulate:a", 1.0, 0.2)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body is CharacterBody2D:
		# Only show '!' again if gameplay has started
		if prompt_icon and game_started:
			prompt_icon.show()

		if controls_panel:
			var tween = create_tween()
			tween.tween_property(controls_panel, "modulate:a", 0.0, 0.2)
			tween.tween_callback(controls_panel.hide)
