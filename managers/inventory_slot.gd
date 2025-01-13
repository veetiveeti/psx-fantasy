extends Panel

@onready var icon = $MarginContainer/Icon
@onready var quantity_label = $QuantityLabel

func set_item(item: ConsumableResource):
	icon.texture = load(item.texture_path)
	if item.stackable:
		quantity_label.text = str(item.quantity)
		quantity_label.show()
	else:
		quantity_label.hide()

func clear():
	icon.texture = null
	quantity_label.hide()
