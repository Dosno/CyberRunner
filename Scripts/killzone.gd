extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		print("PLAYER DIED!")

		if GameManager.has_checkpoint:
			body.global_position = GameManager.checkpoint_position
			body.velocity = Vector2.ZERO
		else:
			get_tree().reload_current_scene()
