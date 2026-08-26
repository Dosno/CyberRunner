extends Area2D

@export var destination: Node2D
@export var destination_city: String = ""

func _on_body_entered(body: Node2D) -> void:
	print("PORTAL DETECTED: ", body.name)
	print("Is player group? ", body.is_in_group("player"))

	if body.is_in_group("player"):
		print("TELEPORTING PLAYER!")

		GameManager.checkpoint_position = destination.global_position
		GameManager.has_checkpoint = true

		body.global_position = destination.global_position

		if destination_city != "":
			print("Showing city: ", destination_city)
			CitySignManager.show_city(destination_city)
