extends Control

signal save_file_requested(save_id: int)

const MAIN_MENU_SCENE := "res://Scenes/MainMenu/MainMenu.tscn"
const GAME_SCENE := "res://Scenes/Main/Main.tscn"
const SAVE_SLOT_SCENE := preload(
	"res://Scenes/LoadGame/SaveSlot.tscn"
)

var save_list: VBoxContainer
var slots_scroll: ScrollContainer
var save_count_label: Label


func _ready() -> void:
	_prepare_dynamic_save_list()
	refresh_save_files()


func _prepare_dynamic_save_list() -> void:
	save_list = get_node_or_null(
		"Modal/Inner/Content/Slots"
	) as VBoxContainer

	save_count_label = get_node_or_null(
		"Modal/Inner/Content/SaveIndicator/Center/Row/Label"
	) as Label

	if save_list == null:
		push_error(
			"Load Game save list could not be found."
		)
		return

	var content := save_list.get_parent()

	if content == null:
		return

	var original_index := save_list.get_index()

	content.remove_child(
		save_list
	)

	slots_scroll = ScrollContainer.new()
	slots_scroll.name = "SlotsScroll"
	slots_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)

	content.add_child(
		slots_scroll
	)

	content.move_child(
		slots_scroll,
		original_index
	)

	slots_scroll.add_child(
		save_list
	)

	save_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func refresh_save_files() -> void:
	if save_list == null:
		return

	for child in save_list.get_children():
		save_list.remove_child(
			child
		)
		child.queue_free()

	var summaries := SaveManager.get_all_save_summaries()

	_update_save_count_label(
		summaries.size()
	)

	for summary_value in summaries:
		if typeof(
			summary_value
		) != TYPE_DICTIONARY:
			continue

		var summary: Dictionary = summary_value
		var slot_value := SAVE_SLOT_SCENE.instantiate()

		if slot_value == null:
			continue

		save_list.add_child(
			slot_value
		)

		if slot_value.has_method(
			"apply_save_summary"
		):
			slot_value.call(
				"apply_save_summary",
				summary
			)

		if slot_value.has_signal(
			"load_requested"
		):
			slot_value.connect(
				"load_requested",
				_on_save_load_requested
			)


func _update_save_count_label(
	save_count: int
) -> void:
	if save_count_label == null:
		return

	if save_count == 1:
		save_count_label.text = "1 Save File"
		return

	save_count_label.text = (
		str(save_count)
		+ " Save Files"
	)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(
		MAIN_MENU_SCENE
	)


func _on_save_load_requested(
	save_id: int
) -> void:
	save_file_requested.emit(
		save_id
	)

	if not SaveManager.load_game(
		save_id
	):
		return

	get_tree().change_scene_to_file(
		GAME_SCENE
	)


# Compatibility with the three old scene connections. Those example nodes
# are removed during _ready(), but keeping this method avoids a broken
# connection warning while the original .tscn remains unchanged.
func _on_slot_load_requested(
	_legacy_slot_index: int
) -> void:
	pass
