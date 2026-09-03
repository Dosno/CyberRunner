extends Area2D

@export var end_message: String = 'GIRL: "Dosno said this game is unfinished, Thank you for becoming the Beta Tester!"'

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var hud = get_tree().root.find_child("HUD", true, false)
		if hud and hud.has_method("show_objective"):
			# Pass a very long duration (or handle persistent visibility)
			hud.show_objective(end_message, 999.0, false)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		var hud = get_tree().root.find_child("HUD", true, false)
		if hud and "objective_label" in hud and hud.objective_label:
			# Instantly fade out when walking away
			var tween = create_tween()
			tween.tween_property(hud.objective_label, "modulate:a", 0.0, 0.4)
