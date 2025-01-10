extends Area3D
class_name PickupItem

signal collected(item_data: Dictionary)

@export var item_name: String = "Strength Pneuma Amber"
@export var item_type: String = "pneuma_amber"  # pneuma_amber, weapon, armor, etc
@export var stat_type: String = "strength"      # for pneuma ambers

func _ready():
    # Connect the body entered signal
	body_entered.connect(_on_body_entered)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.4, 0.1, 0.8)  # Amber color
	material.emission_enabled = true
	material.emission = Color(0.9, 0.4, 0.1)
	material.emission_energy = 2.0
	$MeshInstance3D.material_override = material
	
	# You might want to add a simple rotating animation
	var tween = create_tween().set_loops()
	tween.tween_property(self, "rotation_degrees:y", 360, 3).from(0)
	
func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		var item_data = {
			"type": item_type,
			"name": item_name,
			"stat_type": stat_type
		}
		collected.emit(item_data)
		# Add pickup effect here if you want
		queue_free()