extends Node

const FAMILY_TREE_SCREEN := preload(
	"res://Scenes/FamilyTree/FamilyTreeScreen.tscn"
)

var passed: int = 0
var failed: int = 0

var saved_family_name: String = ""


func _ready() -> void:
	saved_family_name = GameManager.family_name

	print("")
	print("========================================")
	print("Family name runtime tests")
	print("========================================")

	_test_family_name_state()
	await _test_family_tree_binding()

	GameManager.set_family_name(
		saved_family_name
	)

	print("")
	print(
		"Family name runtime tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL FAMILY NAME RUNTIME TESTS PASSED."
		)
	else:
		push_error(
			"Family name runtime has %d failing test(s)."
			% failed
		)


func _test_family_name_state() -> void:
	GameManager.set_family_name(
		"  Williams  "
	)

	_assert_true(
		GameManager.family_name == "Williams",
		"GameManager stores a cleaned family name"
	)

	GameManager.set_family_name(
		""
	)

	_assert_true(
		GameManager.family_name.is_empty(),
		"GameManager supports an unassigned family name before New Game provides one"
	)


func _test_family_tree_binding() -> void:
	GameManager.set_family_name(
		"Johnson"
	)

	var screen := FAMILY_TREE_SCREEN.instantiate()
	add_child(
		screen
	)

	await get_tree().process_frame
	await get_tree().process_frame

	_assert_true(
		String(
			screen.get(
				"family_name"
			)
		) == "JOHNSON",
		"Family Tree receives the runtime family name"
	)

	var label_value = screen.get(
		"family_name_label"
	)

	var label_is_correct := false

	if label_value is Label:
		var label := label_value as Label
		label_is_correct = (
			label.text == "JOHNSON"
		)

	_assert_true(
		label_is_correct,
		"Family Tree logo displays the runtime family name"
	)

	screen.queue_free()
	await get_tree().process_frame


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
