extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var healthbar = $SubViewport/EnemyHealthBar
@onready var anim_player = $AnimationPlayer
@onready var hitbox = $Armature/Skeleton3D/axe/axe/Hitbox
@onready var footstep_audio = $FootstepAudioPlayer
@onready var attack_audio = $AttackAudioPlayer
@onready var hurt_audio = $HurtAudioPlayer

var SPEED = 4.3
var ATTACK_COOLDOWN = 2.2  # Seconds between attacks
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
var sound_cooldown = 1.0  # 1 second cooldown

func _ready():
	call_deferred("setup_navigation")

func setup_navigation():
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav_ready = true

func hurt(hit_points, knockback_force=Vector3.ZERO):
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
	if !nav_ready:
		return
	
	# Handle attack cooldown
	if !can_attack:
		attack_timer += delta
		if attack_timer >= ATTACK_COOLDOWN:
			can_attack = true
			attack_timer = 0.0
		
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * SPEED
	
	var distance_to_target = current_location.distance_to(nav_agent.target_position)
	
	if distance_to_target < 1.0:
		if can_attack:
			start_attack()
			can_attack = false
			attack_timer = 0.0
		elif not anim_player.current_animation == "attack":
			anim_player.play("idle")  # Play idle when in range but can't attack yet
	else:
		nav_agent.set_velocity(new_velocity)
		if not anim_player.current_animation == "attack":
			anim_player.play("run")
			play_footstep()
	
	# Apply base movement and knockback
	velocity = new_velocity + knockback_velocity
	knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_resistance)
	
	move_and_slide()

func start_attack():
	bodies_in_hitbox.clear()  # Clear the list before each attack
	anim_player.play("attack")
	play_attack()
	hitbox.set_deferred("monitoring", true)  # Use set_deferred for physics properties

func update_target_location(target_location):
	nav_agent.target_position = target_location
	look_at(target_location)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "attack":
		hitbox.set_deferred("monitoring", false)  # Use set_deferred here too
	if distance_to_player() < 2.0:
		anim_player.play("idle")
	else:
		anim_player.play("run")

func distance_to_player() -> float:
	return global_transform.origin.distance_to(nav_agent.target_position)

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") and not body in bodies_in_hitbox:
		bodies_in_hitbox.append(body)
		get_tree().call_group("player", "hurt", 10)

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
