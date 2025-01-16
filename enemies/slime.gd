extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var stats = $StatsComponent
@onready var healthbar = $SubViewport/EnemyHealthBar
@onready var anim_player = $AnimationPlayer
@onready var hitbox = $Hitbox
@onready var hurt_audio = $HurtAudioPlayer
@onready var footstep_audio = $FootstepAudioPlayer
@onready var attack_audio = $AttackAudioPlayer
@onready var detection_zone = $DetectionZone
@onready var game_manager = get_node("/root/GameManager")
@onready var mesh = $armature/Skeleton3D/Slime

enum SlimeState {
	IDLE,    # Standing still
	CHASE,   # Following player
	PREPARE_ATTACK,  # Preparing to shoot
	ATTACK,  # Shooting poison mist
	WAIT_AFTER_ATTACK,  # Wait for mist to disappear
}

var current_state = SlimeState.IDLE 

var SPEED = 0.8
var CONTACT_DAMAGE = 2
var DAMAGE_COOLDOWN = 1.0
var CHASE_RANGE = 10.0
var ATTACK_RANGE = 8.0  # Range at which slime will shoot mist
var ATTACK_COOLDOWN = 6.0  # Seconds between mist attacks
var ATTACK_WINDUP = 2.0   # Seconds before attack launches
var ROTATION_SPEED = 2.0  # How fast the slime rotates to face movement direction
var health = 40

# Mist attack variables
var can_attack = true
var attack_timer = 0.0
var attack_windup_timer = 0.0
var wait_after_attack_timer = 0.0
const WAIT_AFTER_ATTACK_TIME = 2.5  # Should match mist lifetime
const MIST_PROJECTILE = preload("res://enemies/effects/poison_mist.tscn")

# Hit flash variables
var hit_flash_time = 0.0

@onready var sight_ray = $RayCast3D
var player_in_range = false
var player_ref: Node3D = null
var last_seen_position: Vector3 = Vector3.ZERO
var time_since_last_seen: float = 0.0
var MEMORY_DURATION: float = 3.0
var CLOSE_RANGE: float = 2.0

var knockback_velocity = Vector3.ZERO
var knockback_resistance = 0.2
var nav_ready = false
var damage_timer = 0.0
var can_deal_damage = true
var damaged_bodies = []

var hurt_sound = preload("res://sounds/slime_hurt.wav")
var footstep_sound = preload("res://sounds/slime_run.wav")
var attack_sound = preload("res://sounds/slime_shoot.wav")

func _ready():
	call_deferred("setup_navigation")
	stats.set_base_stat("strength", 4)
	stats.set_base_stat("vitality", 3)
	stats.set_base_stat("dexterity", 6)
	stats.set_base_stat("intelligence", 1)

	health = stats.get_stat("max_health")
	healthbar.max_value = health
	healthbar.value = health

	SPEED = SPEED + (stats.get_stat("dexterity") * 0.1)
	
	# Make hitbox always active for contact damage
	hitbox.monitoring = true
	hitbox.monitorable = true

	stats.stat_changed.connect(_on_stat_changed)

func setup_navigation():
	await get_tree().physics_frame
	nav_ready = true

func _on_stat_changed(stat_name: String, new_value: float):
	match stat_name:
		"max_health":
			health = new_value
			healthbar.max_value = new_value
		"dexterity":
			SPEED = 1.2 + (new_value * 0.1)

