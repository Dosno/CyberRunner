extends Area2D

@export var destination: Node2D
@export var destination_city: String = ""

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	print("PORTAL DETECTED: ", body.name)
	print("Is player group? ", body.is_in_group("player"))

	if body.is_in_group("player") or body.name.begins_with("Player") or body.name.begins_with("player"):
		print("TELEPORTING PLAYER!")

		if destination:
			# Teleport player to the destination node
			body.global_position = destination.global_position

			# Save destination as player's new active checkpoint for respawning on death
			if "active_checkpoint" in body:
				body.active_checkpoint = destination.global_position
				body.has_checkpoint = true
				print("CHECKPOINT UPDATED TO: ", destination.global_position)

		# Show city sign UI if assigned
		if destination_city != "":
			print("Showing city: ", destination_city)
			if has_node("/root/CitySignManager"):
				get_node("/root/CitySignManager").show_city(destination_city)
