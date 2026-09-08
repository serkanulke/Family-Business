extends Node

const LOAD_GAME_SCREEN := preload(
	"res://Scenes/LoadGame/LoadGameScreen.tscn"
)

const TEST_SAVE_DIRECTORY := (
	"user://family_business_save_test"
)

var passed: int = 0
var failed: int = 0
var original_save_directory: String = ""
var original_save_id: int = -1


func _ready() -> void:
	original_save_directory = (
		SaveManager.save_directory
	)
	original_save_id = SaveManager.current_save_id

	SaveManager.save_directory = (
		TEST_SAVE_DIRECTORY
	)
	SaveManager.current_save_id = -1

	_cleanup_test_saves()

	print("")
	print("========================================")
	print("SaveManager runtime tests")
	print("========================================")

	_create_test_game()

	var expected_character_count := (
		CharacterManager.characters.size()
	)

	var expected_worker_count := (
		NPCManager.worker_npcs.size()
	)

	var expected_date := (
		TimeManager.get_iso_date_string()
	)

	var test_save_id := SaveManager.current_save_id

	_assert_true(
		test_save_id > 0,
		"New game owns a positive dynamic save ID"
	)

	_assert_true(
		SaveManager.save_current_game(),
		"Runtime state can be written to the current save file"
	)

	_assert_true(
		SaveManager.has_save(test_save_id),
		"Current dynamic save is reported as existing"
	)

	var summary: Dictionary = (
		SaveManager.get_save_summary(test_save_id)
	)

	_assert_true(
		String(
			summary.get(
				"family_name",
				""
			)
		) == "Johnson",
		"Slot summary stores the real family name"
	)

	_assert_true(
		int(
			summary.get(
				"wealth",
				0
			)
		) == 32100,
		"Slot summary stores the real family money"
	)

	GameManager.family_name = "BROKEN"
	GameManager.family_money = 1
	GameManager.diamonds = 0
	CharacterManager.characters = []
	NPCManager.worker_npcs = []
	TimeManager.current_day = 1
	TimeManager.current_month = 1
	TimeManager.current_year = 2000

	_assert_true(
		SaveManager.load_game(test_save_id),
		"Saved dynamic file can be loaded"
	)

	_assert_true(
		GameManager.family_name == "Johnson",
		"Family name is restored"
	)

	_assert_true(
		GameManager.family_money == 32100,
		"Family money is restored"
	)

	_assert_true(
		GameManager.diamonds == 7,
		"Diamonds are restored"
	)

	_assert_true(
		CharacterManager.characters.size()
		== expected_character_count,
		"Characters are restored"
	)

	_assert_true(
		NPCManager.worker_npcs.size()
		== expected_worker_count,
		"Worker NPC pool is restored"
	)

	_assert_true(
		TimeManager.get_iso_date_string()
		== expected_date,
		"Game date is restored"
	)

	_test_character_id_normalization()

	SaveManager.current_save_id = -1
	_cleanup_test_saves()

	SaveManager.save_directory = (
		original_save_directory
	)
	SaveManager.current_save_id = original_save_id

	print("")
	print(
		"SaveManager runtime tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL SAVE MANAGER RUNTIME TESTS PASSED."
		)
	else:
		push_error(
			"SaveManager has %d failing test(s)."
			% failed
		)


func _create_test_game() -> void:
	var character := GameManager.start_new_game(
		"William",
		"male",
		"Johnson"
	)

	_assert_true(
		not character.is_empty(),
		"Test game creates a real starting character"
	)

	GameManager.set_family_money(
		32100
	)

	GameManager.set_diamonds(
		7
	)

	TimeManager.current_day = 12
	TimeManager.current_month = 6
	TimeManager.current_year = 1992
	TimeManager.speed_multiplier = 2.0
	TimeManager.is_paused = false


func _test_character_id_normalization() -> void:
	var original_characters := CharacterManager.characters

	CharacterManager.characters = [
		{
			"character_id": 1.0,
			"partner_id": 2.0,
			"linked_character_id": 3.0,
			"children_ids": [4.0, 5.0, 4.0],
			"rejected_by_character_ids": [6.0, 7.0, 6.0]
		},
		{
			"character_id": 2.0,
			"partner_id": null,
			"linked_character_id": null,
			"children_ids": [],
			"rejected_by_character_ids": []
		}
	]

	CharacterManager.normalize_character_ids()

	var character: Dictionary = CharacterManager.characters[0]
	var nullable_character: Dictionary = CharacterManager.characters[1]
	var children: Array = character.get("children_ids", [])
	var rejected_by: Array = character.get(
		"rejected_by_character_ids",
		[]
	)

	_assert_true(
		typeof(character.get("character_id")) == TYPE_INT
		and int(character.get("character_id")) == 1,
		"Character ID is normalized to int"
	)

	_assert_true(
		typeof(character.get("partner_id")) == TYPE_INT
		and int(character.get("partner_id")) == 2,
		"Partner ID is normalized to int"
	)

	_assert_true(
		typeof(character.get("linked_character_id")) == TYPE_INT
		and int(character.get("linked_character_id")) == 3,
		"Linked Character ID is normalized to int"
	)

	_assert_true(
		children.size() == 2
		and typeof(children[0]) == TYPE_INT
		and typeof(children[1]) == TYPE_INT
		and int(children[0]) == 4
		and int(children[1]) == 5,
		"Children IDs are normalized to unique ints"
	)

	_assert_true(
		rejected_by.size() == 2
		and typeof(rejected_by[0]) == TYPE_INT
		and typeof(rejected_by[1]) == TYPE_INT
		and int(rejected_by[0]) == 6
		and int(rejected_by[1]) == 7,
		"Rejected-by Character IDs are normalized to unique ints"
	)

	_assert_true(
		nullable_character.get("partner_id", null) == null
		and nullable_character.get("linked_character_id", null) == null,
		"Nullable Character ID fields remain null"
	)

	CharacterManager.characters = original_characters


func _test_load_game_screen_binding() -> void:
	var screen := (
		LOAD_GAME_SCREEN.instantiate()
	)

	add_child(
		screen
	)

	await get_tree().process_frame
	await get_tree().process_frame

	var slot_zero := screen.get_node_or_null(
		"Modal/Inner/Content/Slots/Williams"
	)

	_assert_true(
		slot_zero != null,
		"Existing Load Game slot remains in the scene"
	)

	if slot_zero != null:
		_assert_true(
			String(
				slot_zero.get(
					"family_name"
				)
			) == "Johnson Family",
			"Load Game card displays real save metadata"
		)

		var load_button := slot_zero.get_node_or_null(
			"Padding/Content/LoadCenter/LoadButton"
		) as TextureButton

		_assert_true(
			load_button != null
			and not load_button.disabled,
			"Occupied slot LOAD button is enabled"
		)

	var slot_one := screen.get_node_or_null(
		"Modal/Inner/Content/Slots/Anderson"
	)

	if slot_one != null:
		_assert_true(
			String(
				slot_one.get(
					"family_name"
				)
			) == "EMPTY SLOT",
			"Empty slot no longer shows fake family data"
		)

		var empty_load_button := (
			slot_one.get_node_or_null(
				"Padding/Content/LoadCenter/LoadButton"
			) as TextureButton
		)

		_assert_true(
			empty_load_button != null
			and empty_load_button.disabled,
			"Empty slot LOAD button is disabled"
		)

	screen.queue_free()
	await get_tree().process_frame


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
						TEST_SAVE_DIRECTORY.path_join(file_name)
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
