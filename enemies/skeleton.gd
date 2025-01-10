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

enum EnemyState {
	IDLE,    # Standing still
	PATROL,  # Walking preset paths
	CHASE,   # Following player
	ATTACK   # Attacking player
}

var current_state = EnemyState.IDLE 

var SPEED = 3.8
var ATTACK_COOLDOWN = 1.5 # Seconds between attacks
var ATTACK_RANGE = 0.8
var health = 50
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
	stats.set_base_stat("strength", 5)
	stats.set_base_stat("vitality", 6)
	stats.set_base_stat("dexterity", 6)
	stats.set_base_stat("intelligence", 1)


	health = stats.get_stat("max_health")  # This will now use the proper vitality-based health
	healthbar.max_value = health           # Make sure healthbar matches
	healthbar.value = health               # Set initial health

	SPEED = 3.8 + (stats.get_stat("dexterity") * 0.1)
	ATTACK_COOLDOWN = 1.5 * (1.0 / stats.get_stat("attack_speed"))

	stats.stat_changed.connect(_on_stat_changed)

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

	if final_damage < health:
		health -= final_damage
	else:
		health = 0

	# Update healthbar
	healthbar.value = health
	print("New health: ", health)

	# Apply knockback
	var strength_factor = 1.0 - (stats.get_stat("strength") * 0.01)
	strength_factor = clamp(strength_factor, 0.1, 1.0)
	knockback_velocity = knockback_force * strength_factor

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

	# Apply knockback in all states
	knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_resistance)
	move_and_slide()

func start_attack():
	bodies_in_hitbox.clear()
	anim_player.play("attack")
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
		var base_damage = 10.0
		var strength_bonus = stats.get_stat("strength") * 0.5  # Each point of strength adds 0.5 damage
		var final_damage = base_damage + strength_bonus

		if player.is_blocking and player.is_attack_from_front(global_position):
			# Attack blocked
			bodies_in_hitbox.append(body)
			get_tree().call_group("player", "hurt", 0)
		else:
			# Attack not blocked (from behind or not blocking)
			bodies_in_hitbox.append(body)
			get_tree().call_group("player", "hurt", final_damage)

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
