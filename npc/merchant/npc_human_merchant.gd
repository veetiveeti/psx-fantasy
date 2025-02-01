extends CharacterBody3D

signal show_interaction_text(text: String)
signal hide_interaction_text

@onready var interaction_area = $InteractionArea
@onready var dialogue_audio = $DialoguePlayer

var player_in_range = false
var dialogue_active = false
var current_dialogue_stage = 1  # Added this line

var dialogue_sound_1 = preload("res://npc/merchant/1.wav")
var dialogue_sound_2 = preload("res://npc/merchant/2.wav")
var dialogue_sound_3 = preload("res://npc/merchant/3.wav")
var dialogue_sound_4 = preload("res://npc/merchant/4.wav")

var dialogues = [
	dialogue_sound_1,
	dialogue_sound_2,
	dialogue_sound_3,
	dialogue_sound_4
]

func _ready():
	# Added this function to connect the audio finished signal
	dialogue_audio.finished.connect(_on_dialogue_finished)

func _process(_delta):
	if player_in_range:
		if Input.is_action_just_pressed("interact"):
			start_talk()

func _on_interaction_area_body_entered(body:Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		show_interaction_text.emit("Presseth F to talk.")

func _on_interaction_area_body_exited(body:Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		hide_interaction_text.emit()

func start_talk():
	hide_interaction_text.emit()
	var dialogue_index = mini(current_dialogue_stage - 1, dialogues.size() - 1)
	dialogue_audio.stream = dialogues[dialogue_index]
	dialogue_audio.play()
	if current_dialogue_stage < dialogues.size():
		current_dialogue_stage += 1

# Added this function to show the interaction text again when audio finishes
func _on_dialogue_finished():
	if player_in_range:
		show_interaction_text.emit("Presseth F to talk.")