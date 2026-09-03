extends Node

const LOAD_GAME_SCREEN := preload(
	"res://Scenes/LoadGame/LoadGameScreen.tscn"
)

const TEST_SAVE_DIRECTORY := (
	"user://family_business_dynamic_save_test"
)

const TEST_ITEM_ID := (
	"accessory_common_black_gold_browline_sunglasses_007"
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
	print("Dynamic SaveManager tests")
	print("========================================")

	_assert_true(
		SaveManager.get_save_count() == 0,
		"Save list starts empty"
	)

	await _test_empty_load_screen()

	var first_character := GameManager.start_new_game(
		"William",
		"male",
		"Johnson"
	)

	_assert_true(
		not first_character.is_empty(),
		"First new game creates a real character"
	)

	var first_save_id := SaveManager.current_save_id

	_assert_true(
		first_save_id > 0,
		"First new game automatically creates a save file"
	)

	_assert_true(
		SaveManager.get_save_count() == 1,
		"One new game produces exactly one save file"
	)

	BusinessManager.businesses = [{
		"business_instance_id": "business_0001",
		"business_type_id": "cafe",
		"plot_id": "cafe_01",
		"level": 1,
		"slots": [
			{"slot_id": "manager_01", "assigned_character_id": null, "assigned_npc_id": null},
		],
	}]
	BusinessManager.next_business_instance_number = 2
	_assert_true(
		SaveManager.save_game(first_save_id),
		"Stable Map property plot_id can be written with business state"
	)

	GameManager.set_family_money(
		32100
	)
	GameManager.set_diamonds(
		7
	)

	var preserved_item := ItemManager.create_item_instance(
		TEST_ITEM_ID
	)
	var preserved_item_instance_id := String(
		preserved_item.get("instance_id", "")
	)
	_assert_true(
		not preserved_item_instance_id.is_empty(),
		"First save owns a real ItemInstance before another new game starts"
	)
	_assert_true(
		SaveManager.save_game(first_save_id),
		"First save captures Item state before the new-game transition"
	)

	await get_tree().process_frame
	await get_tree().process_frame

	var first_summary := SaveManager.get_save_summary(
		first_save_id
	)

	_assert_true(
		int(
			first_summary.get(
				"wealth",
				0
			)
		) == 32100,
		"Important state change is autosaved to the current file"
	)

	var second_character := GameManager.start_new_game(
		"Emma",
		"female",
		"Anderson"
	)

	_assert_true(
		not second_character.is_empty(),
		"Second new game creates a real character"
	)

	var second_save_id := SaveManager.current_save_id

	_assert_true(
		second_save_id > 0
		and second_save_id != first_save_id,
		"Every new game receives a new unique save ID"
	)

	_assert_true(
		ItemManager.get_inventory_item_instance(preserved_item_instance_id).is_empty(),
		"Second new game starts with clean Item runtime state"
	)

	_assert_true(
		SaveManager.get_save_count() == 2,
		"Two new games remain as two independent save files"
	)

	_assert_true(
		SaveManager.get_most_recent_save_id()
		== second_save_id,
		"Continue resolves to the most recent save"
	)

	await _test_populated_load_screen()

	_assert_true(
		SaveManager.load_game(
			first_save_id
		),
		"An older save can be loaded directly"
	)

	_assert_true(
		GameManager.family_name == "Johnson",
		"Loading an older file restores its family"
	)

	_assert_true(
		GameManager.family_money == 32100,
		"Loading an older file restores its autosaved money"
	)

	_assert_true(
		not ItemManager.get_inventory_item_instance(preserved_item_instance_id).is_empty(),
		"Starting a new game does not erase Item state from the previous save file"
	)

	var restored_business := BusinessManager.get_business_on_plot("cafe_01")
	_assert_true(
		str(restored_business.get("business_instance_id", "")) == "business_0001"
		and str(restored_business.get("plot_id", "")) == "cafe_01",
		"Save/load preserves the stable Map property plot_id link"
	)

	_cleanup_test_saves()
	SaveManager.current_save_id = -1
	SaveManager.save_directory = original_save_directory

	print("")
	print(
		"Dynamic SaveManager tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL DYNAMIC SAVE MANAGER TESTS PASSED."
		)
	else:
		push_error(
			"Dynamic SaveManager has %d failing test(s)."
			% failed
		)


func _test_empty_load_screen() -> void:
	var screen := LOAD_GAME_SCREEN.instantiate()
	add_child(screen)

	await get_tree().process_frame
	await get_tree().process_frame

	var save_list := screen.get_node_or_null(
		"Modal/Inner/Content/SlotsScroll/Slots"
	)

	var count_label := screen.get_node_or_null(
		"Modal/Inner/Content/SaveIndicator/Center/Row/Label"
	) as Label

	_assert_true(
		save_list != null
		and save_list.get_child_count() == 0,
		"No save files means no save cards are displayed"
	)

	_assert_true(
		count_label != null
		and count_label.text == "0 Save Files",
		"Save counter displays the real zero count"
	)

	screen.queue_free()
	await get_tree().process_frame


func _test_populated_load_screen() -> void:
	var screen := LOAD_GAME_SCREEN.instantiate()
	add_child(screen)

	await get_tree().process_frame
	await get_tree().process_frame

	var save_list := screen.get_node_or_null(
		"Modal/Inner/Content/SlotsScroll/Slots"
	)

	var count_label := screen.get_node_or_null(
		"Modal/Inner/Content/SaveIndicator/Center/Row/Label"
	) as Label

	_assert_true(
		save_list != null
		and save_list.get_child_count() == 2,
		"Load Game displays only the two existing save files"
	)

	_assert_true(
		count_label != null
		and count_label.text == "2 Save Files",
		"Save counter reflects the real file count"
	)

	if save_list != null and save_list.get_child_count() == 2:
		var first_card := save_list.get_child(0)

		_assert_true(
			String(
				first_card.get(
					"family_name"
				)
			) == "Anderson Family",
			"Newest save is displayed first"
		)

	screen.queue_free()
	await get_tree().process_frame


func _cleanup_test_saves() -> void:
	if not DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(
			TEST_SAVE_DIRECTORY
		)
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
		ProjectSettings.globalize_path(
			TEST_SAVE_DIRECTORY
		)
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
