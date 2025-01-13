extends Area3D
class_name PickupItem

signal collected(item: ItemResource)

@export var item: ItemResource

func _ready():
    # Connect the body entered signal
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		collected.emit(item)
		queue_free()