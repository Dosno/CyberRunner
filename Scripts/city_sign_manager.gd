extends CanvasLayer

@onready var city_sign: TextureRect = $CitySign

var city_signs = {
	"AETHEL DUSK": preload("res://Assets/CitySigns/Aethel_dusk_sign.png"),
	"NOX TOKYO": preload("res://Assets/CitySigns/Nox_tokyo_sign.png"),
	"AETHER GLOW": preload("res://Assets/CitySigns/Aether_glow_sign.png"),
	#"UNDERWORLD": preload("res://Assets/CitySigns/UNDERWORLD.png")
}

func _enter_tree() -> void:
	visible = false

func _ready() -> void:
	add_to_group("city_sign_manager")
	visible = false
	if city_sign:
		city_sign.visible = false
		city_sign.modulate.a = 0.0

func show_city(city_name: String, duration: float = 3.5) -> void:
	if not city_sign:
		return

	if not city_signs.has(city_name):
		print("City sign not found: ", city_name)
		return

	visible = true
	city_sign.texture = city_signs[city_name]
	city_sign.modulate.a = 0.0
	city_sign.visible = true

	# Fade In
	var fade_in := create_tween()
	fade_in.tween_property(city_sign, "modulate:a", 1.0, 0.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	await fade_in.finished

	# Display Hold (Now uses the duration parameter!)
	await get_tree().create_timer(duration).timeout

	# Fade Out
	var fade_out := create_tween()
	fade_out.tween_property(city_sign, "modulate:a", 0.0, 0.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
		
	await fade_out.finished
	city_sign.visible = false
	visible = false
