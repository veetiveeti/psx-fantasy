extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var healthbar = $SubViewport/EnemyHealthBar
@onready var anim_player = $AnimationPlayer
@onready var hitbox = $Armature/Skeleton3D/shortsword/shortsword/Hitbox
@onready var footstep_audio = $FootstepAudioPlayer
@onready var attack_audio = $AttackAudioPlayer
@onready var hurt_audio = $HurtAudioPlayer
@onready var detection_zone = $DetectionZone
@onready var game_manager = get_node("/root/GameManager")

enum EnemyState {
	IDLE,    # Standing still
	PATROL,  # Walking preset paths
	CHASE,   # Following player
	ATTACK   # Attacking player
}

var current_state = EnemyState.IDLE 

var SPEED = 4
var ATTACK_COOLDOWN = 1.4 # Seconds between attacks
var ATTACK_RANGE = 0.8
var health = 100
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
	knockback_velocity = knockback_force
	play_hurt()
	if health == 0:
		die()
		
func die():
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
				if not anim_player.current_animation == "attack_alt":
					anim_player.play("run")
					play_footstep()

				velocity = new_velocity + knockback_velocity
				
		EnemyState.ATTACK:
			if can_attack:
				start_attack()
				can_attack = false
				attack_timer = 0.0
			elif not anim_player.current_animation == "attack_alt":
				current_state = EnemyState.CHASE
				velocity = knockback_velocity  # Only apply knockback when not attacking

			if anim_player.current_animation == "attack_alt":
				var anim_time = anim_player.current_animation_position
				if anim_time > 0.3 and anim_time < 0.5:
					hitbox.monitoring = true
				else:
					hitbox.monitoring = false
				velocity = Vector3.ZERO 

	# Apply knockback in all states
	knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_resistance)
	move_and_slide()

func start_attack():
	bodies_in_hitbox.clear()
	anim_player.play("attack_alt")
	play_attack()

func update_target_location(target_location):
	nav_agent.target_position = target_location
	# Get direction to target but zero out the Y component
	var direction = target_location - global_position
	direction.y = 0  # Ignore vertical difference
	
	if direction.length() > 0.001:  # Check if we have a meaningful direction
		var target = global_position + direction  # Look at a point at same height
		look_at(target)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "attack_alt":
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

func _on_detection_zone_body_entered(body):
	if body.is_in_group("player"):
		current_state = EnemyState.CHASE