extends Panel

signal item_used(item: ItemResource)

@onready var icon = $MarginContainer/VBoxContainer/Icon
@onready var item_name_label = $MarginContainer/VBoxContainer/ItemName
@onready var description_label = $MarginContainer/VBoxContainer/Description
@onready var use_button = $MarginContainer/VBoxContainer/UseButton

var current_item: ItemResource = null

func _ready():
	clear_description()

func display_item(item: ItemResource):
	current_item = item
	if item:
		icon.texture = load(item.texture_path)
		item_name_label.text = item.name
		
		if item is ConsumableResource:
			description_label.text = item.description
			use_button.show()
	else:
		clear_description()

func clear_description():
	icon.texture = null
	item_name_label.text = ""
	description_label.text = "Select an item to view its description"
	use_button.hide()
	current_item = null

func _on_use_button_pressed():
	if current_item:
		item_used.emit(current_item)
