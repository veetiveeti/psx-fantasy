extends CharacterBody3D

const SPEED = 4.0
const JUMP_VELOCITY = 4.2
const DASH_SPEED = 20.0
const DASH_DURATION = 0.2
var health = 100

var is_dashing = false
var dash_timer = 0.0
var can_dash = true
var dash_cooldown_timer = 0.0
const DASH_COOLDOWN = 1.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var hitbox = $Camera3D/WeaponPivot/WeaponMesh/Hitbox
@onready var healthbar = $Camera3D/ProgressBar

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func hurt(hit_points):
	if hit_points < health:
		health -= hit_points
	else:
		health = 0
	healthbar.value = health
	if health == 0:
		die()
		
func die():
	print("dead!")
	set_physics_process(false)  # Stop physics processing
	set_process(false)          # Stop normal processing
	set_process_input(false)    # Stop input processing
	# Add code to show game over UI or restart prompt
	
func _process(_delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
		
	if Input.is_action_just_pressed("hit"):
		anim_player.play("attack")
		hitbox.monitoring = true
	
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -(PI/4), PI/4)

func _physics_process(delta):
	# Handle dash cooldown
	if !can_dash:
		dash_cooldown_timer += delta
		if dash_cooldown_timer >= DASH_COOLDOWN:
			can_dash = true
			dash_cooldown_timer = 0.0
	
	# Handle dash timer and end dash
	if is_dashing:
		dash_timer += delta
		if dash_timer >= DASH_DURATION:
			is_dashing = false
			dash_timer = 0.0
			# Reset velocity when dash ends
			velocity = Vector3.ZERO
	
	# Apply gravity if not dashing
	if !is_dashing and !is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle dash input
	if Input.is_action_just_pressed("dash") and can_dash:
		var input_dir = Input.get_vector("left", "right", "forward", "back")
		if input_dir != Vector2.ZERO:
			# Start dash
			is_dashing = true
			can_dash = false
			dash_timer = 0.0
			# Set dash velocity
			var dash_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity = dash_direction * DASH_SPEED
			# Preserve current vertical velocity for air dashes
			if !is_on_floor():
				velocity.y = velocity.y
	
	# Normal movement when not dashing
	if !is_dashing:
		var input_dir = Input.get_vector("left", "right", "forward", "back")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "attack":
		anim_player.play("idle")
		hitbox.monitoring = false


func _on_hitbox_body_entered(body):
	if body.is_in_group("enemy"):
		# Calculate knockback direction from player to enemy
		var knockback_direction = (body.global_position - global_position).normalized()
		var knockback_force = knockback_direction * 10.0  # Adjust force as needed
		body.hurt(10, knockback_force)
		print("enemy hit")
