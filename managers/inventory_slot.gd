extends Panel

@onready var item_name = $HBoxContainer/ItemName
@onready var quantity_label = $HBoxContainer/QuantityLabel
# @onready var icon = $HBoxContainer/Icon

var current_item: ConsumableResource = null
var selected: bool = false:
	set(value):
		selected = value
		# Update visual feedback
		if selected:
			modulate = Color(1.2, 1.2, 1.2)  # Brighten when selected
		else:
			modulate = Color(1, 1, 1)  # Normal color

func set_item(item: ConsumableResource):
	current_item = item
	item_name.text = item.name
	# icon.texture = load(item.texture_path)
	if item.stackable:
		quantity_label.text = str(item.quantity)
		quantity_label.show()
	else:
		quantity_label.hide()

func clear():
	current_item = null
	item_name.text = ''
	# icon.texture = null
	quantity_label.hide()
	selected = false