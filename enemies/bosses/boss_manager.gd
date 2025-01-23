extends Node3D

const WRAITH_SCENE = preload("res://enemies/bosses/wraith.tscn")
var boss_instance = null

func _ready():
    # Connect to altar fires
    for fire in get_tree().get_nodes_in_group("altar_fires"):
        if fire.has_signal("extinguished"):
            fire.extinguished.connect(_on_fire_extinguished)

func _on_fire_extinguished():
    var fires_remaining = get_tree().get_nodes_in_group("altar_fires").size() - 1
    
    if fires_remaining <= 0 and not boss_instance:
        # Spawn boss
        boss_instance = WRAITH_SCENE.instantiate()
        get_tree().current_scene.add_child(boss_instance)
        boss_instance.global_position = Vector3(-2.063, -8.484, -0.888)