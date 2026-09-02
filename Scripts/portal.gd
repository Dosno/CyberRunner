extends Area2D

@export var destination: Node2D
@export var destination_city: String = ""

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Ignore portal collisions while player is in the Main Menu state
	if "current_state" in body and body.current_state == 0: # State.MENU is 0
		return

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
			
			# Find CitySignManager in Scene Tree or Autoload
			var city_mgr = get_node_or_null("/root/CitySignManager")
			if not city_mgr:
				city_mgr = get_tree().root.find_child("CitySignManager", true, false)

			if city_mgr and city_mgr.has_method("show_city"):
				city_mgr.show_city(destination_city)
