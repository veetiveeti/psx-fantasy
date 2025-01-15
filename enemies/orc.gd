extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var stats = $StatsComponent
@onready var healthbar = $SubViewport/EnemyHealthBar
@onready var anim_player = $AnimationPlayer
@onready var hitbox = $Armature/Skeleton3D/shortsword/shortsword/Hitbox
@onready var footstep_audio = $FootstepAudioPlayer
@onready var flee_audio = $FleeAudioPlayer
@onready var attack_audio = $AttackAudioPlayer
@onready var hurt_audio = $HurtAudioPlayer
@onready var detection_zone = $DetectionZone
@onready var game_manager = get_node("/root/GameManager")
@onready var mesh = $Armature/Skeleton3D/lowpoly_orc

enum EnemyState {
	IDLE,    # Standing still
	PATROL,  # Walking preset paths
	CHASE,   # Following player
	ATTACK,   # Attacking player
	FLEE # Fleeing after morale breaks
}

var current_state = EnemyState.IDLE 

var SPEED = 3.9
var ATTACK_COOLDOWN = 1.2 # Seconds between attacks
var ATTACK_RANGE = 0.8
var health = 50

# Hit flash variables
var hit_flash_time = 0.0

@onready var sight_ray = $RayCast3D
var player_in_range = false
var player_ref: Node3D = null
var last_seen_position: Vector3 = Vector3.ZERO
var time_since_last_seen: float = 0.0
var MEMORY_DURATION: float = 5.0  # Remember player longer
var CHASE_DISTANCE: float = 10.0  # Chase further
var CLOSE_RANGE: float = ATTACK_RANGE * 4  # Detect closer without raycast

@warning_ignore("unused_signal")
signal enemy_hurt

var morale = 100
var flee_threshold = 30  # Run at 30% or lower
var flee_chance = 0.4  # 40% chance to flee
var is_fleeing = false  # Track if currently fleeing
var flee_destination = null

var knockback_velocity = Vector3.ZERO
var knockback_resistance = 0.2
var nav_ready = false
var can_attack = true
var attack_timer = 0.0
var bodies_in_hitbox = []
var footstep_sounds = [
	preload("res://sounds/stepstone_4.wav"),
	preload("res://sounds/stepstone_5.wav")
]
var attack_sounds = [
	preload("res://sounds/swing.wav"),
	preload("res://sounds/swing3.wav")
]
var hurt_sounds = [
	preload("res://sounds/Goblin_01.wav"),
	preload("res://sounds/Goblin_04.wav")
]
var flee_sound = preload("res://sounds/Goblin_03.wav")
var can_play_sound = true
var sound_cooldown = 1.0 # 1 second cooldown

func _ready():
	call_deferred("setup_navigation")
	stats.set_base_stat("strength", 5)
	stats.set_base_stat("vitality", 4)
	stats.set_base_stat("dexterity", 8)
	stats.set_base_stat("intelligence", 1)


	health = stats.get_stat("max_health")  # This will now use the proper vitality-based health
	healthbar.max_value = health           # Make sure healthbar matches
	healthbar.value = health               # Set initial health

	SPEED = SPEED + (stats.get_stat("dexterity") * 0.1)
	ATTACK_COOLDOWN = ATTACK_COOLDOWN * (1.0 / stats.get_stat("attack_speed"))

	stats.stat_changed.connect(_on_stat_changed)

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy != self:  # Don't connect to self
			var distance = global_position.distance_to(enemy.global_position)
			if distance < CHASE_DISTANCE:  # Only connect to enemies within chase range
				enemy.enemy_hurt.connect(_on_ally_hurt)

func setup_navigation():
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav_ready = true

func _on_stat_changed(stat_name: String, new_value: float):
	match stat_name:
		"max_health":
			health = new_value
			healthbar.max_value = new_value
		"attack_speed":
			ATTACK_COOLDOWN = 1.5 * (1.0 / new_value)
		"dexterity":
			SPEED = 3.8 + (new_value * 0.1)

func hurt(hit_points, knockback_force = Vector3.ZERO):
	# Debug prints
	print("Incoming damage: ", hit_points)

	# Calculate damage reduction from physical defense
	var defense = stats.get_stat("physical_defense")
	print("Physical defense: ", defense)

	var damage_reduction = defense / (defense + 100.0)
	print("Damage reduction: ", damage_reduction)

	# Calculate final damage
	var final_damage = hit_points * (1.0 - damage_reduction)
	print("Final damage: ", final_damage)
	print("Current health: ", health)

	emit_signal("enemy_hurt")

	if final_damage < health:
		health -= final_damage
		# Calculate health percentage and update morale
		var health_percent = (health / healthbar.max_value) * 100
		morale = health_percent  # Set morale to match health percentage
		check_morale()  # Check if should flee
	else:
		health = 0

	# Update healthbar
	healthbar.value = health
	print("New health: ", health)

	# Apply knockback
	knockback_velocity = knockback_force * 0.3
	
	hit_flash_time = 0.2
	mesh.material_overlay = EffectResources.hit_flash_material
	
	play_hurt()

	if health == 0:
		die()
		
func die():
	remove_from_group("enemy")
	queue_free()

