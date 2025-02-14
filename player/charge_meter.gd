extends Control

@onready var progress_bar = $ProgressBar

func update_charge(charge_time: float, is_charging: bool) -> void:
	if not is_charging:
		progress_bar.value = 0
		return
		
	show()
	
	# Calculate percentage (0 to 100)
	var percentage = (charge_time / 1.0) * 100
	progress_bar.value = percentage