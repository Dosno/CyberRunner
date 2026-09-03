extends Node2D

func _ready() -> void:
	# 1. Trigger the UNDERWORLD City Sign Banner
	var city_sign_mgr = get_tree().get_first_node_in_group("city_sign_manager")
	if not city_sign_mgr:
		city_sign_mgr = get_tree().root.find_child("CitySignManager", true, false)
	
	if city_sign_mgr and city_sign_mgr.has_method("show_city"):
		city_sign_mgr.show_city("UNDERWORLD")
	else:
		print("Warning: CitySignManager node not found in Underworld scene tree.")

	# 2. Trigger the "KILL ALL ENEMIES" White Objective Banner
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		hud = get_tree().root.find_child("HUD", true, false)

	if hud and hud.has_method("show_objective"):
		hud.show_objective("KILL ALL ENEMIES", 4.0, true)
	else:
		print("Warning: HUD node not found in Underworld scene tree.")
