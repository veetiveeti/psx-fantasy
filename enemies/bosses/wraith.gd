extends CharacterBody3D

enum BossState {
	INACTIVE,           # Before boss is awakened
	SPAWN,             # Initial spawn animation
	IDLE,              # Default state, choosing next action
	CHASE,             # Moving towards player
	MELEE_ATTACK,      # Claw attack with poison
	POISON_CLOUD,      # Small poison cloud spell
	MAGIC_MISSILE,     # Direct magic attack
	ULTIMATE_CHARGING, # Preparing big AoE attack
	ULTIMATE_CAST,     # Casting the floor poison
}

# Node references
@onready var anim_player = $AnimationPlayer
@onready var nav_agent = $NavigationAgent3D
@onready var stats = $StatsComponent
@onready var healthbar = $ColorRect/EnemyHealthBar
@onready var healthbar_container = $ColorRect
@onready var detection_zone = $DetectionZone
@onready var mesh = $Armature/Skeleton3D/Cube
@onready var armature = $Armature
@onready var hitbox = $Armature/Skeleton3D/BoneAttachment3D/Hitbox
@onready var missile_position = $Armature/Skeleton3D/BoneAttachment3D2/missile_position
@onready var game_manager = get_node("/root/GameManager")
@onready var boss_theme_audio = $BossThemePlayer
@onready var hurt_audio = $HurtSounds
@onready var spell_audio = $SpellSounds
@onready var attack_audio = $AttackSounds
@onready var other_audio = $OtherSounds

var boss_theme_sound = preload("res://sounds/ds2.wav")
var hurt_sounds = [
	preload("res://enemies/bosses/wraith_sounds/shade13.wav"),
	preload("res://enemies/bosses/wraith_sounds/shade10.wav"),
	preload("res://enemies/bosses/wraith_sounds/shade14.wav")
]
var magic_missile_sound = preload("res://enemies/bosses/wraith_sounds/Spell_02.wav")
var poison_mist_sound = preload("res://enemies/bosses/wraith_sounds/hurt.mp3")
var melee_sound = preload("res://enemies/bosses/wraith_sounds/melee.wav")
var other_sound = preload("res://enemies/bosses/wraith_sounds/groan.mp3")

# Movement variables
var MOVE_SPEED = 3.0
var ROTATION_SPEED = 5.0
var current_state = BossState.INACTIVE
var player_ref: Node3D = null
var gravity = 9.8

# Combat variables
var can_attack = true
var current_attack_cooldown = 0.0
const MELEE_COOLDOWN = 1.0
const POISON_COOLDOWN = 3.0
const MISSILE_COOLDOWN = 4.0
const ULTIMATE_COOLDOWN = 15.0
var bodies_in_hitbox = []

# Base damage values
const MELEE_BASE_DAMAGE = 25.0
const ULTIMATE_BASE_DAMAGE = 50.0

# Attack ranges
const MELEE_RANGE = 0.8
const SPELL_RANGE = 4.0
const ULTIMATE_RANGE = 15.0

# Projectile scenes
const POISON_CLOUD = preload("res://enemies/bosses/wraith_effects/poison_mist.tscn")
const MAGIC_MISSILE = preload("res://enemies/bosses/wraith_effects/magic_missile.tscn")

# Attack pattern variables
var attack_pattern = []
var current_pattern_index = 0
var time_in_state = 0.0
var ultimate_charge_time = 2.0
var ultimate_duration = 6.0

# Hit flash variables
var hit_flash_time = 0.0

