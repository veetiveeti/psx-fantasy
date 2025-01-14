extends PanelContainer

@onready var icon = $MarginContainer/HBoxContainer/ItemIcon
@onready var text = $MarginContainer/HBoxContainer/ItemText

func show_popup(item: ItemResource):
	# Set up the popup
	icon.texture = load(item.texture_path)
	text.text = item.name + " acquired"
	
	# Show and start fade timer
	modulate.a = 2.0
	show()
	
	# Create tween for fade out
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 50, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)  # Remove after animation