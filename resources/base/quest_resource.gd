extends ItemResource

class_name QuestResource

@export_multiline var description: String
@export var use_effect: String

func _init():
    item_type = ItemEnums.ItemType.QUEST