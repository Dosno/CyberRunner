extends CanvasLayer

@onready var city_sign: TextureRect = $CitySign

var city_signs = {
	"AETHEL DUSK": preload("res://Assets/CitySigns/Aethel_dusk_sign.png"),
	"NOX TOKYO": preload("res://Assets/CitySigns/Nox_tokyo_sign.png"),
	"AETHER GLOW": preload("res://Assets/CitySigns/Aether_glow_sign.png")
}

func _enter_tree() -> void:
	# Hide immediately as soon as node enters scene tree
	visible = false

func _ready() -> void:
	visible = false
	if city_sign:
		city_sign.visible = false
		city_sign.modulate.a = 0.0

func show_city(city_name: String) -> void:
	if not city_sign:
		return

	if not city_signs.has(city_name):
		print("City sign not found: ", city_name)
		return

	# Enable visibility only when explicitly requested
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

	# Display Hold
	await get_tree().create_timer(1.5).timeout

	# Fade Out
	var fade_out := create_tween()
	fade_out.tween_property(city_sign, "modulate:a", 0.0, 0.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
		
	await fade_out.finished
	city_sign.visible = false
	visible = false
