extends PanelContainer

@onready var item_name = $MarginContainer/VBoxContainer/PreviewHeader/ItemName
@onready var prev_button = $MarginContainer/VBoxContainer/PreviewHeader/PrevButton
@onready var next_button = $MarginContainer/VBoxContainer/PreviewHeader/NextButton
@onready var item_image = $MarginContainer/VBoxContainer/ItemImage
@onready var item_stats = $MarginContainer/VBoxContainer/ItemStats

func display_item(item: EquipmentManager.Item):
    if not item:
        clear_preview()
        return
        
    item_name.text = item.name
    
    # Load and display item image
    if item.scene_path:
        var texture = load(item.scene_path)
        if texture:
            item_image.texture = texture
    
    # Display stats
    var stats_text = ""
    
    # Add stats bonuses
    for stat_name in item.stats_bonus:
        var value = item.stats_bonus[stat_name]
        stats_text += "%s: +%d\n" % [stat_name.capitalize(), value]
    
    # Add requirements
    stats_text += "\nRequirements:\n"
    for stat_name in item.requirements:
        var value = item.requirements[stat_name]
        stats_text += "%s: %d\n" % [stat_name.capitalize(), value]
    
    item_stats.text = stats_text

func clear_preview():
    item_name.text = "No item selected"
    item_image.texture = null
    item_stats.text = ""