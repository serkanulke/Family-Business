extends Control

signal continue_requested
signal load_game_requested
signal new_game_requested
signal settings_requested

const LOAD_GAME_SCENE := "res://Scenes/LoadGame/LoadGameScreen.tscn"
const GAME_SCENE := "res://Scenes/Main/Main.tscn"
const NEW_GAME_MODAL_SCENE := preload(
	"res://Scenes/NewGame/NewGameModal.tscn"
)

var new_game_modal: Control


func _ready() -> void:
	# If this menu was reached from an active family, persist that family
	# before pausing the simulation. On a fresh application launch there is
	# no current save, so this is simply a no-op.
	SaveManager.autosave_current_game()
	TimeManager.pause()


func _on_continue_button_pressed() -> void:
	continue_requested.emit()

	var save_id := SaveManager.get_most_recent_save_id()

	if save_id <= 0:
		return

	if not SaveManager.load_game(
		save_id
	):
		return

	get_tree().change_scene_to_file(
		GAME_SCENE
	)


func _on_load_game_button_pressed() -> void:
	load_game_requested.emit()
	get_tree().change_scene_to_file(
		LOAD_GAME_SCENE
	)


func _on_new_game_button_pressed() -> void:
	new_game_requested.emit()

	if (
		new_game_modal != null
		and is_instance_valid(
			new_game_modal
		)
	):
		return

	var modal_value := NEW_GAME_MODAL_SCENE.instantiate()
	new_game_modal = modal_value as Control

	if new_game_modal == null:
		push_error(
			"New Game modal could not be instantiated."
		)
		return

	add_child(
		new_game_modal
	)

	if new_game_modal.has_signal(
		"dismissed"
	):
		new_game_modal.connect(
			"dismissed",
			_on_new_game_modal_dismissed
		)


func _on_new_game_modal_dismissed() -> void:
	if (
		new_game_modal == null
		or not is_instance_valid(
			new_game_modal
		)
	):
		return

	new_game_modal.queue_free()
	new_game_modal = null


func _on_settings_button_pressed() -> void:
	settings_requested.emit()
