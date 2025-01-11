extends PanelContainer

@onready var item_name = $MarginContainer/VBoxContainer/ItemName
@onready var prev_button = $MarginContainer/VBoxContainer/PreviewHeader/PrevButton
@onready var next_button = $MarginContainer/VBoxContainer/PreviewHeader/NextButton
@onready var item_image = $MarginContainer/VBoxContainer/ItemImage
@onready var item_stats = $MarginContainer/VBoxContainer/ItemStats

@onready var equipment_view = get_node("../..")
var current_item: Resource = null

func _ready():
    prev_button.pressed.connect(_on_prev_pressed)
    next_button.pressed.connect(_on_next_pressed)

func display_item(item: Resource):
    current_item = item
    if not item:
        clear_preview()
        return
        
    item_name.text = item.name
    
    # Load and display item image
    if item.texture_path:
        var texture = load(item.texture_path)
        if texture:
            item_image.texture = texture
        else:
            push_error("Failed to load texture: " + item.texture_path)
            item_image.texture = null
    else:
        item_image.texture = null  # No texture path provided
    
    # Clear existing stats
    for child in item_stats.get_children():
        child.queue_free()
    
    # Add stats bonuses
    for stat_name in item.stats_bonus:
        var value = item.stats_bonus[stat_name]
        add_stat_line("%s: +%d" % [stat_name.capitalize(), value])
    
    # Add spacer
    var spacer = Control.new()
    spacer.custom_minimum_size.y = 10
    item_stats.add_child(spacer)
    
    # Add requirements
    add_stat_line("Requirements:")
    for stat_name in item.requirements:
        var value = item.requirements[stat_name]
        add_stat_line("%s: %d" % [stat_name.capitalize(), value])

func add_stat_line(text: String):
    var label = Label.new()
    label.text = text
    item_stats.add_child(label)

func clear_preview():
    item_name.text = "No item selected"
    item_image.texture = null
    # Clear stats
    for child in item_stats.get_children():
        child.queue_free()

func _on_prev_pressed():
    if current_item and equipment_view:
        var prev_item = equipment_view.equipment_manager.get_prev_equipment(
            equipment_view.selected_slot,
            current_item
        )
        if prev_item:
            equipment_view.preview_item(prev_item)

func _on_next_pressed():
    if current_item and equipment_view:
        var next_item = equipment_view.equipment_manager.get_next_equipment(
            equipment_view.selected_slot,
            current_item
        )
        if next_item:
            equipment_view.preview_item(next_item)