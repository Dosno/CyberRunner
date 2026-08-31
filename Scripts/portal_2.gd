extends Area2D

@export_file("*.tscn") var target_scene_path: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		if target_scene_path != "":
			call_deferred("change_level")

func change_level() -> void:
	get_tree().change_scene_to_file(target_scene_path)
