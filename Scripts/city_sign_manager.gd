extends CanvasLayer

@onready var city_sign: TextureRect = $CitySign

var city_signs = {
	"AETHEL DUSK": preload("res://Assets/CitySigns/Aethel_dusk_sign.png"),
	"NOX TOKYO": preload("res://Assets/CitySigns/Nox_tokyo_sign.png"),
	"AETHER GLOW": preload("res://Assets/CitySigns/Aether_glow_sign.png")
}

func _ready() -> void:
	city_sign.modulate.a = 0.0

func show_city(city_name: String) -> void:
	if not city_signs.has(city_name):
		print("City sign not found: ", city_name)
		return

	city_sign.texture = city_signs[city_name]
	city_sign.modulate.a = 0.0

	var fade_in := create_tween()
	fade_in.tween_property(city_sign, "modulate:a", 1.0, 0.6)

	await fade_in.finished

	await get_tree().create_timer(1.5).timeout

	var fade_out := create_tween()
	fade_out.tween_property(city_sign, "modulate:a", 0.0, 0.6)
