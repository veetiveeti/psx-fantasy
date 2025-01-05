extends StaticBody3D

@onready var anim_player = $AnimationPlayer
@onready var gate_audio = $GateSounds
@onready var level_finish_audio = $LevelFinishSounds
# @onready var background_music = get_node("/root/Dungeon_lvl1/AudioStreamPlayer")

var gate_sound = preload("res://sounds/gate.wav")
var level_finish_sound = preload("res://sounds/finish.wav")

var is_open = false

func _ready():
	var switch = get_node("../../gate_switch")  # Adjust path to your switch
	switch.gate_opened.connect(_on_gate_opened)
	switch.gate_closed.connect(_on_gate_closed)
	
func _on_gate_opened():
	anim_player.play("rise_up")
	play_gate()

func _on_gate_closed():
	anim_player.play_backwards("rise_up")
	play_gate()
	
func play_gate():
	gate_audio.stream = gate_sound
	gate_audio.play()

func play_finish():
	level_finish_audio.stream = level_finish_sound
	level_finish_audio.play()
