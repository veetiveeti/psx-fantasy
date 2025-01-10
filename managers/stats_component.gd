@tool
extends Node
class_name StatsComponent

signal stat_changed(stat_name: String, new_value: float)
signal stat_increased(stat_name: String, new_value: float)

# Make base stats configurable in the editor
@export_group("Base Stats")
@export var base_strength: float = 10
@export var base_vitality: float = 10
@export var base_dexterity: float = 10
@export var base_intelligence: float = 10

# Internal stat storage
var base_stats = {
    "strength": 10,
    "vitality": 10,
    "dexterity": 10,
    "intelligence": 10,
}

var derived_stats = {
    "max_health": 0,
    "max_stamina": 0,
    "max_mana": 0,
    "physical_defense": 0,
    "magic_defense": 0,
    "carry_capacity": 0,
    "attack_speed": 1.0,
}

var equipment_bonuses = {
    "strength": 0,
    "vitality": 0,
    "dexterity": 0,
    "intelligence": 0,
    "physical_defense": 0,
    "magic_defense": 0,
}

# Stat increase costs (could be adjusted for balance)
var stat_increase_costs = {
    "strength": 1,     # 1 Spirit Stone per level
    "vitality": 1,
    "dexterity": 1,
    "intelligence": 1,
}

func _ready():
    # Sync exported variables with internal stats
    base_stats["strength"] = base_strength
    base_stats["vitality"] = base_vitality
    base_stats["dexterity"] = base_dexterity
    base_stats["intelligence"] = base_intelligence
    
    recalculate_derived_stats()

func get_stat(stat_name: String) -> float:
    if stat_name in base_stats:
        return base_stats[stat_name] + equipment_bonuses.get(stat_name, 0)
    elif stat_name in derived_stats:
        return derived_stats[stat_name]
    return 0.0

# Try to increase a stat using a spirit stone
func increase_stat(stat_name: String, spirit_stones: int) -> bool:
    if not stat_name in base_stats:
        return false
        
    var cost = stat_increase_costs[stat_name]
    if spirit_stones >= cost:
        set_base_stat(stat_name, base_stats[stat_name] + 1)
        emit_signal("stat_increased", stat_name, get_stat(stat_name))
        return true
    return false

func set_base_stat(stat_name: String, value: float) -> void:
    if stat_name in base_stats:
        base_stats[stat_name] = value
        # Also update the exported variable
        match stat_name:
            "strength": base_strength = value
            "vitality": base_vitality = value
            "dexterity": base_dexterity = value
            "intelligence": base_intelligence = value
        
        recalculate_derived_stats()
        emit_signal("stat_changed", stat_name, get_stat(stat_name))

func add_equipment_bonus(stat_name: String, value: float) -> void:
    if stat_name in equipment_bonuses:
        equipment_bonuses[stat_name] += value
        recalculate_derived_stats()
        emit_signal("stat_changed", stat_name, get_stat(stat_name))

func remove_equipment_bonus(stat_name: String, value: float) -> void:
    if stat_name in equipment_bonuses:
        equipment_bonuses[stat_name] -= value
        recalculate_derived_stats()
        emit_signal("stat_changed", stat_name, get_stat(stat_name))

func recalculate_derived_stats() -> void:
    derived_stats["max_health"] = 100 + (get_stat("vitality") * 10)
    derived_stats["max_stamina"] = 100 + (get_stat("vitality") * 5)
    derived_stats["max_mana"] = 50 + (get_stat("intelligence") * 10)
    derived_stats["physical_defense"] = (get_stat("vitality") * 2) + equipment_bonuses.get("physical_defense", 0)
    derived_stats["magic_defense"] = (get_stat("intelligence") * 2) + equipment_bonuses.get("magic_defense", 0)
    derived_stats["carry_capacity"] = 50 + (get_stat("strength") * 5)
    derived_stats["attack_speed"] = 1.0 + (get_stat("dexterity") * 0.01)