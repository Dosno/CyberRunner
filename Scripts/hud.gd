extends Control

@onready var health_bar: HBoxContainer = get_node_or_null("HealthBar")

# Screen FX Overlay References
var canvas_layer: CanvasLayer
var low_hp_rect: ColorRect
var heal_flash_rect: ColorRect
var speed_lines_rect: ColorRect
var fade_rect: ColorRect
var last_health: int = -1

# Dynamic Low HP FX Variables
var heart_pulse_timer: float = 0.0
var is_critical_hp: bool = false
var active_shake_intensity: float = 0.0

# Cooldown UI References
var heal_cd_bar: ProgressBar
var dash_cd_bar: ProgressBar

func _ready() -> void:
	# 1. Setup Canvas Layer
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	# 2. Setup Screen FX Overlays
	setup_screen_fx_overlays()

	# 3. Setup Health Bar Positioning
	if not health_bar:
		health_bar = HBoxContainer.new()
		health_bar.name = "HealthBar"
		health_bar.position = Vector2(20, 20)
		canvas_layer.add_child(health_bar)
	else:
		health_bar.get_parent().remove_child(health_bar)
		canvas_layer.add_child(health_bar)
		health_bar.position = Vector2(20, 20)

	# 4. Setup Cooldown Indicators
	setup_cooldown_ui()

	var player = get_tree().get_first_node_in_group("player")
	if player:
		last_health = player.current_health
		setup_health_display(player.max_health)
		update_health_display(player.current_health)
		
		# Hide HUD if starting in MENU state
		if "current_state" in player and player.current_state == player.State.MENU:
			hide_hud()

	# Run automated scene entry fade-in
	fade_in_from_black(1.0)

func show_hud() -> void:
	if canvas_layer:
		canvas_layer.visible = true

func hide_hud() -> void:
	if canvas_layer:
		canvas_layer.visible = false

func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")

	# Critical Heartbeat Pulse Animation (1 HP)
	if is_critical_hp and low_hp_rect:
		heart_pulse_timer += delta * 6.0
		var pulse_alpha = lerp(0.35, 0.75, (sin(heart_pulse_timer) + 1.0) / 2.0)
		low_hp_rect.color.a = pulse_alpha

	# Stage-Based Continuous Low HP Screen Shake
	if active_shake_intensity > 0.0 and player and "camera" in player and player.camera:
		player.camera.offset = Vector2(
			randf_range(-active_shake_intensity, active_shake_intensity),
			randf_range(-active_shake_intensity, active_shake_intensity)
		)

	# Real-Time Cooldown UI Tracker
	if player:
		# Update Heal Cooldown Progress (5 Seconds)
		if heal_cd_bar and "heal_cooldown_timer" in player and "HEAL_COOLDOWN_TIME" in player:
			if player.heal_cooldown_timer > 0.0:
				var progress = 1.0 - (player.heal_cooldown_timer / player.HEAL_COOLDOWN_TIME)
				heal_cd_bar.value = progress * 100.0
				heal_cd_bar.modulate = Color(1.0, 0.3, 0.1)
			else:
				heal_cd_bar.value = 100.0
				heal_cd_bar.modulate = Color(0.0, 1.0, 0.5)

		# Update Dash Cooldown Progress (3 Seconds)
		if dash_cd_bar and "dash_cooldown_timer" in player and "DASH_COOLDOWN_TIME" in player:
			if player.dash_cooldown_timer > 0.0:
				var progress = 1.0 - (player.dash_cooldown_timer / player.DASH_COOLDOWN_TIME)
				dash_cd_bar.value = progress * 100.0
				dash_cd_bar.modulate = Color(0.2, 0.4, 0.8)
			else:
				dash_cd_bar.value = 100.0
				dash_cd_bar.modulate = Color(0.0, 0.8, 1.0)

func setup_screen_fx_overlays() -> void:
	# 1. Low Health Blood Screen Filter
	low_hp_rect = ColorRect.new()
	low_hp_rect.name = "LowHealthOverlay"
	low_hp_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	low_hp_rect.color = Color(0.85, 0.0, 0.1, 0.0)
	low_hp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(low_hp_rect)

	# 2. Speed Lines FX Overlay Shader
	speed_lines_rect = ColorRect.new()
	speed_lines_rect.name = "SpeedLinesOverlay"
	speed_lines_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_lines_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader = load("res://Shaders/speed_lines.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("intensity", 0.0)
		speed_lines_rect.material = mat
	canvas_layer.add_child(speed_lines_rect)

	# 3. Heal Accent Flash Overlay
	heal_flash_rect = ColorRect.new()
	heal_flash_rect.name = "HealFlashOverlay"
	heal_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heal_flash_rect.color = Color(0.0, 1.0, 0.5, 0.0)
	heal_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(heal_flash_rect)

	# 4. Global Scene FadeRect Overlay
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0) # Start transparent
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(fade_rect)

