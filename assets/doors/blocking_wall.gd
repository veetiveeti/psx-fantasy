extends Area3D

@warning_ignore("unused_signal")
signal destroyed
signal show_interaction_text(text: String)
signal hide_interaction_text

func _ready():
	print("BlockingWall ready")  # Debug print
	# Find the boss manager in the scene
	var boss_manager = get_node("../BossManager")  # Adjust the path based on your scene structure
	if boss_manager:
		print("Found BossManager, connecting to boss_defeated signal")  # Debug print
		if boss_manager.has_signal("boss_defeated"):
			boss_manager.boss_defeated.connect(_on_boss_defeated)
			print("Successfully connected to boss_defeated signal")  # Debug print
		else:
			print("ERROR: boss_defeated signal not found in BossManager!")  # Debug print
	else:
		print("ERROR: BossManager not found! Check the node path.")  # Debug print

func _on_boss_defeated():
	print("BlockingWall: boss_defeated signal received")  # Debug print
	# Create a fade-out effect
	queue_free()
	
	emit_signal("destroyed")

func _on_body_entered(body) -> void:
	if body.is_in_group("player"):
		show_interaction_text.emit("A Powerful magic seems to block the way")

func _on_body_exited(body) -> void:
	if body.is_in_group("player"):
		hide_interaction_text.emit()