func _ready():
	print("Boss initializing...")
	current_state = BossState.INACTIVE
	
	# Hide boss initially
	visible = false
	if armature:
		armature.visible = false
		print("Found and hidden armature")
	if mesh:
		mesh.visible = false
		print("Found and hidden mesh")
	if healthbar_container:
		healthbar_container.visible = false
	print("Initial visibility - Node: ", visible, " Armature: ", armature.visible if armature else "null", " Mesh: ", mesh.visible if mesh else "null")

	# Set up base stats for the boss
	stats.set_base_stat("strength", 20)
	stats.set_base_stat("vitality", 36)
	stats.set_base_stat("dexterity", 25)
	stats.set_base_stat("intelligence", 34)
	
	# Set up initial attack pattern
	setup_attack_pattern()
	
	# Connect signals
	detection_zone.body_entered.connect(_on_detection_zone_body_entered)
	detection_zone.body_exited.connect(_on_detection_zone_body_exited)
	
	# Connect to altar fires
	print("Looking for altar fires...")
	var fires = get_tree().get_nodes_in_group("altar_fires")
	print("Found ", fires.size(), " altar fires")
	
	for fire in fires:
		print("Connecting to fire: ", fire)
		if fire.has_signal("extinguished"):
			fire.extinguished.connect(_on_fire_extinguished)
			print("Successfully connected to fire")
		else:
			print("Fire does not have extinguished signal!")
			
	# Initialize health from stats
	healthbar.max_value = stats.get_stat("max_health")
	healthbar.value = stats.get_stat("max_health")

	print("Boss initialization complete")

func setup_attack_pattern():
	attack_pattern = [
		"magic_missile",
		"magic_missile",
		"poison_cloud",
		"melee",
		"magic_missile",
		# "ultimate"
	]

func _process(delta):
	if hit_flash_time > 0:
		hit_flash_time -= delta
		EffectResources.hit_flash_material.set_shader_parameter("flash_strength", hit_flash_time / 0.2)
	
	if hit_flash_time <= 0:
		mesh.material_overlay = null

func _physics_process(delta):
	if not GameManager.game_active:
		return

	if current_state == BossState.INACTIVE:
		return
		
	time_in_state += delta
	
	# Force state update if stuck in state too long
	if time_in_state > 3.0 and current_state != BossState.IDLE:
		print("State timeout - returning to IDLE")
		current_state = BossState.IDLE
		time_in_state = 0.0
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	# Print debug info every second
	if Engine.get_physics_frames() % 60 == 0:
		print("Current state: ", BossState.keys()[current_state])
		print("Current position: ", global_position)
		print("Current visibility: ", visible)
	
	# Update attack cooldowns
	if current_attack_cooldown > 0:
		current_attack_cooldown -= delta

	# State machine
	match current_state:
		BossState.SPAWN:
			handle_spawn_state(delta)
		BossState.IDLE:
			handle_idle_state(delta)
		BossState.CHASE:
			handle_chase_state(delta)
		BossState.MELEE_ATTACK:
			handle_melee_state(delta)
		BossState.POISON_CLOUD:
			handle_poison_cloud_state(delta)
		BossState.MAGIC_MISSILE:
			handle_magic_missile_state(delta)
	
	move_and_slide()

func calculate_damage(base_damage: float, is_magical: bool = false) -> float:
	var total_damage = base_damage
	
	if is_magical:
		total_damage += stats.get_stat("intelligence") * 0.5
	else:
		total_damage += stats.get_stat("strength") * 0.5
		
	return total_damage

func choose_next_attack():
	var attacks = {
		"melee": BossState.MELEE_ATTACK,
		"poison_cloud": BossState.POISON_CLOUD,
		"magic_missile": BossState.MAGIC_MISSILE,
		# "ultimate": BossState.ULTIMATE_CHARGING
	}
	
	current_pattern_index = (current_pattern_index + 1) % attack_pattern.size()
	var next_attack = attack_pattern[current_pattern_index]
	print("Choosing next attack: ", next_attack)
	
	return attacks[next_attack]

