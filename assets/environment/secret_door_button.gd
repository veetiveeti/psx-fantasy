extends Area3D

signal secret_door_opened
signal secret_door_closed

var player_in_range = false
@onready var anim_player = $AnimationPlayer
# @onready var switch_audio = $SwitchAudio
@onready var game_manager = get_node("/root/GameManager")

var is_secret_door_open = false

var switch_sounds = [
	preload("res://sounds/switch.wav")
]

func _process(_delta):
    if player_in_range:
        if Input.is_action_just_pressed("interact"):
            if is_secret_door_open:
                close_secret_door()
            else:
                open_secret_door()

func _on_body_entered(body):
    if body.is_in_group("player"):
        print("player in range")
        player_in_range = true

func open_secret_door():
    anim_player.play("press")
    is_secret_door_open = true
    # play_switch()
    secret_door_opened.emit()  # Tell portcullis to open

func close_secret_door():
    # GameManager.game_active = false
    anim_player.play_backwards("press")  # Play switch animation
    is_secret_door_open = false
   #  play_switch()
    secret_door_closed.emit()  # Tell portcullis to open

# func play_switch():
    # switch_audio.stream = switch_sounds[randi() % switch_sounds.size()]
    # switch_audio.play()
