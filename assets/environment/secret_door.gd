extends StaticBody3D

@onready var anim_player = $AnimationPlayer

var gate_sound = preload("res://sounds/gate.wav")
var level_finish_sound = preload("res://sounds/finish.wav")

var is_open = false

func _ready():
	var button = get_node("../SecretDoorButtonParented/SecretDoorButton")
	button.secret_door_opened.connect(_on_secret_door_opened)
	button.secret_door_closed.connect(_on_secret_door_closed)
	
func _on_secret_door_opened():
	anim_player.play("activate")
	# play_gate()

func _on_secret_door_closed():
	anim_player.play_backwards("activate")
	# play_gate()
	
# func play_gate():
	# gate_audio.stream = gate_sound
	# gate_audio.play()
