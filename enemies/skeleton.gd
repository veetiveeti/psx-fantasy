extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var stats = $StatsComponent
@onready var healthbar = $SubViewport/EnemyHealthBar
@onready var anim_player = $AnimationPlayer
@onready var hitbox = $Armature/Skeleton3D/axe/axe/Hitbox
@onready var footstep_audio = $FootstepAudioPlayer
@onready var attack_audio = $AttackAudioPlayer
@onready var hurt_audio = $HurtAudioPlayer
@onready var detection_zone = $DetectionZone
@onready var game_manager = get_node("/root/GameManager")
@onready var sight_ray = $RayCast3D
@onready var mesh = $Armature/Skeleton3D/skeleton

enum EnemyState {
	IDLE,    # Standing still
	CHASE,   # Following player
	ATTACK   # Attacking player
}

var current_state = EnemyState.IDLE 

# Core stats
var SPEED = 2.8
var ATTACK_COOLDOWN = 1.2
var ATTACK_RANGE = 0.8
var health = 80

# Hit flash variables
var hit_flash_time = 0.0

# Player tracking variables
var player_in_range = false
var player_ref: Node3D = null
var last_seen_position: Vector3 = Vector3.ZERO
var time_since_last_seen: float = 0.0
var MEMORY_DURATION: float = 3.0
var CHASE_RANGE = 10.0
var CHASE_DISTANCE: float = 10.0  # Chase further
var CLOSE_RANGE = ATTACK_RANGE * 4

# Combat and movement variables
var knockback_velocity = Vector3.ZERO
var knockback_resistance = 0.2
var nav_ready = false
var can_attack = true
var attack_timer = 0.0
var bodies_in_hitbox = []

@warning_ignore("unused_signal")
signal enemy_hurt

# Audio resources
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

# Sound control
var can_play_sound = true
var sound_cooldown = 1.0

func _ready():
	call_deferred("setup_navigation")
	
	# Initialize stats
	stats.set_base_stat("strength", 5)
	stats.set_base_stat("vitality", 6)
	stats.set_base_stat("dexterity", 6)
	stats.set_base_stat("intelligence", 1)

	# Set up derived stats
	health = stats.get_stat("max_health")
	healthbar.max_value = health
	healthbar.value = health

	# Apply stat modifiers
	SPEED = SPEED + (stats.get_stat("dexterity") * 0.1)
	ATTACK_COOLDOWN = ATTACK_COOLDOWN * (1.0 / stats.get_stat("attack_speed"))

	# Connect signals
	stats.stat_changed.connect(_on_stat_changed)

	for ally in get_tree().get_nodes_in_group("skeleton"):
		if ally != self:  # Don't connect to self
			var distance = global_position.distance_to(ally.global_position)
			if distance < CHASE_DISTANCE:  # Only connect to enemies within chase range
				ally.enemy_hurt.connect(_on_ally_hurt)

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

func _physics_process(delta):
	if not GameManager.game_active:
		return

	if !nav_ready:
		return
		
	# Update player tracking
	if player_in_range and player_ref and is_instance_valid(player_ref):
		var dist_to_player = global_position.distance_to(player_ref.global_position)
		
		# Always detect if very close
		if dist_to_player < CLOSE_RANGE:
			last_seen_position = player_ref.global_position
			time_since_last_seen = 0.0
			if current_state == EnemyState.IDLE:
				current_state = EnemyState.CHASE
		# Otherwise use distance check
		elif dist_to_player < CHASE_RANGE:
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
					if not anim_player.current_animation == "attack":
						anim_player.play("run")
						play_footstep()

					velocity = new_velocity + knockback_velocity
				
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
				velocity = knockback_velocity
			else:
				current_state = EnemyState.CHASE

	# Apply knockback in all states
	knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_resistance)
	move_and_slide()

func start_attack():
	bodies_in_hitbox.clear()
	anim_player.play("attack")
	play_attack()

func update_target_location(target_location):
	nav_agent.target_position = target_location
	
	var direction = target_location - global_position
	direction.y = 0
	
	if direction.length() > 0.001:
		var target = global_position + direction
		look_at(target)
		rotation.x = 0  # Keep upright

func hurt(hit_points, knockback_force = Vector3.ZERO):
	var defense = stats.get_stat("physical_defense")
	var damage_reduction = defense / (defense + 100.0)
	var final_damage = hit_points * (1.0 - damage_reduction)

	emit_signal("enemy_hurt")

	if final_damage < health:
		health -= final_damage
	else:
		health = 0

	healthbar.value = health
	
	# Apply knockback based on strength
	var strength_factor = 1.0 - (stats.get_stat("strength") * 0.01)
	strength_factor = clamp(strength_factor, 0.1, 1.0)
	knockback_velocity = knockback_force * strength_factor

	hit_flash_time = 0.2
	mesh.material_overlay = EffectResources.hit_flash_material

	play_hurt()

	if health <= 0:
		die()
		
func die():
	queue_free()

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

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "attack":
		hitbox.set_deferred("monitoring", false)
	if distance_to_player() < ATTACK_RANGE:
		anim_player.play("idle")
	else:
		anim_player.play("run")

func distance_to_player() -> float:
	return global_transform.origin.distance_to(nav_agent.target_position)

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") and not body in bodies_in_hitbox:
		if current_state == EnemyState.ATTACK and anim_player.current_animation == "attack":
			var player = body
			
			if player.is_blocking and player.is_attack_from_front(global_position):
				# Attack blocked
				bodies_in_hitbox.append(body)
				get_tree().call_group("player", "hurt", 0)
			else:
				# Attack not blocked - calculate damage based on strength
				bodies_in_hitbox.append(body)
				var base_damage = 10.0
				var strength_bonus = stats.get_stat("strength") * 0.5
				var final_damage = base_damage + strength_bonus
				get_tree().call_group("player", "hurt", final_damage)

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

func _on_detection_zone_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		current_state = EnemyState.CHASE
		
func _on_detection_zone_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		var distance = global_position.distance_to(body.global_position)
		if distance > CHASE_RANGE:
			current_state = EnemyState.IDLE
