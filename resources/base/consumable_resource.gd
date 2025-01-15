extends ItemResource
class_name ConsumableResource

@export var stackable: bool = true
@export_multiline var description: String
@export var use_effect: String
@export var effect_amount: float

func _init():
    item_type = ItemEnums.ItemType.CONSUMABLE