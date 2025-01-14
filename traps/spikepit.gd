extends Area3D

func _ready():
	# Connect the body entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Set blocking state temporarily to false
		var was_blocking = body.is_blocking
		body.is_blocking = false
		body.hurt(10000)
		body.is_blocking = was_blocking  # Restore original blocking state
