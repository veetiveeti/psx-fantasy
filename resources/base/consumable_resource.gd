extends ItemResource
class_name ConsumableResource

@export var stackable: bool = true
@export_multiline var description: String
@export var use_effect: String
@export var effect_amount: float
@export var quantity: int = 1

func _init():
    item_type = ItemEnums.ItemType.CONSUMABLE