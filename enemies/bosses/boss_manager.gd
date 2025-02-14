extends Node3D

signal boss_defeated  # Add this new signal

const WRAITH_SCENE = preload("res://enemies/bosses/wraith.tscn")
var boss_instance = null

func _ready():
	print("BossManager ready")  # Debug print
	# Connect to altar fires
	for fire in get_tree().get_nodes_in_group("altar_fires"):
		if fire.has_signal("extinguished"):
			fire.extinguished.connect(_on_fire_extinguished)

func _on_fire_extinguished():
	var fires_remaining = get_tree().get_nodes_in_group("altar_fires").size() - 1
	
	if fires_remaining <= 0 and not boss_instance:
		print("Spawning Wraith")  # Debug print
		# Spawn boss
		boss_instance = WRAITH_SCENE.instantiate()
		get_tree().current_scene.add_child(boss_instance)
		boss_instance.global_position = Vector3(-2.063, -8.484, -0.888)
		
		# Connect to the wraith's defeated signal
		if boss_instance.has_signal("wraith_defeated"):
			print("Connecting to wraith_defeated signal")  # Debug print
			boss_instance.wraith_defeated.connect(_on_wraith_defeated)
		else:
			print("ERROR: wraith_defeated signal not found!")  # Debug print

func _on_wraith_defeated():
	print("BossManager: Wraith defeated signal received")  # Debug print
	emit_signal("boss_defeated")
	print("BossManager: boss_defeated signal emitted")  # Debug print