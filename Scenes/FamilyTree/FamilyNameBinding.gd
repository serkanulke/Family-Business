extends Node

const EMPTY_FAMILY_LABEL := "FAMILY"

var family_tree_screen: Control


func _ready() -> void:
	family_tree_screen = get_parent() as Control

	if family_tree_screen == null:
		push_error(
			"FamilyNameBinding must be a child of FamilyTreeScreen."
		)
		return

	if not GameManager.family_name_changed.is_connected(
		_on_family_name_changed
	):
		GameManager.family_name_changed.connect(
			_on_family_name_changed
		)

	_apply_family_name(
		GameManager.family_name
	)


func _apply_family_name(
	value: String
) -> void:
	if family_tree_screen == null:
		return

	var cleaned_name := value.strip_edges()
	var display_name := EMPTY_FAMILY_LABEL

	if not cleaned_name.is_empty():
		display_name = cleaned_name.to_upper()

	family_tree_screen.set(
		"family_name",
		display_name
	)

	var label_value = family_tree_screen.get(
		"family_name_label"
	)

	if label_value is Label:
		var label := label_value as Label
		label.text = display_name


func _on_family_name_changed(
	new_name: String
) -> void:
	_apply_family_name(
		new_name
	)
