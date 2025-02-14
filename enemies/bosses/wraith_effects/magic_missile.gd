extends Area3D

var DAMAGE = 48
var LIFETIME = 2.0
var SPEED = 4.0  # Faster than poison cloud
var direction = Vector3.ZERO

@onready var mesh = $CollisionShape3D/MeshInstance3D
@onready var collision_shape = $CollisionShape3D
@onready var particles = $CollisionShape3D/GPUParticles3D

var time_alive = 0
var start_position: Vector3

func _ready():
	# You might want to add some particles or effects here
	start_position = global_position
	
func initialize(pos: Vector3, dir: Vector3):
	global_position = pos
	direction = dir
	# Rotate the missile to face the direction it's moving
	look_at(global_position + direction)

func _physics_process(delta):
	time_alive += delta
	
	# Move missile
	position += direction * SPEED * delta
	
	# Destroy when lifetime is up
	if time_alive >= LIFETIME:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.hurt(DAMAGE, global_position)
