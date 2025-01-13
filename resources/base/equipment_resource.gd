extends ItemResource
class_name EquipmentResource

@export var equipment_slot: ItemEnums.EquipmentSlot
@export var model_scene_path: String

func _init():
    item_type = ItemEnums.ItemType.EQUIPMENT