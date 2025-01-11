extends Node
class_name CombatSystem

@onready var stats_component = get_parent().get_node("StatsComponent")
@onready var equipment_manager = get_parent().get_node("EquipmentManager")
@onready var player = get_parent()

# Base damage values
const BASE_UNARMED_DAMAGE = 10.0
const STRENGTH_DAMAGE_MODIFIER = 0.5  # Each point of strength adds this much damage
const BLOCK_DAMAGE_REDUCTION = 0.5

# Offensive calculations
func calculate_attack_damage() -> float:
    if not stats_component or not equipment_manager:
        push_error("Required components not found in CombatSystem!")
        return BASE_UNARMED_DAMAGE
    
    # Start with base unarmed damage
    var total_damage = BASE_UNARMED_DAMAGE
    
    # Add strength modifier
    var strength = stats_component.get_stat("strength")
    total_damage += strength * STRENGTH_DAMAGE_MODIFIER
    
    # Add weapon damage if equipped
    var weapon = equipment_manager.get_equipped_item(EquipmentManager.EquipmentSlot.WEAPON)
    if weapon:
        total_damage += weapon.base_damage
    
    return total_damage

# Defensive calculations
func calculate_incoming_damage(hit_points: float, attacker_position: Vector3) -> float:
    if not stats_component:
        return hit_points

    # Apply armor/defense reduction
    var damage_reduction = stats_component.get_stat("physical_defense") * 0.01
    var final_damage = hit_points * (1 - damage_reduction)
    
    # Apply block reduction if blocking
    if player.is_blocking:
        if is_attack_from_front(attacker_position):
            final_damage *= BLOCK_DAMAGE_REDUCTION
            
    return final_damage

func is_attack_from_front(attacker_position: Vector3) -> bool:
    var to_attacker = (attacker_position - player.global_position).normalized()
    var forward = -player.global_transform.basis.z
    var angle = rad_to_deg(forward.angle_to(to_attacker))
    return angle < 90  # Blocks 180-degree arc in front


# Could be expanded with functions like:
# func calculate_critical_chance() -> float:
# func calculate_armor_penetration() -> float:
# func apply_damage_modifiers(base_damage: float) -> float: