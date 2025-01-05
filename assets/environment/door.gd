extends StaticBody3D

signal show_interaction_text(text: String)
signal hide_interaction_text

@onready var anim_player = $AnimationPlayer
@onready var door_audio = $DoorSounds

var player_in_range = false
var is_open = false
var door_sound = preload("res://sounds/door.wav")
	
func _process(_delta):
	if player_in_range:
		if Input.is_action_just_pressed("interact"):
			if is_open:
				close_door()
			else:
				open_door()

func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		var text = "Presseth F to " + ("close" if is_open else "open") + " the door."
		show_interaction_text.emit(text)

func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		hide_interaction_text.emit()

func open_door():
	anim_player.play("open")
	play_door()
	is_open = true
	# Update interaction text
	show_interaction_text.emit("Presseth F to close the door.")

func close_door():
	anim_player.play_backwards("open")  # Play the same animation backwards
	play_door()
	is_open = false
	# Update interaction text
	show_interaction_text.emit("Presseth F to open the door.")
	
func play_door():
	door_audio.stream = door_sound
	door_audio.play()

