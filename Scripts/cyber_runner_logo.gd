extends Control

var float_timer: float = 0.0

func _process(delta: float) -> void:
	if visible and modulate.a > 0.0:
		# Floating hover animation while in menu
		float_timer += delta * 2.0
		position.y += sin(float_timer) * 0.3

func fade_out_and_hide() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished
	hide()
