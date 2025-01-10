extends Node3D
class_name EquipmentManager

# Ignore the warning: this signal is used in Equipment_View
@warning_ignore("unused_signal")
signal equipment_changed(slot: int, item: Item)

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

class Item:
    var id: String
    var name: String
    var slot: EquipmentSlot
    var stats_bonus = {}  # Dictionary of stat bonuses
    var requirements = {}  # Dictionary of stat requirements
    var scene_path: String  # Path to the 3D model scene
    
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

# Try to equip an item
func equip_item(item: Item) -> bool:
    if not stats_component:
        return false
        
    # Check stat requirements
    for stat_name in item.requirements:
        if stats_component.get_stat(stat_name) < item.requirements[stat_name]:
            return false
    
    # Remove old item if one exists
    if equipped_items.has(item.slot):
        unequip_item(item.slot)
    
    # Apply stat bonuses
    for stat_name in item.stats_bonus:
        stats_component.add_equipment_bonus(stat_name, item.stats_bonus[stat_name])
    
    equipped_items[item.slot] = item
    emit_signal("equipment_changed", item.slot, item)
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
func get_equipped_item(slot: EquipmentSlot) -> Item:
    return equipped_items.get(slot)

# Example weapon creation
func create_sword() -> Weapon:
    var sword = Weapon.new("sword_basic", "Iron Sword")
    sword.base_damage = 10
    sword.attack_speed = 1.0
    sword.weapon_range = 1.5
    sword.stats_bonus = {
        "strength": 2
    }
    sword.requirements = {
        "strength": 8
    }
    sword.scene_path = "res://models/weapons/iron_sword.tscn"
    return sword

# Example armor creation functions
func create_test_helmet() -> Armor:
    var helmet = Armor.new("helmet_basic", "Iron Helmet", EquipmentSlot.HEAD)
    helmet.physical_defense = 8
    helmet.magic_defense = 3
    helmet.stats_bonus = {
        "vitality": 2,
        "physical_defense": 8
    }
    helmet.requirements = {
        "strength": 5
    }
    return helmet

func create_chest_armor() -> Armor:
    var chest = Armor.new("chest_basic", "Iron Chestplate", EquipmentSlot.CHEST)
    chest.physical_defense = 15
    chest.magic_defense = 5
    chest.stats_bonus = {
        "vitality": 3,
        "physical_defense": 15
    }
    chest.requirements = {
        "strength": 10
    }
    return chest

func create_test_legs() -> Armor:
    var legs = Armor.new("legs_basic", "Iron Greaves", EquipmentSlot.LEGS)
    legs.physical_defense = 12
    legs.magic_defense = 4
    legs.stats_bonus = {
        "vitality": 2,
        "physical_defense": 12
    }
    legs.requirements = {
        "strength": 8
    }
    return legs

func create_test_shield() -> Armor:
    var shield = Armor.new("shield_basic", "Iron Shield", EquipmentSlot.SHIELD)
    shield.physical_defense = 10
    shield.magic_defense = 5
    shield.stats_bonus = {
        "vitality": 1,
        "physical_defense": 10,
        "magic_defense": 5
    }
    shield.requirements = {
        "strength": 7
    }
    return shield

# Initialize test equipment
func create_test_equipment():
    # Create and store equipment by slot
    available_equipment = {
        EquipmentSlot.WEAPON: [create_sword()],
        EquipmentSlot.HEAD: [create_test_helmet()],
        EquipmentSlot.CHEST: [create_chest_armor()],
        EquipmentSlot.LEGS: [create_test_legs()],
        EquipmentSlot.SHIELD: [create_test_shield()]
    }
    print("Test equipment created")

# Get available equipment for a specific slot
func get_available_equipment(slot: EquipmentSlot) -> Array:
    if available_equipment.has(slot):
        return available_equipment[slot]
    return []

# Get the next available equipment for a slot
func get_next_equipment(slot: EquipmentSlot, current_item: Item) -> Item:
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
func get_prev_equipment(slot: EquipmentSlot, current_item: Item) -> Item:
    var items = get_available_equipment(slot)
    if items.is_empty():
        return null
        
    if not current_item:
        return items[-1]
        
    var current_index = items.find(current_item)
    if current_index <= 0:
        return items[-1]
    return items[current_index - 1]