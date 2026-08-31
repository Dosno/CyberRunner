extends AudioStreamPlayer

func _ready() -> void:
	# Ensure the music automatically restarts whenever it finishes playing
	if not finished.is_connected(_on_music_finished):
		finished.connect(_on_music_finished)
	
	# Start playing automatically when the game launches
	if not playing:
		play()

func _on_music_finished() -> void:
	play()
