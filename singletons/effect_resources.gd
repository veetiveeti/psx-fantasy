extends Node

var hit_flash_material: ShaderMaterial

func _ready():
	# Create the material once
	hit_flash_material = ShaderMaterial.new()
	hit_flash_material.shader = load("res://shaders/hit_flash.gdshader")
	hit_flash_material.set_shader_parameter("flash_strength", 0.0)