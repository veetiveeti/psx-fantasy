extends CharacterBody3D

const SPEED = 4.7
const JUMP_VELOCITY = 4.2
const DASH_SPEED = 20.0
const DASH_DURATION = 0.3
var health = 100
var is_dying = false
var death_rotation_speed = 4.0 # Adjust this to control fall speed
var death_rotation_completed = false
var target_rotation = 0.0 # Related to death rotation
var death_fade_speed = 4.0  # Control fade speed
var can_play_sound = true
var sound_cooldown = 1.0  # 1 second cooldown
var initial_dash_speed = 10.0  # Your current DASH_SPEED
var final_dash_speed = 20.0     # Speed to ease down to (could be your normal SPEED)
var stored_dash_direction = Vector3.ZERO  # Store dash direction


var hit_enemies = []
var is_attacking = false

var is_blocking = false
var block_damage_reduction = 0.5

var hurt_sounds = [
	preload("res://sounds/pain1.wav"),
	preload("res://sounds/pain6.wav")
]
var attack_sounds = [
	preload("res://sounds/sword_sfx.wav")
]
var death_sounds = [
	preload("res://sounds/die2.wav")
]
var footstep_sounds = [
	preload("res://sounds/stepstone_4.wav"),
	preload("res://sounds/stepstone_5.wav")
]
var block_sounds = [
	preload("res://sounds/sword-unsheathe2.wav")
]
var dash_sounds = [
	preload("res://sounds/air_move.wav")
]

var is_dashing = false
var dash_timer = 0.0
var can_dash = true
var dash_cooldown_timer = 0.0
const DASH_COOLDOWN = 0.8

var can_play_attack_sound = true
var attack_sound_cooldown = 0.5

var score = 0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var hitbox = $Armature/Skeleton3D/shortsword/shortsword/Area3D
@onready var healthbar = $Camera3D/ProgressBar
@onready var attack_audio = $AttackSounds
@onready var hurt_audio = $HurtSounds
@onready var death_audio = $HurtSounds
@onready var block_audio = $BlockSounds
@onready var footstep_audio = $FootSounds
@onready var dash_audio = $DashSounds
@onready var weapon_hide = $Armature/Skeleton3D/shortsword/shortsword
@onready var death_screen = $CanvasLayer/ColorRect
@onready var dash_effect = $CanvasLayer/DashEffect

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	dash_effect.modulate.a = 0
	if death_screen:
		death_screen.modulate.a = 0  # Start fully transparent
	floor_max_angle = deg_to_rad(60) # Increase max floor angle
	floor_snap_length = 0.5 # Helps stick to ground when going up stairs
	for coin in get_tree().get_nodes_in_group("coins"):
		coin.connect("coin_collected", _on_coin_collected)
	
func hurt(hit_points):

	if is_blocking:
		# Reduce damage when blocking
		hit_points *= block_damage_reduction
		play_block()

	if hit_points < health:
		health -= hit_points
		if not is_blocking:
			play_hurt()
		if is_blocking and not is_attack_from_front(global_position):
			play_hurt()
	else:
		health = 0
	healthbar.value = health
	if health == 0:
		die()
		
func die():
	is_dying = true
	play_death()
	weapon_hide = false
	velocity = Vector3.ZERO # Stop all movement
	set_process(false)
	set_process_input(false)

func is_attack_from_front(attacker_position: Vector3) -> bool:
	var to_attacker = (attacker_position - global_position).normalized()
	var forward = -global_transform.basis.z  # Player's forward direction
	var angle = rad_to_deg(forward.angle_to(to_attacker))
	return angle < 90  # Blocks 180-degree arc in front
	
