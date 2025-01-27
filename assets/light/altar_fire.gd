extends Node3D

@warning_ignore("unused_signal")
signal extinguished
signal show_interaction_text(text: String)
signal hide_interaction_text

@onready var omni_light = $MeshInstance3D/OmniLight3D
@onready var particles = $MeshInstance3D/GPUParticles3D
@onready var interaction_area = $Area3D
@onready var collision_shape = $Area3D/CollisionShape3D

var is_burning = true
var can_interact = true

func _ready():
	add_to_group("altar_fires")
	interaction_area.body_entered.connect(_on_area_body_entered)
	interaction_area.body_exited.connect(_on_area_body_exited)

func _on_area_body_entered(body):
	if body.is_in_group("player"):
		# Show interaction prompt
		if is_burning:
			show_interaction_text.emit("Presseth F to extinguish the flame.")

func _on_area_body_exited(body):
	if body.is_in_group("player"):
		# Hide interaction prompt
		hide_interaction_text.emit()

func _input(event):
	if event.is_action_pressed("interact"):  # Make sure you have this action defined
		var bodies = interaction_area.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player") and is_burning and can_interact:
				extinguish_fire()

func extinguish_fire():
	is_burning = false
	can_interact = false

	hide_interaction_text.emit()
	
	# Turn off visual effects
	particles.emitting = false
	omni_light.light_energy = 0
	
	# Remove from group before emitting signal
	remove_from_group("altar_fires")

	# Activate the other torch lights in the scene
	for triggered_fire in get_tree().get_nodes_in_group("triggered_fires"):
		triggered_fire.visible = true
	
	print("Fire extinguished, emitting signal")  # Debug print
	emit_signal("extinguished")