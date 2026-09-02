extends Control

# Manual Offset Controllers (Tweak these in the Inspector!)
@export var prompt_offset: Vector2 = Vector2(180, 220)
@export var credits_offset: Vector2 = Vector2(180, 260)

var float_timer: float = 0.0
@onready var start_prompt: Label = get_node_or_null("StartPrompt")
@onready var credits_label: Label = get_node_or_null("CreditsLabel")

func _ready() -> void:
	# 1. SETUP 'PRESS SPACEBAR TO START' PROMPT
	if not start_prompt:
		start_prompt = Label.new()
		start_prompt.name = "StartPrompt"
		start_prompt.text = "[ PRESS SPACEBAR TO START ]"
		start_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		start_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		var settings = LabelSettings.new()
		settings.font_size = 45
		settings.font_color = Color(0.0, 1.0, 1.0) # Bright Cyan
		settings.outline_size = 4
		settings.outline_color = Color(0.0, 0.0, 0.0)
		start_prompt.label_settings = settings
		
		# Set node top-left as independent and manual
		start_prompt.top_level = false
		start_prompt.custom_minimum_size = Vector2(400, 40)
		add_child(start_prompt)

	# 2. SETUP CREDITS LABEL
	if not credits_label:
		credits_label = Label.new()
		credits_label.name = "CreditsLabel"
		credits_label.text = "Created by: Drenz Gabriel Tabio"
		credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		var credit_settings = LabelSettings.new()
		credit_settings.font_size = 35
		credit_settings.font_color = Color(1.0, 1.0, 1.0, 1.0) # Pink/Magenta
		credit_settings.outline_size = 4
		credit_settings.outline_color = Color(0.0, 0.0, 0.0)
		credits_label.label_settings = credit_settings
		
		credits_label.top_level = false
		credits_label.custom_minimum_size = Vector2(400, 30)
		add_child(credits_label)

	# Apply manual coordinates
	start_prompt.position = prompt_offset
	credits_label.position = credits_offset

	_animate_pulse_prompt()

func _animate_pulse_prompt() -> void:
	if not start_prompt:
		return
		
	var tween = create_tween().set_loops()
	tween.tween_property(start_prompt, "modulate:a", 0.3, 0.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(start_prompt, "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	if visible and modulate.a > 0.0:
		float_timer += delta * 2.0
		position.y += sin(float_timer) * 0.3

func fade_out_and_hide() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished
	hide()
