extends Node3D
class_name EquipmentManager

# Ignore the warning: this signal is used in Equipment_View
@warning_ignore("unused_signal")
signal equipment_changed(slot: ItemEnums.EquipmentSlot, item: ItemResource)

@onready var skeleton = get_node("../metarig/Skeleton3D")
@onready var current_hitbox: Area3D = null

# Current equipped items
var equipped_items = {}

# Available equipment by slot
var available_equipment = {}

# Reference to the stats component
var stats_component: StatsComponent

# Preload weapon resources
var iron_sword = preload("res://resources/weapons/iron_sword.tres")

func _ready():
	# Find the stats component in the parent (player)
	stats_component = get_parent().get_node("StatsComponent")
	if not stats_component:
		push_error("EquipmentManager: StatsComponent not found in parent node!")

	# Create test equipment
	create_test_equipment()

	# Equip default weapon
	if iron_sword:
		equip_item(iron_sword)

func hide_all_weapons():
	if skeleton:
		print("------ Hiding All Weapons ------")
		for weapon in get_tree().get_nodes_in_group("weapons"):
			print("Found weapon in group: ", weapon.name)
			if weapon.visible:
				print("Hiding weapon: ", weapon.name)
				var hitbox = weapon.find_child("Hitbox", true)
				if hitbox:
					print("Found hitbox for ", weapon.name, " monitoring state: ", hitbox.monitoring)
			weapon.visible = false
			
func equip_item(item: ItemResource) -> bool:
	print("\n====== Equipping Item: ", item.name, " ======")
	
	if not stats_component:
		return false
		
	# Check stat requirements
	for stat_name in item.requirements:
		if stats_component.get_stat(stat_name) < item.requirements[stat_name]:
			return false
	
	# Remove old item if one exists
	if item is EquipmentResource:
		if equipped_items.has(item.equipment_slot):
			print("Unequipping old item from slot: ", item.equipment_slot)
			var old_item = equipped_items[item.equipment_slot]
			if old_item is WeaponResource:
				print("Old item was weapon: ", old_item.weapon_model_name)
				# Ensure old hitbox is properly deactivated
				if current_hitbox:
					current_hitbox.monitoring = false
					current_hitbox.monitorable = false
			unequip_item(item.equipment_slot)
	
	# Handle weapon model visibility if it's a weapon
	if item is WeaponResource and skeleton:
		print("\nHandling weapon equip for: ", item.weapon_model_name)
		
		# Reset current hitbox if it exists
		if current_hitbox:
			current_hitbox.monitoring = false
			current_hitbox.monitorable = false
			current_hitbox = null
		
		hide_all_weapons()
		
		# Show the selected weapon
		var weapon = skeleton.get_node_or_null(item.weapon_model_name)
		if weapon:
			print("Found weapon node: ", weapon.name)
			weapon.visible = true
			
			var new_hitbox = weapon.find_child("Hitbox", true)
			if new_hitbox:
				print("Found new hitbox: ", new_hitbox.get_path())
				print("Hitbox collision layer: ", new_hitbox.collision_layer)
				print("Hitbox collision mask: ", new_hitbox.collision_mask)
				# Force reset hitbox state
				new_hitbox.monitoring = false
				new_hitbox.monitorable = true  # Keep it monitorable but not monitoring
				current_hitbox = new_hitbox
				print("Reset hitbox states - monitoring: false, monitorable: true")
			else:
				print("WARNING: No hitbox found for weapon!")
		else:
			print("ERROR: Could not find weapon node: ", item.weapon_model_name)
	
	# Apply stat bonuses
	for stat_name in item.stats_bonus:
		stats_component.add_equipment_bonus(stat_name, item.stats_bonus[stat_name])
	
	equipped_items[item.equipment_slot] = item
	emit_signal("equipment_changed", item.equipment_slot, item)
	print("Equipment change completed for: ", item.name)
	return true

# Remove an item from a slot
func unequip_item(slot: ItemEnums.EquipmentSlot) -> void:
	if equipped_items.has(slot):
		var item = equipped_items[slot]
		for stat_name in item.stats_bonus:
			stats_component.remove_equipment_bonus(stat_name, item.stats_bonus[stat_name])
		equipped_items.erase(slot)
		emit_signal("equipment_changed", slot, null)

# Get currently equipped item in slot
func get_equipped_item(slot: ItemEnums.EquipmentSlot) -> ItemResource:
	return equipped_items.get(slot)

# Initialize test equipment
func create_test_equipment():
	# Create and store equipment by slot
	available_equipment = {
		ItemEnums.EquipmentSlot.WEAPON: [iron_sword],
		# Other equipment will be added later
	}
	print("Test equipment created")

# Get available equipment for a specific slot
func get_available_equipment(slot: ItemEnums.EquipmentSlot) -> Array:
	if available_equipment.has(slot):
		return available_equipment[slot]
	return []

# Get the next available equipment for a slot
func get_next_equipment(slot: ItemEnums.EquipmentSlot, current_item: ItemResource) -> ItemResource:
	var items = get_available_equipment(slot)
	if items.is_empty():
		return null
		
	if not current_item:
		return items[0]
		
	var current_index = items.find(current_item)
	if current_index == -1 or current_index == items.size() - 1:
		return items[0]
	return items[current_index + 1]

# Get the previous available equipment for a slot
func get_prev_equipment(slot: ItemEnums.EquipmentSlot, current_item: ItemResource) -> ItemResource:
	var items = get_available_equipment(slot)
	if items.is_empty():
		return null
		
	if not current_item:
		return items[-1]
		
	var current_index = items.find(current_item)
	if current_index <= 0:
		return items[-1]
	return items[current_index - 1]