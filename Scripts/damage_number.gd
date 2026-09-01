extends Label

func setup(amount: int, is_critical: bool = false) -> void:
	text = str(amount)
	
	# Style options
	if is_critical:
		modulate = Color(1.0, 0.2, 0.2) # Red for high/heavy damage
		scale = Vector2(1.3, 1.3)
	else:
		modulate = Color(1.0, 0.9, 0.3) # Yellow for regular light hits

	# Animate float up and fade out
	var tween = create_tween().set_parallel(true)
	
	tween.tween_property(self, "global_position:y", global_position.y - 30.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
		
	tween.tween_property(self, "modulate:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	await tween.finished
	queue_free()
