extends VBoxContainer

signal slot_selected(slot: int)

@onready var slot_button = $SlotButton
@onready var equipped_label = $EquippedLabel

var equipment_slot: int

func setup(slot: int, equipped_item_name: String = "Nothing equipped"):
	equipment_slot = slot
	slot_button.text = ItemEnums.EquipmentSlot.keys()[slot]
	equipped_label.text = equipped_item_name

func _ready():
	slot_button.pressed.connect(_on_button_pressed)

func _on_button_pressed():
	slot_selected.emit(equipment_slot)

func update_equipped_item(item_name: String):
	equipped_label.text = item_name
