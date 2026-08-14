extends Area2D

@export var destination: Node2D
@export var destination_city: String = ""

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Save this portal's destination as the new checkpoint
		GameManager.checkpoint_position = destination.global_position
		GameManager.has_checkpoint = true

		# Teleport player
		body.global_position = destination.global_position

		# Show city sign
		if destination_city != "":
			print("CitySignManager = ", CitySignManager)
			CitySignManager.show_city(destination_city)
