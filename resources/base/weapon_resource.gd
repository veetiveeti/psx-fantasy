extends EquipmentResource
class_name WeaponResource

@export var base_damage: float
@export var attack_speed: float
@export var weapon_range: float
@export var hitbox_path: String
@export var weapon_model_name: String

func _init():
    super._init()
    equipment_slot = ItemEnums.EquipmentSlot.WEAPON