func handle_spawn_state(_delta):
	if time_in_state == 0.0:
		print("Spawn state entered at time 0")
		print("Position at spawn start: ", global_position)
		
		# Show everything
		visible = true
		if armature:
			armature.visible = true
		if mesh:
			mesh.visible = true
		if healthbar_container:
			healthbar_container.visible = true
		
		anim_player.play("idle")
		
	print("In spawn state, time: ", time_in_state)
	if time_in_state >= 3.0:
		print("Transitioning to IDLE from SPAWN")
		current_state = BossState.IDLE
		time_in_state = 0.0

func handle_idle_state(_delta):
	if not anim_player.current_animation == "idle":
		anim_player.play("idle")
	
	velocity.x = 0
	velocity.z = 0
		
	if player_ref and is_instance_valid(player_ref):
		var distance = global_position.distance_to(player_ref.global_position)
		print("IDLE: Distance to player = ", distance)
		
		# If player is very far away, always chase
		if distance > SPELL_RANGE * 1.5:
			print("IDLE: Player too far, initiating chase")
			current_state = BossState.CHASE
			return
			
		# If we can attack, choose based on distance
		if current_attack_cooldown <= 0:
			print("IDLE: Attack ready, choosing action")
			# Close range - heavily prefer melee
			if distance <= MELEE_RANGE * 1.5:
				print("IDLE: In close range, choosing melee")
				current_state = BossState.MELEE_ATTACK
			# Medium range - mix of chase and spells
			elif distance <= SPELL_RANGE:
				if randf() < 0.3:  # 40% chance to chase for melee
					print("IDLE: Medium range, choosing to chase")
					current_state = BossState.CHASE
				else:
					print("IDLE: Medium range, choosing spell")
					current_state = choose_random_spell()
			else:
				print("IDLE: Long range, choosing to chase")
				current_state = BossState.CHASE
			time_in_state = 0.0
		# If on cooldown and not too close, chase
		elif distance > MELEE_RANGE * 2:
			print("IDLE: On cooldown and not close, choosing to chase")
			current_state = BossState.CHASE

func choose_action_by_distance(distance: float) -> BossState:
	# Very close - prefer melee but might use spells
	if distance <= MELEE_RANGE * 1:
		# 70% chance for melee, 30% chance for spells
		if randf() < 0.6:
			return BossState.MELEE_ATTACK
		else:
			return choose_random_spell()
	
	# Medium range - prefer spells but might chase for melee
	elif distance <= SPELL_RANGE:
		# 80% chance for spells, 20% chance to chase for melee
		if randf() < 0.8:
			return choose_random_spell()
		else:
			return BossState.CHASE
	
	# Long range - mix of chasing and long-range spells
	else:
		# 40% chance to chase, 60% chance for spells
		if randf() < 0.4:
			return BossState.CHASE
		else:
			return choose_random_spell()

func choose_random_spell() -> BossState:
	var spells = [BossState.POISON_CLOUD, BossState.MAGIC_MISSILE, BossState.POISON_CLOUD]
	var chosen = spells[randi() % spells.size()]
	print("Chose random spell: ", BossState.keys()[chosen])
	return chosen

func handle_chase_state(_delta):
	if not player_ref or not is_instance_valid(player_ref):
		current_state = BossState.IDLE
		return
		
	if not anim_player.current_animation == "run":
		anim_player.play("run")
		
	var direction = player_ref.global_position - global_position
	var raw_distance = direction.length()
	
	# Project the direction to ground plane for movement
	direction.y = 0
	var horizontal_distance = direction.length()
	
	print("CHASE: Distance to player = ", horizontal_distance)
	print("CHASE: Height difference = ", player_ref.global_position.y - global_position.y)
	
	# If close enough horizontally and on same height level, attack
	if horizontal_distance <= MELEE_RANGE and current_attack_cooldown <= 0 and abs(player_ref.global_position.y - global_position.y) < 1.0:
		print("CHASE: In melee range and can attack, switching to melee")
		var possible_states = [BossState.MELEE_ATTACK, BossState.MAGIC_MISSILE]
		current_state = possible_states[randi() % possible_states.size()]
		time_in_state = 0.0
		return
	
	# Use navigation since we need to handle height differences
	nav_agent.target_position = player_ref.global_position
	if nav_agent.is_target_reachable():
		var next_pos = nav_agent.get_next_path_position()
		var move_direction = (next_pos - global_position).normalized()
		velocity.x = move_direction.x * MOVE_SPEED
		velocity.z = move_direction.z * MOVE_SPEED
		# Let gravity handle Y movement
		face_player()
		print("CHASE: Nav movement with velocity ", velocity)
	else:
		# If we can't reach the player, try ranged attacks
		print("CHASE: Can't reach target, using spell")
		if current_attack_cooldown <= 0:
			current_state = choose_random_spell()
			time_in_state = 0.0

