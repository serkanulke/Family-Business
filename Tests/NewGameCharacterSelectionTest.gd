extends Node

const NEW_GAME_MODAL := preload(
	"res://Scenes/NewGame/NewGameModal.tscn"
)

const TEST_SAVE_DIRECTORY := (
	"user://new_game_character_selection_test"
)

var passed: int = 0
var failed: int = 0
var original_save_directory: String = ""


func _ready() -> void:
	original_save_directory = SaveManager.save_directory
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.current_save_id = -1
	_cleanup_test_saves()

	print("")
	print("========================================")
	print("New Game character selection tests")
	print("========================================")

	var mixed_male_paths := (
		CharacterManager.get_portrait_paths(
			"male",
			"mixed"
		)
	)

	_assert_true(
		not mixed_male_paths.is_empty(),
		"Male mixed-skin portrait folder is discovered"
	)

	var modal := NEW_GAME_MODAL.instantiate()
	add_child(
		modal
	)

	await get_tree().process_frame
	await get_tree().process_frame

	_assert_true(
		String(
			modal.get(
				"selected_gender"
			)
		) == "male",
		"New Game modal defaults to male selection"
	)

	var initial_portrait_paths: Dictionary = modal.get(
		"selected_portrait_paths"
	)

	var male_portrait_before_female_change := String(
		initial_portrait_paths.get(
			"male",
			""
		)
	)

	_assert_true(
		String(
			modal.get(
				"selected_skin_tone"
			)
		) == "mixed",
		"New Game modal defaults to mixed skin"
	)

	var preview_path := String(
		modal.call(
			"get_selected_portrait_path"
		)
	)

	_assert_true(
		preview_path.contains(
			"/Male/Mixed/YoungAdult/"
		),
		"Selected preview comes from canonical Male/Mixed/YoungAdult folder"
	)

	modal.call(
		"select_gender",
		"female"
	)

	_assert_true(
		String(
			modal.get(
				"selected_gender"
			)
		) == "female",
		"Gender selection can change to female"
	)

	modal.call(
		"select_skin_tone",
		"light"
	)

	_assert_true(
		String(
			modal.get(
				"selected_skin_tone"
			)
		) == "light",
		"Skin-tone selection can change to light"
	)

	var per_gender_skin: Dictionary = modal.get(
		"selected_skin_tones"
	)

	var portrait_paths_after_female_change: Dictionary = modal.get(
		"selected_portrait_paths"
	)

	_assert_true(
		String(
			per_gender_skin.get(
				"male",
				""
			)
		) == "mixed"
		and String(
			per_gender_skin.get(
				"female",
				""
			)
		) == "light",
		"Male and female remember independent skin selections"
	)

	_assert_true(
		String(
			portrait_paths_after_female_change.get(
				"male",
				""
			)
		) == male_portrait_before_female_change,
		"Changing female skin does not change the male portrait"
	)

	var start_button := modal.get_node_or_null(
		"Modal/StartGameButton"
	) as Button

	var start_background := modal.get_node_or_null(
		"Modal/StartGameButton/Background"
	) as NinePatchRect

	_assert_true(
		start_button != null
		and start_background != null,
		"START GAME uses a Button with NinePatch background"
	)

	_assert_true(
		start_background != null
		and start_background.get_patch_margin(
			SIDE_LEFT
		) > 0
		and start_background.get_patch_margin(
			SIDE_RIGHT
		) > 0,
		"START GAME preserves PNG edges with NinePatch margins"
	)

	var female_light_path := (
		CharacterManager.get_random_portrait_path(
			"female",
			"light"
		)
	)

	_assert_true(
		female_light_path.contains(
			"/Female/Light/YoungAdult/"
		),
		"Female light-skin portrait comes from canonical Female/Light/YoungAdult folder"
	)

	modal.queue_free()
	await get_tree().process_frame

	var starting_character := (
		GameManager.start_new_game_from_character_selection(
			"male",
			"mixed",
			String(
				mixed_male_paths[0]
			)
		)
	)

	_assert_true(
		not starting_character.is_empty(),
		"Gender + skin selection starts a real game"
	)

	var genetics: Dictionary = (
		starting_character.get(
			"genetics",
			{}
		)
	)

	_assert_true(
		String(
			genetics.get(
				"skin_tone",
				""
			)
		) == "mixed"
		and not genetics.has("hair_color")
		and not genetics.has("eye_color"),
		"Starting character stores skin-only active genetics"
	)

	_assert_true(
		String(
			starting_character.get(
				"portrait_path",
				""
			)
		).contains(
			"/Male/Mixed/YoungAdult/"
		),
		"Starting character stores the canonical selected portrait path"
	)

	_assert_true(
		String(
			starting_character.get(
				"portrait_variant_id",
				""
			)
		) == "character_001",
		"Starting character stores the persistent portrait variant ID"
	)

	var male_names_value = NPCManager.name_config.get(
		"male",
		[]
	)

	var family_names_value = NPCManager.name_config.get(
		"last_names",
		[]
	)

	_assert_true(
		starting_character.get(
			"first_name",
			""
		) in male_names_value,
		"Starting first name comes from the existing male name list"
	)

	_assert_true(
		GameManager.family_name in family_names_value,
		"Family name comes from the existing last-name list"
	)

	_assert_true(
		SaveManager.current_save_id > 0,
		"Starting through character selection creates a dynamic save"
	)

	_cleanup_test_saves()
	SaveManager.current_save_id = -1
	SaveManager.save_directory = original_save_directory

	print("")
	print(
		"New Game character selection tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL NEW GAME CHARACTER SELECTION TESTS PASSED."
		)
	else:
		push_error(
			"New Game selection has %d failing test(s)."
			% failed
		)


func _cleanup_test_saves() -> void:
	var absolute_directory := (
		ProjectSettings.globalize_path(
			TEST_SAVE_DIRECTORY
		)
	)

	if not DirAccess.dir_exists_absolute(
		absolute_directory
	):
		return

	var directory := DirAccess.open(
		TEST_SAVE_DIRECTORY
	)

	if directory != null:
		directory.list_dir_begin()
		var file_name := directory.get_next()

		while not file_name.is_empty():
			if not directory.current_is_dir():
				DirAccess.remove_absolute(
					ProjectSettings.globalize_path(
						TEST_SAVE_DIRECTORY.path_join(
							file_name
						)
					)
				)

			file_name = directory.get_next()

		directory.list_dir_end()

	DirAccess.remove_absolute(
		absolute_directory
	)


func _assert_true(
	condition: bool,
	test_name: String
) -> void:
	if condition:
		passed += 1
		print(
			"[PASS] ",
			test_name
		)
	else:
		failed += 1
		push_error(
			"[FAIL] "
			+ test_name
		)
