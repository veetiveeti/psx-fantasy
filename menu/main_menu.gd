extends Control

@onready var start_button = $ColorRect/VBoxContainer/StartButton
@onready var load_button = $ColorRect/VBoxContainer/LoadButton
@onready var options_button = $ColorRect/VBoxContainer/OptionsButton
@onready var quit_button = $ColorRect/VBoxContainer/QuitButton
@onready var crt_filter = $CanvasLayer2/CrtFilter

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	load_button.pressed.connect(_on_load_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Show mouse cursor in menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Optional: Play menu music here
	$MenuMusic.play()

func _on_start_pressed():
	# Change this to your actual first level scene
	get_tree().change_scene_to_file("res://test_1.tscn")

func _on_load_pressed():
	# Placeholder for load game functionality
	print("Load game - Not implemented yet")

func _on_options_pressed():
	# Placeholder for options menu
	print("Options - Not implemented yet")

func _on_quit_pressed():
	get_tree().quit()

# Optional: Add fade transitions later
#func fade_to_scene(scene_path: String):
#	var fade = ColorRect.new()
#	fade.color = Color.BLACK
#	fade.anchors_preset = Control.PRESET_FULL_RECT
#	add_child(fade)
#	
#	var tween = create_tween()
#	tween.tween_property(fade, "modulate:a", 1.0, 0.5)
#	await tween.finished
#	get_tree().change_scene_to_file(scene_path)