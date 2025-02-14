extends Control
class_name InventoryUI

@onready var tab_container = $TabContainer
@onready var items_view = $TabContainer/ItemsView
@onready var equipment_view = $TabContainer/EquipmentView
@onready var items_container = $TabContainer/ItemsView/PanelContainer/HBoxContainer/MarginContainer/ScrollContainer/ItemsContainer
@onready var item_description = $TabContainer/ItemsView/PanelContainer/HBoxContainer/ItemDescription
@onready var inventory_manager = get_node("../../../../InventoryManager")
@onready var interaction_audio = get_node("../../../../InventorySounds")

var slot_scene = preload("res://managers/inventory_slot.tscn")
var slots: Array[Control] = []
var selected_slot_index: int = -1

func _ready():
	setup_ui_style()
	
	if not inventory_manager:
		push_error("InventoryManager not found!")
		return
	
	# Connect signals
	tab_container.tab_changed.connect(_on_tab_changed)
	inventory_manager.inventory_changed.connect(_on_inventory_changed)
	inventory_manager.item_added.connect(_on_item_added)
	inventory_manager.item_removed.connect(_on_item_removed)
	item_description.item_used.connect(_on_item_use_pressed)
	
	print("Inventory UI setup complete")

func setup_ui_style():
	tab_container.set_tab_title(0, "Items")
	tab_container.set_tab_title(1, "Equipment & Abilities")
	tab_container.tab_alignment = TabBar.ALIGNMENT_LEFT

func create_slot_for_item(item: ConsumableResource) -> Control:
	var slot = slot_scene.instantiate()
	items_container.add_child(slot)
	slots.append(slot)
	slot.gui_input.connect(_on_slot_gui_input.bind(slots.size() - 1))
	slot.set_item(item)
	return slot

func refresh_inventory():
	if not items_container:
		push_error("Cannot refresh inventory - Items container not found!")
		return
		
	print("Refreshing inventory...")
	
	# Clear existing slots
	for slot in slots:
		slot.queue_free()
	slots.clear()
	
	# Create slots only for existing items
	for item in inventory_manager.inventory:
		create_slot_for_item(item)

func _on_tab_changed(tab_index: int):
	match tab_index:
		0:  # Items tab
			equipment_view.hide()
			items_view.show()
			refresh_inventory()
			play_interaction()
		1:  # Equipment tab
			equipment_view.show()
			items_view.hide()
			play_interaction()

func _on_inventory_changed():
	refresh_inventory()

func _on_item_added(item):
	print("Item added: %s" % item.name)
	refresh_inventory()

func _on_item_removed(item):
	print("Item removed: %s" % item.name)
	refresh_inventory()

func _on_slot_gui_input(event: InputEvent, slot_index: int):
	if event is InputEventMouseButton and event.pressed:
		if slot_index < inventory_manager.inventory.size():
			var item = inventory_manager.inventory[slot_index]
			match event.button_index:
				MOUSE_BUTTON_LEFT:  # Select item
					selected_slot_index = slot_index
					# Update visuals for selected slot
					for i in range(slots.size()):
						slots[i].selected = (i == selected_slot_index)
					# Display item description
					item_description.display_item(item)
					play_interaction()

func _on_item_use_pressed(item: ItemResource):
	if item:
		inventory_manager.use_item(item)

func play_interaction():
	interaction_audio.stream = UiAudioManager.menu_sounds.interaction
	interaction_audio.play()