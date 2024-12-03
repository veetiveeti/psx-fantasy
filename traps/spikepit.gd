extends Area3D

func _ready():
    # Connect the body entered signal
    body_entered.connect(_on_body_entered)

func _on_body_entered(body):
    # Check if the colliding body is the player
    if body.is_in_group("player"):
        # Kill the player
        get_tree().call_group("player", "hurt", 100)