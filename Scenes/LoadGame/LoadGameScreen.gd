extends Control

signal save_slot_requested(slot_index: int)

const MAIN_MENU_SCENE := "res://Scenes/MainMenu/MainMenu.tscn"


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_slot_load_requested(slot_index: int) -> void:
	# SaveManager is not implemented yet. Keep the UI action explicit
	# without inventing save-loading behavior.
	save_slot_requested.emit(slot_index)
