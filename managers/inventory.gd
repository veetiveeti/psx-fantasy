extends Node
class_name Inventory

@onready var inventory_manager = $InventoryManager
@onready var inventory_ui = $CanvasLayer/Control/MarginContainer/InventoryUi

func _ready():
	# Ensure we found the UI and manager
	if not inventory_ui:
		push_error("InventoryUI not found!")
		return
		
	if not inventory_manager:
		push_error("InventoryManager not found!")
		return
	
	# Hide UI by default
	inventory_ui.hide()
	
	# Connect to the inventory manager
	inventory_manager.inventory_changed.connect(_on_inventory_changed)

	# Connect to all pickups
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.collected.connect(_on_item_collected)

func _input(event: InputEvent):
	if event.is_action_pressed("inventory"):  # TAB key
		toggle_inventory()

func _on_inventory_changed():
	inventory_ui.refresh_inventory()

func toggle_inventory():
	if inventory_ui.visible:
		inventory_ui.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		inventory_ui.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# Public methods to interact with inventory
func add_item(item: ItemResource) -> bool:
	if not inventory_manager:
		return false
	return inventory_manager.add_item(item)

func _on_item_collected(item: ItemResource):
	if add_item(item):
		print("Picked up ", item.name)


func remove_item(item: ItemResource, quantity: int = 1) -> bool:
	if not inventory_manager:
		return false
	return inventory_manager.remove_item(item, quantity)

func has_item(item_id: String) -> bool:
	if not inventory_manager:
		return false
	for item in inventory_manager.inventory:
		if item.id == item_id:
			return true
	return false