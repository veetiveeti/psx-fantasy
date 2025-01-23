extends Area3D

var DAMAGE = 45
var LIFETIME = 6.0
var SPEED = 6.0  # Faster than poison cloud
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
	
	# Move missile
	position += direction * SPEED * delta
	
	# Destroy when lifetime is up
	if time_alive >= LIFETIME:
		queue_free()

func _on_body_entered(body):
	print("Magic missile hit:", body.name, " from angle: ", rad_to_deg(rotation.y))
	if body.is_in_group("player"):
		print("Magic missile attempting to deal damage from angle: ", rad_to_deg(rotation.y))
		body.hurt(DAMAGE, global_position)
		print("Magic missile damage applied from angle: ", rad_to_deg(rotation.y))
