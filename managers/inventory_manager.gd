extends Node
class_name InventoryManager


signal item_added(item: InventoryItem)
signal item_removed(item: InventoryItem)
signal inventory_changed()

class InventoryItem:
	var id: String
	var name: String
	var description: String
	var stackable: bool
	var quantity: int
	var item_type: ItemType
	var icon_path: String
	var on_use: Callable  # Function to call when item is used
	
	func _init(p_id: String, p_name: String, p_description: String, p_stackable: bool = false):
		id = p_id
		name = p_name
		description = p_description
		stackable = p_stackable
		quantity = 1

enum ItemType {
	CONSUMABLE,  # Pneuma ambers, potions, etc
	EQUIPMENT,   # Weapons, armor
	QUEST,       # Quest items
	KEY,         # Important non-stackable items
	MATERIAL     # Crafting materials (if you add crafting)
}

# Main inventory storage
var inventory: Array[InventoryItem] = []
var capacity: int = 24  # Maximum inventory slots

# Reference to equipment manager for equippable items
@onready var stats_component = get_node("../../StatsComponent")
@onready var equipment_manager = get_node("../../EquipmentManager")

func add_item(item: InventoryItem) -> bool:
	# Check if inventory is full
	if inventory.size() >= capacity and not can_stack_item(item):
		return false
		
	# Try to stack if item is stackable
	if item.stackable:
		for inv_item in inventory:
			if inv_item.id == item.id:
				inv_item.quantity += item.quantity
				emit_signal("inventory_changed")
				emit_signal("item_added", item)
				return true
	
	# Add as new item if can't stack
	if inventory.size() < capacity:
		inventory.append(item)
		emit_signal("inventory_changed")
		emit_signal("item_added", item)
		return true
		
	return false

func remove_item(item: InventoryItem, quantity: int = 1) -> bool:
	for inv_item in inventory:
		if inv_item.id == item.id:
			if inv_item.stackable:
				inv_item.quantity -= quantity
				if inv_item.quantity <= 0:
					inventory.erase(inv_item)
			else:
				inventory.erase(inv_item)
			
			emit_signal("inventory_changed")
			emit_signal("item_removed", item)
			return true
	return false

func can_stack_item(item: InventoryItem) -> bool:
	if not item.stackable:
		return false
	
	for inv_item in inventory:
		if inv_item.id == item.id:
			return true
	return false

func use_item(item: InventoryItem) -> bool:
	if not inventory.has(item):
		return false
		
	# Execute the item's use function
	if item.on_use.is_valid():
		var success = item.on_use.call()
		if success:
			remove_item(item)
			return true
	
	return false

# Example: Create a pneuma amber
func create_pneuma_amber(stat_type: String) -> InventoryItem:
	var amber = InventoryItem.new(
		"pneuma_" + stat_type.to_lower(),
		stat_type.capitalize() + " Pneuma Amber",
		"A crystallized essence that can increase " + stat_type.capitalize() + ".",
		true  # Stackable
	)
	amber.item_type = ItemType.CONSUMABLE
	amber.icon_path = "res://items/textures/pneuma_amber.png"
	
	# Set the use function
	amber.on_use = func():
		return stats_component.increase_stat(stat_type.to_lower(), 1)
	
	return amber

# Example: Create a health potion
func create_health_potion() -> InventoryItem:
	var potion = InventoryItem.new(
		"health_potion",
		"Health Potion",
		"Restores 50 health points.",
		true
	)
	potion.item_type = ItemType.CONSUMABLE
	potion.icon_path = "res://textures/items/health_potion.png"
	
	# Set the use function
	potion.on_use = func():
		var player = get_parent()
		if player.health < player.max_health:
			player.health = min(player.health + 50, player.max_health)
			return true
		return false
	
	return potion
