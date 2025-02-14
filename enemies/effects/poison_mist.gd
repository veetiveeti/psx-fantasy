extends Area3D

var DAMAGE = 15
var LIFETIME = 2.4
var SPEED = 1.6
var DAMAGE_TICK = 0.5  # How often damage is applied while in mist
var direction = Vector3.ZERO

@onready var particles = $GPUParticles3D
@onready var collision_shape = $CollisionShape3D

var time_alive = 0
var bodies_in_mist = {}  # Dictionary to track bodies and their damage timers

func _ready():
    # Start particles
    particles.emitting = true
    
func initialize(pos: Vector3, dir: Vector3):
    position = pos
    direction = dir
    # Rotate the mist to face the direction it's moving
    look_at(position + direction)

func _physics_process(delta):
    time_alive += delta
    position += direction * SPEED * delta
    
    # Update damage timers for bodies in mist
    for body in bodies_in_mist.keys():
        if is_instance_valid(body):
            bodies_in_mist[body] += delta
            if bodies_in_mist[body] >= DAMAGE_TICK:
                apply_damage(body)
                bodies_in_mist[body] = 0
    
    # Destroy when lifetime is up
    if time_alive >= LIFETIME:
        queue_free()

func _on_body_entered(body):
    if body.is_in_group("player"):
        # Initialize damage timer for this body
        bodies_in_mist[body] = 0
        apply_damage(body)

func _on_body_exited(body):
    if body in bodies_in_mist:
        bodies_in_mist.erase(body)

func apply_damage(body):
    if body.is_in_group("player") and is_instance_valid(body):
        body.hurt(DAMAGE, global_position)