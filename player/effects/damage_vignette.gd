extends ColorRect

@export var flash_duration = 0.2
@export var flash_intensity = 0.8
@export var flash_opacity = 0.6

var tween: Tween

func _ready():
	# Make sure the ColorRect covers the whole viewport
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse input
	
	# Initialize shader parameters
	material.set_shader_parameter("vignette_intensity", 0.0)
	material.set_shader_parameter("vignette_opacity", 0.0)

func flash_damage():
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_parallel(true)
	
	# Flash intensity up and down
	tween.tween_property(material, "shader_parameter/vignette_intensity", 
		flash_intensity, flash_duration * 0.2)
	tween.tween_property(material, "shader_parameter/vignette_intensity", 
		0.0, flash_duration * 0.8).set_delay(flash_duration * 0.2)
	
	# Flash opacity up and down
	tween.tween_property(material, "shader_parameter/vignette_opacity", 
		flash_opacity, flash_duration * 0.2)
	tween.tween_property(material, "shader_parameter/vignette_opacity", 
		0.0, flash_duration * 0.8).set_delay(flash_duration * 0.2)