func _physics_process(delta):
	if not GameManager.game_active:
		return

	# Handle attack cooldown
	if !can_attack:
		attack_timer += delta
		if attack_timer >= ATTACK_COOLDOWN:
			can_attack = true
			attack_timer = 0.0

	# Handle contact damage cooldown
	if not can_deal_damage:
		damage_timer += delta
		if damage_timer >= DAMAGE_COOLDOWN:
			can_deal_damage = true
			damage_timer = 0.0
			damaged_bodies.clear()

	if player_in_range and player_ref and is_instance_valid(player_ref):
		var dist_to_player = global_position.distance_to(player_ref.global_position)
		sight_ray.target_position = to_local(player_ref.global_position)

		# Check if we should switch to prepare attack state
		if can_attack and dist_to_player <= ATTACK_RANGE and \
		   (!sight_ray.is_colliding() or sight_ray.get_collider().is_in_group("player")):
			if current_state != SlimeState.PREPARE_ATTACK and current_state != SlimeState.ATTACK:
				print("Entering PREPARE_ATTACK state")  # Debug log
				current_state = SlimeState.PREPARE_ATTACK
				attack_windup_timer = 0.0  # Reset windup timer
		# Otherwise handle normal detection logic
		elif dist_to_player < CLOSE_RANGE:
			last_seen_position = player_ref.global_position
			time_since_last_seen = 0.0
			if current_state == SlimeState.IDLE:
				current_state = SlimeState.CHASE
		elif (!sight_ray.is_colliding() or sight_ray.get_collider().is_in_group("player")) and dist_to_player < CHASE_RANGE:
			last_seen_position = player_ref.global_position
			time_since_last_seen = 0.0
			if current_state == SlimeState.IDLE:
				current_state = SlimeState.CHASE
		else:
			time_since_last_seen += delta
			if current_state == SlimeState.CHASE and time_since_last_seen > MEMORY_DURATION:
				current_state = SlimeState.IDLE
	
	match current_state:
		SlimeState.IDLE:
			if not anim_player.current_animation == "idle":
				anim_player.play("idle")
			velocity = knockback_velocity
				
		SlimeState.CHASE:
			if player_ref and is_instance_valid(player_ref):
				update_target_location(player_ref.global_position)
				
				var current_location = global_transform.origin
				var next_location = nav_agent.get_next_path_position()
				var new_velocity = (next_location - current_location).normalized() * SPEED

				if not anim_player.current_animation == "run":
					anim_player.play("run")

				play_footstep()
				
				# Rotate to face movement direction
				if new_velocity.length() > 0.1:
					var target_rotation = atan2(new_velocity.x, new_velocity.z)  # Removed negatives
					var current_rotation = rotation.y
					
					# Find the shortest rotation path
					var rotation_diff = fmod((target_rotation - current_rotation + PI), (PI * 2)) - PI
					
					# Smoothly interpolate rotation
					rotation.y = current_rotation + rotation_diff * ROTATION_SPEED * delta
				
				velocity = new_velocity + knockback_velocity

		SlimeState.PREPARE_ATTACK:
			velocity = knockback_velocity  # Stop moving while preparing
			if not anim_player.current_animation == "shoot":
				anim_player.play("shoot")  # Or use a specific preparation animation if you have one
			
			# Keep facing the player while preparing to attack
			if player_ref and is_instance_valid(player_ref):
				var direction = player_ref.global_position - global_position
				var target_rotation = atan2(direction.x, direction.z)  # Removed negatives
				var current_rotation = rotation.y
				var rotation_diff = fmod((target_rotation - current_rotation + PI), (PI * 2)) - PI
				rotation.y = current_rotation + rotation_diff * ROTATION_SPEED * delta

			# Update windup timer
			attack_windup_timer += delta
			print("Windup timer: ", attack_windup_timer)  # Debug log
			if attack_windup_timer >= ATTACK_WINDUP:
				print("Transitioning to ATTACK state")  # Debug log
				current_state = SlimeState.ATTACK

			# Update windup timer
			attack_windup_timer += delta
			if attack_windup_timer >= ATTACK_WINDUP:
				current_state = SlimeState.ATTACK
				
		SlimeState.WAIT_AFTER_ATTACK:
			velocity = knockback_velocity  # Stay still while waiting
			
			# Keep facing the player while waiting
			if player_ref and is_instance_valid(player_ref):
				var direction = player_ref.global_position - global_position
				var target_rotation = atan2(direction.x, direction.z)
				var current_rotation = rotation.y
				var rotation_diff = fmod((target_rotation - current_rotation + PI), (PI * 2)) - PI
				rotation.y = current_rotation + rotation_diff * ROTATION_SPEED * delta
			
			# Update wait timer
			wait_after_attack_timer += delta
			if wait_after_attack_timer >= WAIT_AFTER_ATTACK_TIME:
				current_state = SlimeState.CHASE  # Resume chase after waiting

		SlimeState.ATTACK:
			velocity = knockback_velocity
			print("In ATTACK state, can_attack: ", can_attack)  # Debug log
			if player_ref and is_instance_valid(player_ref):
				# Keep facing the player while attacking
				var direction = player_ref.global_position - global_position
				var target_rotation = atan2(direction.x, direction.z)  # Removed negatives
				var current_rotation = rotation.y
				var rotation_diff = fmod((target_rotation - current_rotation + PI), (PI * 2)) - PI
				rotation.y = current_rotation + rotation_diff * ROTATION_SPEED * delta
				
				if can_attack:
					print("Shooting mist")  # Debug log
					shoot_mist()
					can_attack = false
					attack_timer = 0.0
					wait_after_attack_timer = 0.0
					current_state = SlimeState.WAIT_AFTER_ATTACK  # Go to wait state instead of chase

	# Apply knockback in all states
	knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_resistance)
	move_and_slide()