func _process(delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
		
	if Input.is_action_just_pressed("hit") and not is_blocking:
		hit_enemies.clear() # Clear the list when starting a new attack
		is_attacking = true
		anim_player.play("attack")
		play_attack()
		hitbox.monitoring = true
		
	if Input.is_action_just_pressed("hit_alt") and not is_blocking:
		hit_enemies.clear() # Clear the list when starting a new attack
		is_attacking = true
		anim_player.play("attack_alt")
		play_attack()
		hitbox.monitoring = true

	if Input.is_action_just_pressed("block"):  # When block starts
		is_blocking = true
		anim_player.play("block")
		velocity.x = 0
		velocity.y = 0
		velocity.z = 0
		# Wait until animation reaches last frame
		await get_tree().create_timer(anim_player.current_animation_length).timeout
		anim_player.pause()
	elif Input.is_action_just_released("block"):  # When block ends
		is_blocking = false
		anim_player.play("idle")  # Or return to whatever animation should play
		
	if not can_play_attack_sound:
		attack_sound_cooldown -= delta
	if attack_sound_cooldown <= 0:
		can_play_attack_sound = true
		attack_sound_cooldown = 0.5

	if not can_play_sound:
		sound_cooldown -= delta
	if sound_cooldown <= 0:
		can_play_sound = true
		sound_cooldown = 0.3
	
func _input(event):
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
		else:
			# Calculate eased speed
			var t = dash_timer / DASH_DURATION
			var current_dash_speed = lerp(initial_dash_speed, final_dash_speed, ease(t, 0.2))  # Adjust ease value
			velocity = stored_dash_direction * current_dash_speed
			
	if is_dying:
		if target_rotation < PI/2:
			target_rotation += death_rotation_speed * delta
			rotation.x = target_rotation
			# Add fade effect
			death_screen.modulate.a = move_toward(death_screen.modulate.a, 1.0, death_fade_speed * delta)
		else:
			rotation.x = PI/2
			death_screen.modulate.a = 1.0  # Ensure fully black
			is_dying = false
			set_physics_process(false)
		return

	if not is_attacking and not is_blocking:  # Only play movement animations if not attacking or blocking
		if velocity.length() > 0.1 and is_on_floor() and not is_dashing:
			anim_player.play("run")
			play_footstep()
		else:
			if not is_dashing:
				anim_player.play("idle")
	
	# Apply gravity if not dashing
	if !is_dashing and !is_on_floor():
		velocity.y -= gravity * delta
		can_play_sound = false

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle dash input
	if Input.is_action_just_pressed("dash") and can_dash:
		var input_dir = Input.get_vector("left", "right", "forward", "back")
		if input_dir != Vector2.ZERO:
			is_dashing = true
			can_dash = false
			dash_effect.modulate.a = 1.0
			dash_timer = 0.0
			stored_dash_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			anim_player.play("dash")
			play_dash()
			if !is_on_floor():
				velocity.y = velocity.y
	
	# Normal movement when not dashing
	if !is_dashing and !is_blocking:
		dash_effect.modulate.a = move_toward(dash_effect.modulate.a, 0, delta * 10.0)
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
	if anim_name == "attack" or anim_name == "attack_alt":  # Proper way to check both animations
		is_attacking = false
		hitbox.monitoring = false
	elif anim_name == "dash":
		anim_player.play("idle")

func _on_area_3d_body_entered(body):
	if body.is_in_group("enemy") and not body in hit_enemies:
		# Calculate knockback direction from player to enemy
		var knockback_direction = (body.global_position - global_position).normalized()
		var knockback_force = knockback_direction * 18.0 # Adjust force as needed
		body.hurt(10, knockback_force)
		hit_enemies.append(body)
		
func _on_coin_collected(value):
	score += value
	print("Score: ", score)  # Or update UI

func play_hurt():
		hurt_audio.stream = hurt_sounds[randi() % hurt_sounds.size()]
		hurt_audio.play()

func play_death():
		death_audio.stream = death_sounds[randi() % death_sounds.size()]
		death_audio.play()

func play_attack():
	if can_play_attack_sound:
		attack_audio.stream = attack_sounds[randi() % attack_sounds.size()]
		attack_audio.play()
		can_play_attack_sound = false
		attack_sound_cooldown = 0.25 # Reset cooldown here

func play_block():
		block_audio.stream = block_sounds[randi() % block_sounds.size()]
		block_audio.play()
	
func play_footstep():
	if can_play_sound:
		footstep_audio.stream = footstep_sounds[randi() % footstep_sounds.size()]
		footstep_audio.play()
		can_play_sound = false

func play_dash():
	dash_audio.stream = dash_sounds[randi() % dash_sounds.size()]
	dash_audio.play()
