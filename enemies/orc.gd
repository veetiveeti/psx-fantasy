extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var healthbar = $SubViewport/EnemyHealthBar
@onready var anim_player = $AnimationPlayer
@onready var hitbox = $Armature/Skeleton3D/shortsword/shortsword/Hitbox
@onready var footstep_audio = $FootstepAudioPlayer
@onready var flee_audio = $FleeAudioPlayer
@onready var attack_audio = $AttackAudioPlayer
@onready var hurt_audio = $HurtAudioPlayer
@onready var detection_zone = $DetectionZone
@onready var game_manager = get_node("/root/GameManager")

enum EnemyState {
	IDLE,    # Standing still
	PATROL,  # Walking preset paths
	CHASE,   # Following player
	ATTACK,   # Attacking player
	FLEE # Fleeing after morale breaks
}

var current_state = EnemyState.IDLE 

var SPEED = 3.8
var ATTACK_COOLDOWN = 1.3 # Seconds between attacks
var ATTACK_RANGE = 0.8
var health = 100

var morale = 100
var flee_threshold = 40  # Run at 20% or lower
var flee_chance = 0.6  # 60% chance to flee
var is_fleeing = false  # Track if currently fleeing
var flee_destination = null

var knockback_velocity = Vector3.ZERO
var knockback_resistance = 0.2
var nav_ready = false
var can_attack = true
var attack_timer = 0.0
var bodies_in_hitbox = []
var footstep_sounds = [
	preload("res://sounds/stepdirt_6.wav"),
	preload("res://sounds/stepdirt_1.wav"),
	preload("res://sounds/stepdirt_4.wav")
]
var attack_sounds = [
	preload("res://sounds/swing.wav"),
	preload("res://sounds/swing3.wav")
]
var hurt_sounds = [
	preload("res://sounds/shade4.wav"),
	preload("res://sounds/shade5.wav")
]
var flee_sound = preload("res://sounds/niilo.wav")
var can_play_sound = true
var sound_cooldown = 1.0 # 1 second cooldown

func _ready():
	call_deferred("setup_navigation")

func setup_navigation():
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav_ready = true

func hurt(hit_points, knockback_force = Vector3.ZERO):
	if hit_points < health:
		health -= hit_points
	else:
		health = 0
	healthbar.value = health
	
	# Calculate morale loss based on damage
	if health > 0:
		morale -= (hit_points / health) * 100
	check_morale()

	knockback_velocity = knockback_force
	play_hurt()
	if health == 0:
		die()
		
func die():
	remove_from_group("enemy")
	queue_free()

func _physics_process(delta):
	if not GameManager.game_active:
		return

	if !nav_ready:
		return
	
	# Handle attack cooldown
	if !can_attack:
		attack_timer += delta
		if attack_timer >= ATTACK_COOLDOWN:
			can_attack = true
			attack_timer = 0.0
			
	match current_state:
		EnemyState.IDLE:
			# Just stand still and animate
			if not anim_player.current_animation == "idle":
				anim_player.play("idle")
				velocity = knockback_velocity
				
		EnemyState.CHASE:
			var current_location = global_transform.origin
			var next_location = nav_agent.get_next_path_position()
			var new_velocity = (next_location - current_location).normalized() * SPEED

			var distance_to_target = current_location.distance_to(nav_agent.target_position)

			if distance_to_target < ATTACK_RANGE:
				current_state = EnemyState.ATTACK
			else:
				nav_agent.set_velocity(new_velocity)
				if not anim_player.current_animation == "attack":
					anim_player.play("run")
					play_footstep()

				velocity = new_velocity + knockback_velocity
				
		EnemyState.ATTACK:
			if can_attack:
				start_attack()
				can_attack = false
				attack_timer = 0.0
			elif not anim_player.current_animation == "attack":
				current_state = EnemyState.CHASE
				velocity = knockback_velocity  # Only apply knockback when not attacking

			if anim_player.current_animation == "attack":
				var anim_time = anim_player.current_animation_position
				if anim_time > 0.3 and anim_time < 0.5:
					hitbox.monitoring = true
				else:
					hitbox.monitoring = false
				velocity = Vector3.ZERO
				
		EnemyState.FLEE:
				if flee_destination != null:
					var player = get_tree().get_nodes_in_group("player")[0]
					var current_location = global_transform.origin

					# Get direction AWAY from player
					var flee_direction = (current_location - player.global_position).normalized()
					# Set new flee point constantly away from player
					var target = current_location + (flee_direction * SPEED)
					# Move directly away
					velocity = flee_direction * SPEED

					if not anim_player.current_animation == "run":
						anim_player.play("run")

					# Look in direction of movement
					var look_target = global_position + flee_direction
					look_at(look_target)

	# Apply knockback in all states
	knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_resistance)
	move_and_slide()

func start_attack():
	bodies_in_hitbox.clear()
	anim_player.play("attack")
	play_attack()
	
func check_morale():
	if morale <= flee_threshold and not is_fleeing:
		# 60% chance to flee
		if randf() <= flee_chance:
			start_fleeing()
			
func start_fleeing():
	is_fleeing = true
	play_flee()
	current_state = EnemyState.FLEE
	flee_destination = Vector3.ONE
	
func find_flee_destination():
	var player = get_tree().get_nodes_in_group("player")[0]
	# Get direction AWAY from player
	var flee_direction = (global_position - player.global_position).normalized()

	# Set flee destination further away from player
	var target = global_position + (flee_direction * 20.0)
	# Add some randomness
	target += Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	flee_destination = target
	nav_agent.target_position = flee_destination
	print("Setting flee destination to: ", flee_destination)

func update_target_location(target_location):
	nav_agent.target_position = target_location
	# Get direction to target but zero out the Y component
	var direction = target_location - global_position
	direction.y = 0  # Ignore vertical difference
	
	if direction.length() > 0.001:  # Check if we have a meaningful direction
		var target = global_position + direction  # Look at a point at same height
		look_at(target)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "attack":
		hitbox.set_deferred("monitoring", false) # Use set_deferred here too
	if distance_to_player() < ATTACK_RANGE:
		anim_player.play("idle")
	else:
		anim_player.play("run")

func distance_to_player() -> float:
	return global_transform.origin.distance_to(nav_agent.target_position)

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") and not body in bodies_in_hitbox:
		var player = body
		if player.is_blocking and player.is_attack_from_front(global_position):
			# Attack blocked
			bodies_in_hitbox.append(body)
			get_tree().call_group("player", "hurt", 0) # Reduced damage
		else:
			# Attack not blocked (from behind or not blocking)
			bodies_in_hitbox.append(body)
			get_tree().call_group("player", "hurt", 10) # Full damage

func _process(delta):
	if not can_play_sound:
		sound_cooldown -= delta
	if sound_cooldown <= 0:
		can_play_sound = true
		sound_cooldown = 1.0

func play_footstep():
	if can_play_sound:
		footstep_audio.stream = footstep_sounds[randi() % footstep_sounds.size()]
		footstep_audio.play()
		can_play_sound = false

func play_attack():
		attack_audio.stream = attack_sounds[randi() % attack_sounds.size()]
		attack_audio.play()

func play_hurt():
		hurt_audio.stream = hurt_sounds[randi() % hurt_sounds.size()]
		hurt_audio.play()

func play_flee():
	flee_audio.stream = flee_sound
	flee_audio.play()

func _on_detection_zone_body_entered(body):
	if body.is_in_group("player"):
		current_state = EnemyState.CHASE
