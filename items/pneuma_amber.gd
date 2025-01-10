extends Node3D
class_name PneumaAmber

signal collected(amber: PneumaAmber)

# You can extend this with different types if needed
enum Type {
    BASIC,          # Regular Pneuma Amber
    GREATER,        # Worth more points
    BOSS            # Special boss Amber, worth many points
}

@export var amber_type: Type = Type.BASIC
@export var value: int = 1  # How many stat points this amber is worth

func _ready():
    # Set up collision and visual effects
    pass

func collect():
    emit_signal("collected", self)
    queue_free()