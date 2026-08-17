@tool
extends PanelContainer

signal load_requested(slot_index: int)

@export var slot_index: int = 0
@export var family_name: String = "Williams Family":
	set(value):
		family_name = value
		_sync_visuals()
@export var wealth_text: String = "240k":
	set(value):
		wealth_text = value
		_sync_visuals()
@export var population_text: String = "10":
	set(value):
		population_text = value
		_sync_visuals()
@export var owned_businesses_text: String = "1":
	set(value):
		owned_businesses_text = value
		_sync_visuals()


func _ready() -> void:
	_sync_visuals()


func _sync_visuals() -> void:
	if not is_inside_tree():
		return

	var family_label := get_node_or_null("Padding/Content/Info/FamilyName") as Label
	var wealth_value := get_node_or_null("Padding/Content/Info/Metrics/WealthRow/Value") as Label
	var population_value := get_node_or_null("Padding/Content/Info/Metrics/PopulationRow/Value") as Label
	var businesses_value := get_node_or_null("Padding/Content/Info/Metrics/BusinessesRow/Value") as Label

	if family_label != null:
		family_label.text = family_name
	if wealth_value != null:
		wealth_value.text = wealth_text
	if population_value != null:
		population_value.text = population_text
	if businesses_value != null:
		businesses_value.text = owned_businesses_text


func _on_load_button_pressed() -> void:
	load_requested.emit(slot_index)
