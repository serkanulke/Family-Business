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


func _ready() -> void:
	original_save_directory = (
		SaveManager.save_directory
	)

	SaveManager.save_directory = (
		TEST_SAVE_DIRECTORY
	)

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

	_assert_true(
		SaveManager.save_game(0),
		"Runtime state can be written to slot 0"
	)

	_assert_true(
		SaveManager.has_save(0),
		"Saved slot is reported as occupied"
	)

	var summary := (
		SaveManager.get_slot_summary(0)
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
		SaveManager.load_game(0),
		"Saved slot can be loaded"
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

	await _test_load_game_screen_binding()

	_cleanup_test_saves()

	SaveManager.save_directory = (
		original_save_directory
	)

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
	for slot_index in range(
		SaveManager.MAX_SAVE_SLOTS
	):
		SaveManager.delete_save(
			slot_index
		)

	var absolute_directory := (
		ProjectSettings.globalize_path(
			TEST_SAVE_DIRECTORY
		)
	)

	if DirAccess.dir_exists_absolute(
		absolute_directory
	):
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
