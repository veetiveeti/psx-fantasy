extends StaticBody3D

@onready var anim_player = $AnimationPlayer
@onready var gate_audio = $GateSounds
@onready var level_finish_audio = $LevelFinishSounds
@onready var background_music = get_node("/root/Dungeon_lvl1/AudioStreamPlayer")

var gate_sound = preload("res://sounds/gate.wav")
var level_finish_sound = preload("res://sounds/finish.wav")



func _ready():
    var switch = get_node("../../gate_switch")  # Adjust path to your switch
    switch.switch_activated.connect(_on_switch_activated)
    
func _on_switch_activated():
    anim_player.play("rise_up")
    play_gate()

func _on_animation_player_animation_finished(anim_name):
    if anim_name == "rise_up":
        background_music.stop()
        get_tree().call_group("player", "show_victory_screen")
        play_finish()
    
func play_gate():
    gate_audio.stream = gate_sound
    gate_audio.play()

func play_finish():
    level_finish_audio.stream = level_finish_sound
    level_finish_audio.play()