func handle_melee_state(_delta):
	velocity.x = 0
	velocity.z = 0
	
	if time_in_state < 0.8:  # Windup
		if not anim_player.current_animation == "spell_02":
			play_attack()
			anim_player.play("spell_02")
		face_player()
		hitbox.set_deferred("monitoring", false)  # Make sure hitbox is off during windup
	elif time_in_state < 1:  # Attack
		hitbox.set_deferred("monitoring", true)  # Enable hitbox for damage
	else:
		current_attack_cooldown = MELEE_COOLDOWN
		current_state = BossState.IDLE
		hitbox.set_deferred("monitoring", false)
		bodies_in_hitbox.clear()  # Clear list for next attack
		time_in_state = 0.0

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") and not body in bodies_in_hitbox:
		# Only deal damage if we're actually in melee attack state
		if current_state == BossState.MELEE_ATTACK:
			var player = body
			if player.is_blocking and player.is_attack_from_front(global_position):
				# Attack blocked
				bodies_in_hitbox.append(body)
				var blocked_damage = 0
				player.hurt(blocked_damage, global_position)
			else:
				# Attack not blocked - use our damage calculation system
				bodies_in_hitbox.append(body)
				var damage = calculate_damage(MELEE_BASE_DAMAGE, false)
				player.hurt(damage, global_position)

func handle_poison_cloud_state(_delta):
	velocity.x = 0
	velocity.z = 0
	
	if time_in_state < 1.0:  # Windup
		if not anim_player.current_animation == "spell_01":
			anim_player.play("spell_01")
			play_poison_mist()
		face_player()
	elif time_in_state < 1.2:  # Cast
		shoot_poison_cloud()
		print("Poison cloud cast, returning to IDLE")
		current_state = BossState.IDLE
		current_attack_cooldown = POISON_COOLDOWN
		time_in_state = 0.0
	else:
		# Failsafe - if we somehow get stuck here
		print("Poison cloud state timeout, returning to IDLE")
		current_state = BossState.IDLE
		current_attack_cooldown = POISON_COOLDOWN
		time_in_state = 0.0

func handle_magic_missile_state(_delta):
	velocity.x = 0
	velocity.z = 0
	
	if time_in_state < 1:  # Windup
		if not anim_player.current_animation == "attack":
			anim_player.play("attack")
		face_player()
	elif time_in_state < 1.2:  # Cast
		play_magic_missile()
		shoot_magic_missile()
		current_state = BossState.IDLE  # Return to idle immediately after shooting
		current_attack_cooldown = MISSILE_COOLDOWN
		time_in_state = 0.0

func face_player():
	if player_ref and is_instance_valid(player_ref):
		var direction = player_ref.global_position - global_position
		var target_rotation = atan2(direction.x, direction.z) + PI  # Add PI to face forward
		rotation.y = lerp_angle(rotation.y, target_rotation, ROTATION_SPEED * get_physics_process_delta_time())

