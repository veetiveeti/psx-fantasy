extends Node3D
class_name EquipmentManager

# Ignore the warning: this signal is used in Equipment_View
@warning_ignore("unused_signal")
signal equipment_changed(slot: int, item: ItemResource)

@onready var skeleton = get_node("../metarig/Skeleton3D")
@onready var current_hitbox: Area3D = null

enum EquipmentSlot {
    WEAPON,
    SHIELD,
    HEAD,
    CHEST,
    LEGS,
    BOOTS,
    ACCESSORY
}

# Current equipped items
var equipped_items = {}

# Available equipment by slot
var available_equipment = {}

# Reference to the stats component
var stats_component: StatsComponent

# Preload weapon resources
var iron_sword = preload("res://resources/weapons/iron_sword.tres")
var iron_mace = preload("res://resources/weapons/iron_mace.tres")

class Item:
    var id: String
    var name: String
    var slot: EquipmentSlot
    var stats_bonus = {}  # Dictionary of stat bonuses
    var requirements = {}  # Dictionary of stat requirements
    var texture_path: String  # Path to the 3D model scene
    
    func _init(p_id: String, p_name: String, p_slot: EquipmentSlot):
        id = p_id
        name = p_name
        slot = p_slot

class Weapon extends Item:
    var base_damage: float
    var attack_speed: float
    var weapon_range: float
    
    func _init(p_id: String, p_name: String):
        super(p_id, p_name, EquipmentSlot.WEAPON)

class Armor extends Item:
    var physical_defense: float
    var magic_defense: float
    
    func _init(p_id: String, p_name: String, p_slot: EquipmentSlot):
        super(p_id, p_name, p_slot)

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
        for weapon in get_tree().get_nodes_in_group("weapons"):
            weapon.visible = false

# Try to equip an item
func equip_item(item: ItemResource) -> bool:
    if not stats_component:
        return false
        
    # Check stat requirements
    for stat_name in item.requirements:
        if stats_component.get_stat(stat_name) < item.requirements[stat_name]:
            return false
    
    # Remove old item if one exists
    if equipped_items.has(item.item_type):
        unequip_item(item.item_type)
    
    # Apply stat bonuses
    for stat_name in item.stats_bonus:
        stats_component.add_equipment_bonus(stat_name, item.stats_bonus[stat_name])

    # Handle weapon model visibility if it's a weapon
    if item is WeaponResource and skeleton:
        hide_all_weapons()

        # Show the selected weapon
        var weapon = skeleton.get_node_or_null(item.weapon_model_name)
        if weapon:
            weapon.visible = true
            # Update hitbox reference
            current_hitbox = weapon.find_child("Hitbox", true)
    
    equipped_items[item.item_type] = item
    emit_signal("equipment_changed", item.item_type, item)
    return true

# Remove an item from a slot
func unequip_item(slot: EquipmentSlot) -> void:
    if equipped_items.has(slot):
        var item = equipped_items[slot]
        for stat_name in item.stats_bonus:
            stats_component.remove_equipment_bonus(stat_name, item.stats_bonus[stat_name])
        equipped_items.erase(slot)
        emit_signal("equipment_changed", slot, null)

# Get currently equipped item in slot
func get_equipped_item(slot: EquipmentSlot) -> ItemResource:
    return equipped_items.get(slot)

# Initialize test equipment
func create_test_equipment():
    # Create and store equipment by slot
    available_equipment = {
        EquipmentSlot.WEAPON: [iron_sword, iron_mace],
        # EquipmentSlot.HEAD: [iron_helmet],
        # EquipmentSlot.CHEST: [iron_mail],
        # EquipmentSlot.LEGS: [iron_leggards]
    }
    print("Test equipment created")

# Get available equipment for a specific slot
func get_available_equipment(slot: EquipmentSlot) -> Array:
    if available_equipment.has(slot):
        return available_equipment[slot]
    return []

# Get the next available equipment for a slot
func get_next_equipment(slot: EquipmentSlot, current_item: ItemResource) -> ItemResource:
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
func get_prev_equipment(slot: EquipmentSlot, current_item: ItemResource) -> ItemResource:
    var items = get_available_equipment(slot)
    if items.is_empty():
        return null
        
    if not current_item:
        return items[-1]
        
    var current_index = items.find(current_item)
    if current_index <= 0:
        return items[-1]
    return items[current_index - 1]