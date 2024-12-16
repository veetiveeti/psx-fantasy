extends Area3D

signal switch_activated
signal show_interaction_text(text: String)
signal hide_interaction_text

var required_coins = 20
var player_in_range = false
@onready var anim_player = $AnimationPlayer
@onready var switch_audio = $SwitchAudio
@onready var game_manager = get_node("/root/GameManager")

var switch_sounds = [
	preload("res://sounds/switch.wav")
]

func _process(_delta):
    if player_in_range:
        if Input.is_action_just_pressed("interact"):
            var player = get_tree().get_nodes_in_group("player")[0]
            if player.score >= required_coins:
                activate_switch()
            else:
                show_requirement()

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

func activate_switch():
    GameManager.game_active = false  # Stop all gameplay
    anim_player.play("switch")  # Play switch animation
    play_switch()
    switch_activated.emit()  # Tell portcullis to open

func play_switch():
    switch_audio.stream = switch_sounds[randi() % switch_sounds.size()]
    switch_audio.play()