func _physics_process(delta):
	if not GameManager.game_active:
		return

	if not is_fleeing and player_in_range and player_ref and is_instance_valid(player_ref):
		var dist_to_player = global_position.distance_to(player_ref.global_position)
		sight_ray.target_position = to_local(player_ref.global_position)

		# Always detect if very close, regardless of line of sight
		if dist_to_player < CLOSE_RANGE:
			last_seen_position = player_ref.global_position
			time_since_last_seen = 0.0
			if current_state == EnemyState.IDLE:
				current_state = EnemyState.CHASE
		# Otherwise use raycast and distance check
		elif (!sight_ray.is_colliding() or sight_ray.get_collider().is_in_group("player")) and dist_to_player < CHASE_DISTANCE:
			last_seen_position = player_ref.global_position
			time_since_last_seen = 0.0
			if current_state == EnemyState.IDLE:
				current_state = EnemyState.CHASE
		else:
			time_since_last_seen += delta
			if current_state == EnemyState.CHASE and time_since_last_seen > MEMORY_DURATION:
				current_state = EnemyState.IDLE
	
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
			if player_ref and is_instance_valid(player_ref):
				update_target_location(player_ref.global_position)
				
				var current_location = global_transform.origin
				var next_location = nav_agent.get_next_path_position()
				var new_velocity = (next_location - current_location).normalized() * SPEED

				var distance_to_target = current_location.distance_to(nav_agent.target_position)

				if distance_to_target < ATTACK_RANGE:
					current_state = EnemyState.ATTACK
				else:
					if not anim_player.current_animation == "run":  # Only change animation if needed
						anim_player.play("run")
					
					velocity = new_velocity + knockback_velocity
					play_footstep()
				
		EnemyState.ATTACK:
			if can_attack:
				start_attack()
				can_attack = false
				attack_timer = 0.0
			elif anim_player.current_animation == "attack":
				var anim_time = anim_player.current_animation_position
				if anim_time > 0.3 and anim_time < 0.5:
					hitbox.monitoring = true
					hitbox.monitorable = true
				else:
					hitbox.monitoring = false
					hitbox.monitorable = false
				velocity = knockback_velocity  # Changed from Vector3.ZERO to allow knockback
				
				if anim_time >= anim_player.current_animation_length:
					current_state = EnemyState.CHASE
			else:
				current_state = EnemyState.CHASE
				
		EnemyState.FLEE:
			if flee_destination != null:
				var players = get_tree().get_nodes_in_group("player")
				if players.is_empty() or not is_instance_valid(players[0]):
					current_state = EnemyState.IDLE
					is_fleeing = false
					return
					
				var player = players[0]
				var current_location = global_transform.origin
				var flee_direction = (current_location - player.global_position)
				flee_direction.y = 0
				
				if flee_direction.length() > 0.001:
					# Make them face away from player while fleeing
					var away_target = global_position + flee_direction.normalized()
					look_at(away_target)
					rotation.x = 0  # Keep upright
				
				var new_velocity = flee_direction.normalized() * SPEED
				velocity = lerp(velocity, new_velocity, 0.1)

				play_footstep()

				if not anim_player.current_animation == "run":
					anim_player.play("run")

	# Apply knockback in all states
	knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_resistance)
	move_and_slide()

func start_attack():
	bodies_in_hitbox.clear()
	anim_player.play("attack")
	play_attack()
	
func check_morale():
	if morale <= flee_threshold and not is_fleeing:
		# 30% chance to flee
		if randf() <= flee_chance:
			start_fleeing()
			
func start_fleeing():
	is_fleeing = true
	current_state = EnemyState.FLEE
	find_flee_destination()
	play_flee()
	# Ignore player detection while fleeing
	player_in_range = false
	player_ref = null

func _on_ally_hurt():
	if current_state == EnemyState.IDLE:
		# Check if player is within awareness range
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var player = players[0]
			var dist = global_position.distance_to(player.global_position)
			if dist < CHASE_DISTANCE:
				player_ref = player
				current_state = EnemyState.CHASE
	
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
	
	# Only handle rotation if not fleeing
	if current_state != EnemyState.FLEE:
		var direction = target_location - global_position
		direction.y = 0
		
		if direction.length() > 0.001:
			var target = global_position + direction
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
		# Only deal damage if we're actually attacking
		if current_state == EnemyState.ATTACK and anim_player.current_animation == "attack":
			var player = body
			if player.is_blocking and player.is_attack_from_front(global_position):
				# Attack blocked
				bodies_in_hitbox.append(body)
				get_tree().call_group("player", "hurt", 0)
			else:
				# Attack not blocked
				bodies_in_hitbox.append(body)
				get_tree().call_group("player", "hurt", 10)

func _process(delta):
	if not can_play_sound:
		sound_cooldown -= delta
	if sound_cooldown <= 0:
		can_play_sound = true
		sound_cooldown = 1.0
	
	if hit_flash_time > 0:
		hit_flash_time -= delta
		EffectResources.hit_flash_material.set_shader_parameter("flash_strength", hit_flash_time / 0.2)
		
		if hit_flash_time <= 0:
			mesh.material_overlay = null

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
		player_in_range = true
		player_ref = body
		# Force state change immediately if we have line of sight
		sight_ray.target_position = to_local(body.global_position)
		if !sight_ray.is_colliding() or sight_ray.get_collider().is_in_group("player"):
			current_state = EnemyState.CHASE

func _on_detection_zone_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		# Only go to IDLE if we're far enough from player
		var distance = global_position.distance_to(body.global_position)
		if distance > ATTACK_RANGE * 10:  # Give some buffer distance
			current_state = EnemyState.IDLE
