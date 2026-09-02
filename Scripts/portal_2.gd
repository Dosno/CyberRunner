extends Area2D

@export_file("*.tscn") var target_scene_path: String = ""

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Ignore level transitions while in Main Menu state
	if "current_state" in body and body.current_state == 0:
		return

	if body.is_in_group("player") or body.name.begins_with("Player") or body.name.begins_with("player"):
		if target_scene_path != "":
			call_deferred("change_level")

func change_level() -> void:
	get_tree().change_scene_to_file(target_scene_path)
