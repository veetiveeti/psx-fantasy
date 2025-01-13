extends Area3D

signal gate_opened
signal gate_closed
signal show_interaction_text(text: String)
signal hide_interaction_text

var required_coins = 0
var player_in_range = false
@onready var anim_player = $AnimationPlayer
@onready var switch_audio = $SwitchAudio
@onready var game_manager = get_node("/root/GameManager")

var is_gate_open = false

var switch_sounds = [
	preload("res://sounds/switch.wav")
]

func _process(_delta):
    if player_in_range:
        if Input.is_action_just_pressed("interact"):
            if is_gate_open:
                close_gate()
            else:
                open_gate()

func _on_body_entered(body):
    if body.is_in_group("player"):
        player_in_range = true
        show_interaction_text.emit("Presseth F to pulleth the switch.")

func _on_body_exited(body):
    if body.is_in_group("player"):
        player_in_range = false
        hide_interaction_text.emit()

func show_requirement():
    show_interaction_text.emit("Thou shalt not pass if thou hast not acquired 20 coins.")
    await get_tree().create_timer(4.0).timeout
    if player_in_range:
        show_interaction_text.emit("Press F to pull switch")

func open_gate():
    # GameManager.game_active = false  # Stop all gameplay
    anim_player.play("switch")  # Play switch animation
    is_gate_open = true
    play_switch()
    gate_opened.emit()  # Tell portcullis to open

func close_gate():
    # GameManager.game_active = false  # Stop all gameplay
    anim_player.play_backwards("switch")  # Play switch animation
    is_gate_open = false
    play_switch()
    gate_closed.emit()  # Tell portcullis to open

func play_switch():
    switch_audio.stream = switch_sounds[randi() % switch_sounds.size()]
    switch_audio.play()
