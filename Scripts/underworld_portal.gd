extends Area2D

@export var destination_scene: PackedScene

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Entering Underworld!")
		
		if destination_scene:
			get_tree().change_scene_to_packed(destination_scene)
		else:
			print("ERROR: No destination scene assigned!")
