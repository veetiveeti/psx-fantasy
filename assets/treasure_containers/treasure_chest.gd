extends StaticBody3D

@warning_ignore("unused_signal")
signal loot_collected(item: ItemResource)

@export var loot: Array[ItemResource] = []  # Array to hold the chest's contents
var is_opened = false
var player_in_range = false

func _ready():
	add_to_group("interactable")
	print("Chest ready, loot count: ", loot.size())

func _input(event):
	if event.is_action_pressed("interact") and player_in_range and not is_opened:
		print("Interact pressed, player in range: ", player_in_range, ", is_opened: ", is_opened)
		open_chest()

func _on_interaction_area_body_entered(body):
	print("Body entered: ", body.name)
	if body.is_in_group("player") and not is_opened:
		print("Player entered interaction area")
		player_in_range = true
		body._on_show_interaction_text("Press F to open chest")

func _on_interaction_area_body_exited(body):
	print("Body exited: ", body.name)
	if body.is_in_group("player"):
		print("Player exited interaction area")
		player_in_range = false
		body._on_hide_interaction_text()

func open_chest():
	is_opened = true
	print("Chest opened!")
	# $AnimationPlayer.play("open")
	
	# Distribute loot to player
	for item in loot:
		emit_signal("loot_collected", item)
		print("You found: ", item.name)
		
	# Empty the chest
	loot.clear()
	queue_free()
