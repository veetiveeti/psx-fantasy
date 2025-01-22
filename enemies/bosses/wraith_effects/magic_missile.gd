extends Area3D

var DAMAGE = 35
var LIFETIME = 6.0
var SPEED = 3.0  # Faster than poison cloud
var direction = Vector3.ZERO

@onready var mesh = $CollisionShape3D/MeshInstance3D
@onready var collision_shape = $CollisionShape3D
@onready var particles = $CollisionShape3D/GPUParticles3D

var time_alive = 0
var start_position: Vector3

func _ready():
    # You might want to add some particles or effects here
    start_position = global_position
    print("Magic missile spawned at:", start_position)
    
func initialize(pos: Vector3, dir: Vector3):
    global_position = pos
    direction = dir
    print("Magic missile initialized:")
    print("- Position:", pos)
    print("- Direction:", dir)
    # Rotate the missile to face the direction it's moving
    look_at(global_position + direction)

func _physics_process(delta):
    time_alive += delta
    
    # Debug every second
    if int(time_alive) != int(time_alive - delta):  # Only print on whole seconds
        print("Missile at time ", time_alive, ":")
        print("- Position:", global_position)
        print("- Distance travelled:", global_position.distance_to(start_position))
        print("- Current velocity:", direction * SPEED)
    
    # Move missile
    position += direction * SPEED * delta
    
    # Destroy when lifetime is up
    if time_alive >= LIFETIME:
        print("Magic missile lifetime expired")
        queue_free()

func _on_body_entered(body):
    print("Magic missile hit:", body.name)
    if body.is_in_group("player"):
        print("Hit player! Dealing damage")
        body.hurt(DAMAGE, global_position)
        queue_free()
    elif not body.is_in_group("enemy"):
        print("Hit non-player object:", body.name)
        queue_free()