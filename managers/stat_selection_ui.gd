extends CanvasLayer

@warning_ignore("unused_signal")
signal stat_selected(stat_name: String)
@warning_ignore("unused_signal")
signal selection_cancelled

@onready var stats_component = get_node("../StatsComponent")
var selected_stat: String = ""

@onready var interaction_audio = get_node("../Inventory/InventorySounds")

func _ready() -> void:
	hide()

	for stat in ["strength", "vitality", "dexterity", "intelligence"]:
		var button = get_node("StatSelectionUi/PanelContainer/MarginContainer/VBoxContainer/Stats/%sContainer/%sButton" % [stat.capitalize(), stat.capitalize()])
		print("Found button for ", stat, "?: ", button != null)
		if button:
			button.pressed.connect(_on_stat_button_pressed.bind(stat))

	var finish_button = $StatSelectionUi/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/FinishButton
	var cancel_button = $StatSelectionUi/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/CancelButton

	if finish_button:
		finish_button.pressed.connect(_on_finish_button_pressed)
		finish_button.hide()
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_button_pressed)

	update_stat_displays()

func show_stat_options():
	selected_stat = ""
	show()
	GameManager.game_active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	update_stat_displays()

func update_stat_displays():
	# Update each stat display
	for stat in ["strength", "vitality", "dexterity", "intelligence"]:
		var stat_container = get_node("StatSelectionUi/PanelContainer/MarginContainer/VBoxContainer/Stats/%sContainer" % stat.capitalize())
		var label = stat_container.get_node("HBoxContainer/StatValue")  # Label showing current value
		var current_value = stats_component.get_stat(stat)
		label.text = str(current_value)

		# If this stat is selected, show preview of new value
		if selected_stat == stat:
			label.text += " → " + str(current_value + 1)

func _on_stat_button_pressed(stat_name: String):
	play_interaction()
	selected_stat = stat_name.to_lower()
	update_stat_displays()
	$StatSelectionUi/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/FinishButton.show()

func _on_finish_button_pressed():
	if selected_stat != "":
		emit_signal("stat_selected", selected_stat)
		selected_stat = ""
		hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		var inventory_ui = get_node("../Inventory/CanvasLayer/Control/MarginContainer/InventoryUi")
		if inventory_ui:
			inventory_ui.show()

func _on_cancel_button_pressed():
	emit_signal("stat_selected", "")  # Emit signal with empty stat name
	selected_stat = ""
	play_interaction()
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var inventory_ui = get_node("../Inventory/CanvasLayer/Control/MarginContainer/InventoryUi")
	if inventory_ui:
		inventory_ui.show()

func play_interaction():
	interaction_audio.stream = UiAudioManager.menu_sounds.interaction
	interaction_audio.play()