func shoot_poison_cloud():
	if player_ref and is_instance_valid(player_ref):
		print("Shooting poison cloud")
		
		# Calculate direction to player
		var direction = (player_ref.global_position - global_position).normalized()
		
		# Create cloud instance
		var cloud = POISON_CLOUD.instantiate()
		get_tree().current_scene.add_child(cloud)
		
		# Set cloud position slightly higher and in front
		var spawn_pos = global_position + direction * 2.0
		spawn_pos.y += 1.0  # Raise just a bit off the ground
		
		# Initialize with direction
		cloud.initialize(spawn_pos, direction)

func shoot_magic_missile():
	if player_ref and is_instance_valid(player_ref):
		print("Shooting magic missiles")
		
		# Calculate base direction to player
		var base_direction = (player_ref.global_position - missile_position.global_position).normalized()
		
		# Define spread angles (in radians)
		var angles = [0, PI/4, -PI/4, PI/16, -PI/16]  # Center, 45 degrees right, 45 degrees left
		
		# Spawn three missiles
		for angle in angles:
			# Rotate the base direction by the angle
			var missile_direction = base_direction.rotated(Vector3.UP, angle)
			
			# Create missile instance
			var missile = MAGIC_MISSILE.instantiate()
			get_tree().current_scene.add_child(missile)
			
			# Set missile position to muzzle position
			var spawn_pos = missile_position.global_position
			
			# Initialize missile with direction
			missile.initialize(spawn_pos, missile_direction)

			
			print("Spawned missile at angle:", rad_to_deg(angle))

func _on_fire_extinguished():
	print("Fire extinguished signal received")
	var fires_remaining = get_tree().get_nodes_in_group("altar_fires").size() - 1
	print("Fires remaining: ", fires_remaining)
	
	if fires_remaining <= 0:
		print("All fires out, spawning boss")
		# Set exact spawn position but higher up
		global_position = Vector3(-2.06, -6.0, -0.888)  # Changed Y to be higher
		print("Initial position set to: ", global_position)
		
		# Start spawn sequence and make visible
		visible = true
		if armature:
			armature.visible = true
		if mesh:
			mesh.visible = true
		if healthbar_container:
			await get_tree().create_timer(2.0).timeout
			healthbar_container.visible = true
			
		current_state = BossState.SPAWN
		time_in_state = 0.0
		print("Boss spawn sequence started")
		play_other()
		# play_boss_theme()

func _on_detection_zone_body_entered(body):
	if body.is_in_group("player"):
		print("Player entered detection zone")
		nav_agent.target_position = body.global_position
		if nav_agent.is_target_reachable():
			player_ref = body
			if current_state == BossState.IDLE:
				current_state = BossState.CHASE
		else:
			print("Player detected but not reachable")

func _on_detection_zone_body_exited(body):
	if body.is_in_group("player"):
		print("Player exited detection zone")
		player_ref = null

func hurt(_hit_points: float, _attacker_position: Vector3 = Vector3.ZERO):
	var defense = stats.get_stat("physical_defense")
	var damage_reduction = defense / (defense + 100.0)
	var final_damage = _hit_points * (1.0 - damage_reduction)
	
	print("Boss taking damage: ", final_damage)
	healthbar.value -= final_damage
	play_hurt()

	hit_flash_time = 0.2
	mesh.material_overlay = EffectResources.hit_flash_material
	
	if healthbar.value <= 0:
		die()

func die():
	print("Boss died")
	queue_free()

func play_boss_theme():
		boss_theme_audio.stream = boss_theme_sound
		boss_theme_audio.play()

func play_hurt():
		hurt_audio.stream = hurt_sounds[randi() % hurt_sounds.size()]
		hurt_audio.play()

func play_attack():
		attack_audio.stream = melee_sound
		attack_audio.play()

func play_magic_missile():
		spell_audio.stream = magic_missile_sound
		spell_audio.play()

func play_poison_mist():
		spell_audio.stream = poison_mist_sound
		spell_audio.play()

func play_other():
		other_audio.stream = other_sound
		other_audio.play()
