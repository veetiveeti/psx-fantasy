extends Control
class_name InventoryUI

@onready var tab_container = $TabContainer
@onready var items_view = $TabContainer/ItemsView
@onready var equipment_view = $TabContainer/EquipmentView
@onready var grid_container = $TabContainer/ItemsView/PanelContainer/MarginContainer/GridContainer
@onready var inventory_manager = get_node("../../../../InventoryManager")
@onready var interaction_audio = get_node("../../../../InventorySounds")

var slot_scene = preload("res://managers/inventory_slot.tscn")
var slots: Array[Control] = []

func _ready():
	setup_ui_style()
	
	if not inventory_manager:
		push_error("InventoryManager not found!")
		return
	
	print("Setting up inventory UI...")
	
	# Connect to tab change signal
	tab_container.tab_changed.connect(_on_tab_changed)
	
	# Connect inventory signals
	inventory_manager.inventory_changed.connect(_on_inventory_changed)
	inventory_manager.item_added.connect(_on_item_added)
	inventory_manager.item_removed.connect(_on_item_removed)
	
	# Setup items grid
	_setup_items_grid()
	refresh_inventory()  # Make sure to refresh initially
	
	# Make sure both views exist
	if not items_view:
		push_error("ItemsView not found!")
	if not equipment_view:
		push_error("EquipmentView not found!")
	

	
	print("Inventory UI setup complete")

func setup_ui_style():
	
	# Tab settings
	tab_container.set_tab_title(0, "Items")
	tab_container.set_tab_title(1, "Equipment & Abilities")
	tab_container.tab_alignment = TabBar.ALIGNMENT_LEFT

func _setup_items_grid():
	if not grid_container:
		push_error("GridContainer not found!")
		return
		
	print("Setting up items grid...")
	
	# Create inventory slots
	for i in range(inventory_manager.capacity):
		var slot = slot_scene.instantiate()
		grid_container.add_child(slot)
		slots.append(slot)
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
	
	print("Created %d inventory slots" % slots.size())

func _on_tab_changed(tab_index: int):
	
	match tab_index:
		0:  # Items tab
			equipment_view.hide()
			items_view.show()
			refresh_inventory()  # Refresh when showing items
			play_interaction()
		1:  # Equipment tab
			equipment_view.show()
			items_view.hide()
			play_interaction()

func refresh_inventory():
	if not grid_container:
		push_error("Cannot refresh inventory - GridContainer not found!")
		return
		
	print("Refreshing inventory...")
	
	for slot in slots:
		slot.clear()
	
	for i in range(inventory_manager.inventory.size()):
		var item = inventory_manager.inventory[i]
		if item:
			print("Setting item %s in slot %d" % [item.name, i])
			slots[i].set_item(item)

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
				MOUSE_BUTTON_LEFT:  # Use item
					if item:
						print("Attempting to use item: ", item.name)
						print("Item Type: ", item.get_class())
						print("Use effect: ", item.use_effect if item is ConsumableResource else "not consumable")
						inventory_manager.use_item(item)

func play_interaction():
	interaction_audio.stream = UiAudioManager.menu_sounds.interaction
	interaction_audio.play()