func setup_cooldown_ui() -> void:
	var cd_container = HBoxContainer.new()
	cd_container.name = "CooldownContainer"
	cd_container.position = Vector2(20, 52)
	canvas_layer.add_child(cd_container)

	# Heal Cooldown Bar
	var heal_wrapper = VBoxContainer.new()
	var heal_label = Label.new()
	heal_label.text = "[E] HEAL"
	heal_label.add_theme_font_size_override("font_size", 10)
	heal_label.modulate = Color(0.8, 0.8, 0.8)

	heal_cd_bar = ProgressBar.new()
	heal_cd_bar.custom_minimum_size = Vector2(80, 6)
	heal_cd_bar.show_percentage = false
	heal_cd_bar.value = 100.0

	heal_wrapper.add_child(heal_label)
	heal_wrapper.add_child(heal_cd_bar)
	cd_container.add_child(heal_wrapper)

	# Dash Cooldown Bar
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)

	var dash_wrapper = VBoxContainer.new()
	var dash_label = Label.new()
	dash_label.text = "DASH"
	dash_label.add_theme_font_size_override("font_size", 10)
	dash_label.modulate = Color(0.8, 0.8, 0.8)

	dash_cd_bar = ProgressBar.new()
	dash_cd_bar.custom_minimum_size = Vector2(60, 6)
	dash_cd_bar.show_percentage = false
	dash_cd_bar.value = 100.0

	dash_wrapper.add_child(dash_label)
	dash_wrapper.add_child(dash_cd_bar)
	margin.add_child(dash_wrapper)
	cd_container.add_child(margin)

# --- TRANSITION & FX FUNCTIONS ---

func trigger_speed_lines_burst(duration: float = 1.0) -> void:
	if not speed_lines_rect or not speed_lines_rect.material:
		return
	var mat = speed_lines_rect.material as ShaderMaterial
	
	var tween = create_tween()
	mat.set_shader_parameter("intensity", 1.0)
	tween.tween_property(mat, "shader_parameter/intensity", 0.0, duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

func fade_in_from_black(duration: float = 0.8) -> void:
	if not fade_rect:
		return
	fade_rect.color.a = 1.0 # Force full black
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

func setup_health_display(max_hp: int) -> void:
	if not health_bar:
		return

	for child in health_bar.get_children():
		child.queue_free()

	for i in range(max_hp):
		var hp_block = ColorRect.new()
		hp_block.name = "HPBlock_" + str(i)
		hp_block.custom_minimum_size = Vector2(32, 24)
		hp_block.color = Color(1.0, 0.1, 0.3)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_child(hp_block)
		
		health_bar.add_child(margin)

func update_health_display(current_hp: int) -> void:
	if not health_bar:
		return

	if health_bar.get_child_count() == 0:
		var player = get_tree().get_first_node_in_group("player")
		var max_hp = player.max_health if player else 5
		setup_health_display(max_hp)

	if last_health != -1 and current_hp > last_health:
		trigger_heal_flash()
	last_health = current_hp

	var children = health_bar.get_children()
	for i in range(children.size()):
		var margin = children[i] as MarginContainer
		if margin and margin.get_child_count() > 0:
			var block = margin.get_child(0) as ColorRect
			if block:
				if i < current_hp:
					block.color = Color(1.0, 0.1, 0.3)
				else:
					block.color = Color(0.2, 0.05, 0.1, 0.5)

	update_low_health_filter(current_hp)

func update_low_health_filter(current_hp: int) -> void:
	if not low_hp_rect:
		return

	if current_hp <= 1 and current_hp > 0:
		is_critical_hp = true
		active_shake_intensity = 2.0
	else:
		is_critical_hp = false
		var target_alpha: float = 0.0
		
		match current_hp:
			2:
				target_alpha = 0.30
				active_shake_intensity = 1.2
			3:
				target_alpha = 0.18
				active_shake_intensity = 0.6
			_:
				target_alpha = 0.0
				active_shake_intensity = 0.0

		var tween = create_tween()
		tween.tween_property(low_hp_rect, "color:a", target_alpha, 0.3)

func trigger_heal_flash() -> void:
	if not heal_flash_rect:
		return

	var tween = create_tween()
	heal_flash_rect.color.a = 0.35
	tween.tween_property(heal_flash_rect, "color:a", 0.0, 1.0)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
