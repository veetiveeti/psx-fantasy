extends Node3D
signal coin_collected(value)

@onready var coin_audio = $CoinSounds

var collected = false

var coin_sounds = [
    preload("res://sounds/coin3.wav")
]

func _process(delta):
    rotate_y(2.0 * delta)
    
func _on_area_3d_body_entered(body):
    if body.is_in_group("player") and not collected:
        collected = true
        play_coin()
        coin_collected.emit(1)  # Emit signal with coin value
        await coin_audio.finished
        queue_free()  # Remove the coin
        
func play_coin():
    coin_audio.stream = coin_sounds[randi() % coin_sounds.size()]
    coin_audio.play()
