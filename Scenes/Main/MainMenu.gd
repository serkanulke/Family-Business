extends Control

signal continue_requested
signal load_game_requested
signal new_game_requested
signal settings_requested

const LOAD_GAME_SCENE := "res://Scenes/LoadGame/LoadGameScreen.tscn"


func _ready() -> void:
	# Main menu is outside the running simulation.
	# This also protects against time continuing after returning here
	# from an active game session.
	TimeManager.pause()


func _on_continue_button_pressed() -> void:
	continue_requested.emit()


func _on_load_game_button_pressed() -> void:
	load_game_requested.emit()
	get_tree().change_scene_to_file(LOAD_GAME_SCENE)


func _on_new_game_button_pressed() -> void:
	new_game_requested.emit()


func _on_settings_button_pressed() -> void:
	settings_requested.emit()