func shoot_mist():
	if player_ref and is_instance_valid(player_ref):
		# Calculate direction to player
		var direction = (player_ref.global_position - global_position).normalized()
		
		# Create mist instance
		var mist = MIST_PROJECTILE.instantiate()
		get_tree().current_scene.add_child(mist)
		
		# Set mist position slightly in front of slime
		var spawn_pos = global_position + direction * 1.0  # Offset by 1 unit
		spawn_pos.y += 0.5  # Raise slightly to be more at center mass
		
		# Initialize mist
		mist.initialize(spawn_pos, direction)

		play_attack()
		
		# Play attack animation if you have one
		anim_player.play("shoot")

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") and can_deal_damage and not body in damaged_bodies:
		var player = body
		
		# Apply damage if player isn't blocking or if attack is from behind
		if not player.is_blocking or not player.is_attack_from_front(global_position):
			damaged_bodies.append(body)
			can_deal_damage = false
			damage_timer = 0.0
			
			# Calculate final damage based on strength
			var final_damage = CONTACT_DAMAGE + (stats.get_stat("strength") * 0.5)
			get_tree().call_group("player", "hurt", final_damage, global_position)

func update_target_location(target_location):
	nav_agent.target_position = target_location

func hurt(hit_points, knockback_force = Vector3.ZERO):
	var defense = stats.get_stat("physical_defense")
	var damage_reduction = defense / (defense + 100.0)
	var final_damage = hit_points * (1.0 - damage_reduction)

	if final_damage < health:
		health -= final_damage
	else:
		health = 0

	healthbar.value = health
	knockback_velocity = knockback_force * 0.3
	
	hit_flash_time = 0.2
	mesh.material_overlay = EffectResources.hit_flash_material
	
	play_hurt()

	if health <= 0:
		die()

func die():
	remove_from_group("enemy")
	queue_free()

func _process(delta):
	if hit_flash_time > 0:
		hit_flash_time -= delta
		EffectResources.hit_flash_material.set_shader_parameter("flash_strength", hit_flash_time / 0.2)
		
		if hit_flash_time <= 0:
			mesh.material_overlay = null

func play_hurt():
	hurt_audio.stream = hurt_sound
	hurt_audio.play()

func play_footstep():
	footstep_audio.stream = footstep_sound
	footstep_audio.play()

func play_attack():
	attack_audio.stream = attack_sound
	attack_audio.play()

func _on_detection_zone_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		sight_ray.target_position = to_local(body.global_position)
		if !sight_ray.is_colliding() or sight_ray.get_collider().is_in_group("player"):
			current_state = SlimeState.CHASE

func _on_detection_zone_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		var distance = global_position.distance_to(body.global_position)
		if distance > CHASE_RANGE:
			current_state = SlimeState.IDLE