extends Node

const MAIN_SCENE := preload("res://Scenes/Main/Main.tscn")

var passed: int = 0
var failed: int = 0


func _ready() -> void:
	var main_instance := MAIN_SCENE.instantiate()
	add_child(main_instance)

	await get_tree().process_frame
	await get_tree().process_frame

	print("")
	print("========================================")
	print("Main / Family Tree integration test")
	print("========================================")

	_assert_true(
		main_instance.get_node_or_null("World/FamilyTreeScreen") != null,
		"Main uses the production FamilyTreeScreen"
	)

	_assert_true(
		main_instance.get_node_or_null("World/FamilyTree") == null,
		"Legacy standalone FamilyTree is no longer instantiated by Main"
	)

	_assert_true(
		main_instance.get_node_or_null("UI/TopBar") == null,
		"Legacy standalone TopBar is no longer instantiated by Main"
	)

	_assert_true(
		main_instance.get_node_or_null("UI/BottomBar") == null,
		"Legacy standalone BottomBar is no longer instantiated by Main"
	)

	var screen := main_instance.get_node_or_null("World/FamilyTreeScreen")
	var refresh_available := (
		screen != null
		and screen.has_method("refresh_from_managers")
	)

	_assert_true(
		refresh_available,
		"Production screen exposes runtime manager refresh"
	)

	main_instance.call("show_screen", "map")
	await get_tree().process_frame
	await get_tree().process_frame
	var map_screen := main_instance.get_node_or_null("World/MapScreen")
	_assert_true(
		map_screen != null
		and map_screen.visible
		and not screen.visible
		and screen.process_mode == Node.PROCESS_MODE_DISABLED,
		"Map navigation shows one production content screen and disables Family Tree input"
	)

	main_instance.call("show_screen", "family_tree")
	await get_tree().process_frame
	_assert_true(
		screen.visible
		and screen.process_mode != Node.PROCESS_MODE_DISABLED
		and not map_screen.visible
		and map_screen.process_mode == Node.PROCESS_MODE_DISABLED,
		"Family Tree navigation restores the existing screen and disables Map input"
	)

	print("")
	print(
		"Main / Family Tree integration tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print("ALL MAIN / FAMILY TREE INTEGRATION TESTS PASSED.")
	else:
		push_error(
			"Main / Family Tree integration has %d failing test(s)."
			% failed
		)


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)
