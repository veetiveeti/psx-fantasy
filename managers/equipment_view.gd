extends Control

@onready var equipment_list = $HBoxContainer/EquipmentList/MarginContainer/ScrollContainer/VBoxContainer
@onready var item_preview = $HBoxContainer/ItemPreview
@onready var character_stats = $HBoxContainer/CharacterStats/MarginContainer/VBoxContainer/StatsDisplay
@onready var equipment_manager = get_node("../../../../../../../EquipmentManager")
@onready var stats_component = get_node("../../../../../../../StatsComponent")
@onready var equip_button = $HBoxContainer/CharacterStats/MarginContainer/VBoxContainer/EquipButton

var selected_slot = 0  # Will use WEAPON from enum
var current_preview_item = null

func _ready():
	if not equipment_manager:
		push_error("EquipmentManager not found!")
		return

	# Connect to equipment changes
	equipment_manager.equipment_changed.connect(_on_equipment_changed)
	# Connect equip button
	equip_button.pressed.connect(_on_equip_button_pressed)
	# Connect to stats changes
	stats_component.stat_changed.connect(_on_stat_changed)
	stats_component.stat_increased.connect(_on_stat_changed)
	
	setup_equipment_slots()
	update_character_stats()

func setup_equipment_slots():
	# Create header
	var header = Label.new()
	header.text = "Equipment Slots"
	equipment_list.add_child(header)
	
	# Add some spacing
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	equipment_list.add_child(spacer)
	
	# Create buttons for each equipment slot
	for slot in ItemEnums.EquipmentSlot.values():
		var slot_container = VBoxContainer.new()
		equipment_list.add_child(slot_container)
		
		# Slot button
		var slot_button = Button.new()
		slot_button.text = ItemEnums.EquipmentSlot.keys()[slot]
		slot_button.custom_minimum_size.y = 20
		slot_button.pressed.connect(_on_slot_selected.bind(slot))
		slot_container.add_child(slot_button)
		
		# Currently equipped item
		var equipped_label = Label.new()
		var equipped_item = equipment_manager.get_equipped_item(slot)
		equipped_label.text = equipped_item.name if equipped_item else "Nothing equipped"
		equipped_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		slot_container.add_child(equipped_label)
		
		# Add some spacing
		var slot_spacer = Control.new()
		slot_spacer.custom_minimum_size.y = 10
		slot_container.add_child(slot_spacer)

func _on_slot_selected(slot: int):
	selected_slot = slot
	var equipped_item = equipment_manager.get_equipped_item(slot)
	var available = equipment_manager.get_available_equipment(slot)
	preview_item(equipped_item if equipped_item else (available[0] if not available.is_empty() else null))

func preview_item(item):
	print("preview item called")
	if not item:
		print("no item to preview")
		return

	current_preview_item = item

	# Get the ItemPreview node
	var preview_node = $HBoxContainer/ItemPreview
	if preview_node:
		print("Found preview node, displaying item: ", item.name)  # Debug print
		preview_node.display_item(item)
	else:
		print("Could not find ItemPreview node!")  # Debug print

func update_character_stats():
	if not stats_component:
		return
		
	# Clear existing stats
	for child in character_stats.get_children():
		child.queue_free()
	
	# Add title
	var title = Label.new()
	title.text = "Character Stats"
	character_stats.add_child(title)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	character_stats.add_child(spacer)
	
	# Add base stats
	add_stat_label("Strength", stats_component.get_stat("strength"))
	add_stat_label("Vitality", stats_component.get_stat("vitality"))
	add_stat_label("Dexterity", stats_component.get_stat("dexterity"))
	add_stat_label("Intelligence", stats_component.get_stat("intelligence"))
	
	# Add derived stats
	var separator = HSeparator.new()
	character_stats.add_child(separator)
	
	add_stat_label("Physical Defense", stats_component.get_stat("physical_defense"))
	add_stat_label("Magic Defense", stats_component.get_stat("magic_defense"))
	add_stat_label("Attack Speed", stats_component.get_stat("attack_speed"))

	# Add spacer before button
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size.y = 20
	character_stats.add_child(button_spacer)

func _on_equipment_changed(_slot: int, _item):
	# Update the equipped item label for this slot
	refresh_equipment_slots()
	# Update char stats to show new stat bonuses
	update_character_stats()

func refresh_equipment_slots():
	for child in equipment_list.get_children():
		child.queue_free()
	setup_equipment_slots()

func _on_equip_button_pressed():
	if current_preview_item:
		print("Attempting to equip: ", current_preview_item)
		var success = equipment_manager.equip_item(current_preview_item)
		print("Equip success: ", success)

func add_stat_label(stat_name: String, value: float):
	var hbox = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = stat_name + ":"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Font color for stat name
	name_label.add_theme_color_override("font_color", Color(100, 100, 100))
	
	var value_label = Label.new()
	value_label.text = str(value)

	# Font color for stat value
	value_label.add_theme_color_override("font_color", Color(100, 100, 100))
	
	hbox.add_child(name_label)
	hbox.add_child(value_label)
	
	character_stats.add_child(hbox)

func _on_stat_changed(_stat_name: String, _new_value: float):
	update_character_stats()
