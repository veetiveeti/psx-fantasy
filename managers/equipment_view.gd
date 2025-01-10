extends Control

@onready var equipment_list = $HBoxContainer/EquipmentList/MarginContainer/ScrollContainer/VBoxContainer
@onready var item_preview = $HBoxContainer/ItemPreview/MarginContainer/VBoxContainer
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
	
	setup_equipment_slots()
	update_character_stats()

func setup_equipment_slots():
	# Create header
	var header = Label.new()
	header.text = "Equipment Slots"
	header.add_theme_font_size_override("font_size", 12)
	equipment_list.add_child(header)
	
	# Add some spacing
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	equipment_list.add_child(spacer)
	
	# Create buttons for each equipment slot
	for slot in equipment_manager.EquipmentSlot.values():
		var slot_container = VBoxContainer.new()
		equipment_list.add_child(slot_container)
		
		# Slot button
		var slot_button = Button.new()
		slot_button.text = equipment_manager.EquipmentSlot.keys()[slot]
		slot_button.custom_minimum_size.y = 20
		slot_button.pressed.connect(_on_slot_selected.bind(slot))
		slot_container.add_child(slot_button)
		
		# Currently equipped item
		var equipped_label = Label.new()
		var equipped_item = equipment_manager.get_equipped_item(slot)
		equipped_label.text = equipped_item.name if equipped_item else "Nothing equipped"
		equipped_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		equipped_label.add_theme_font_size_override("font_size", 12)
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
	if not item:
		return
		
	current_preview_item = item
	
	# Update preview panel
	var name_label = item_preview.get_node_or_null("ItemName")
	if name_label:
		name_label.text = item.name
	
	# Create name label if it doesn't exist
	if not name_label:
		name_label = Label.new()
		name_label.name = "ItemName"
		name_label.text = item.name
		name_label.add_theme_font_size_override("font_size", 12)
		item_preview.add_child(name_label)
	
	# Update stats
	var stats_label = item_preview.get_node_or_null("Stats")
	if not stats_label:
		stats_label = Label.new()
		stats_label.name = "Stats"
		item_preview.add_child(stats_label)
	
	var stats_text = ""
	for stat_name in item.stats_bonus:
		stats_text += "%s: +%d\n" % [stat_name.capitalize(), item.stats_bonus[stat_name]]
	
	stats_text += "\nRequirements:\n"
	for stat_name in item.requirements:
		stats_text += "%s: %d\n" % [stat_name.capitalize(), item.requirements[stat_name]]
	
	stats_label.text = stats_text

func update_character_stats():
	if not stats_component:
		return
		
	# Clear existing stats
	for child in character_stats.get_children():
		child.queue_free()
	
	# Add title
	var title = Label.new()
	title.text = "Character Stats"
	title.add_theme_font_size_override("font_size", 12)
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
	
	var value_label = Label.new()
	value_label.text = str(value)
	
	hbox.add_child(name_label)
	hbox.add_child(value_label)
	
	character_stats.add_child(hbox)
