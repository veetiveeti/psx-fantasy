extends Node
class_name InventoryManager

# Ignore the warning: these signals are used elsewhere
@warning_ignore("unused_signal")
signal item_added(item: ItemResource)
@warning_ignore("unused_signal")
signal item_removed(item: ItemResource)
@warning_ignore("unused_signal")
signal inventory_changed()

# Main inventory storage
var inventory: Array[ItemResource] = []
var capacity: int = 24  # Maximum inventory slots

# Reference to components
@onready var stats_component = get_node("../../StatsComponent")
@onready var equipment_manager = get_node("../../EquipmentManager")
@onready var stat_selection_ui = get_node("../../StatSelectionUi")
@onready var audio_player = get_node("../InventorySounds")

func add_item(item: ItemResource) -> bool:
	# If it's equipment, add it to available equipment instead of inventory
	if item is EquipmentResource:
		var slot = item.equipment_slot
		if not equipment_manager.available_equipment.has(slot):
			equipment_manager.available_equipment[slot] = []
		
		# Add to available equipment if not already there
		if not item in equipment_manager.available_equipment[slot]:
			equipment_manager.available_equipment[slot].append(item)
			emit_signal("item_added", item)
			emit_signal("inventory_changed")
			return true
		return false

	# Check if inventory is full
	if inventory.size() >= capacity and not can_stack_item(item):
		return false
		
	# Try to stack if item is stackable
	if item is ConsumableResource and item.stackable:
		for inv_item in inventory:
			if inv_item.id == item.id:
				inv_item.quantity += 1  # Add 1 instead of item.quantity
				emit_signal("inventory_changed")
				emit_signal("item_added", item)
				return true
	
	# Add as new item if can't stack
	if inventory.size() < capacity:
		if item is ConsumableResource and item.stackable:
			item.quantity = 1  # Set quantity to 1 for new stackable items
		inventory.append(item)
		emit_signal("inventory_changed")
		emit_signal("item_added", item)
		return true
		
	return false

func remove_item(item: ItemResource, quantity: int = 1) -> bool:
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

func can_stack_item(item: ItemResource) -> bool:
	if not item.stackable:
		return false
	
	for inv_item in inventory:
		if inv_item.id == item.id:
			return true
	return false

func use_item(item: ItemResource) -> bool:
	if not inventory.has(item):
		return false
		
	if item.item_type == ItemEnums.ItemType.CONSUMABLE:
		match item.use_effect:
			"stat_increase":
				# Store the original quantity before removing
				var original_quantity = item.quantity
				remove_item(item)  # Remove the item before showing UI to prevent exploits
				
				var inventory_ui = get_node("../CanvasLayer/Control/MarginContainer/InventoryUi")
				if inventory_ui:
					inventory_ui.hide()

				stat_selection_ui.show_stat_options()
				var selected_stat = await stat_selection_ui.stat_selected

				if inventory_ui:
					inventory_ui.show()

				if selected_stat != "" and stats_component.increase_stat(selected_stat):
					if item.sound_path:
						audio_player.stream = load(item.sound_path)
						audio_player.play()
					return true
				
				# Return the item if cancelled (empty stat) or failed
				# Restore the original quantity
				item.quantity = original_quantity - 1 #FIXME
				add_item(item)
				return false

			"heal_hp":
				var player = get_node("../../../Player")

				if player and player.health < stats_component.get_stat("max_health"):
					var heal_amount = item.effect_amount
					var max_health = stats_component.get_stat("max_health")

					# Cap healing to max HP
					player.health = min(player.health + heal_amount, max_health)

					player.healthbar.value = player.health

					if item.sound_path:
						audio_player.stream = load(item.sound_path)
						audio_player.play()

					remove_item(item)
					return true
				return false
	
	return false