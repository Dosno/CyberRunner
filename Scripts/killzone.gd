extends Area2D

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Only target the player (ignores enemies that fall in)
	if body.is_in_group("player") or body.name.begins_with("Player") or body.name.begins_with("player"):
		print("PLAYER FELL IN KILLZONE!")
		if body.has_method("take_damage"):
			# Deal max health damage to trigger the death animation, black fade, and 5-blink respawn
			var lethal_damage: int = 999
			if "max_health" in body:
				lethal_damage = body.max_health
			
			body.take_damage(lethal_damage, global_position)
