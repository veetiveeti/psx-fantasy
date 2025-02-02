extends Resource
class_name ItemResource

@export var id: String
@export var name: String
@export var item_type: ItemEnums.ItemType
@export var stats_bonus: Dictionary
@export var requirements: Dictionary
@export var texture_path: String
@export var sound_path: String
@export var quantity: int = 1
@export var information: String