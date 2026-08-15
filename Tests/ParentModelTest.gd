extends Node

var passed: int = 0
var failed: int = 0

var saved_characters: Array = []
var saved_next_character_id: int = 1


func _ready() -> void:
	_save_state()

	print("")
	print("========================================")
	print("Parent model tests starting")
	print("========================================")

	_run_tests()
	_restore_state()

	print("")
	print("========================================")
	print(
		"Parent model tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL PARENT MODEL TESTS PASSED."
		)
	else:
		push_error(
			"Parent model has %d failing test(s)."
			% failed
		)


func _save_state() -> void:
	saved_characters = (
		CharacterManager.characters.duplicate(
			true
		)
	)

	saved_next_character_id = (
		CharacterManager.next_character_id
	)


func _restore_state() -> void:
	CharacterManager.characters = (
		saved_characters
	)

	CharacterManager.next_character_id = (
		saved_next_character_id
	)


func _reset_world() -> void:
	CharacterManager.characters = []
	CharacterManager.next_character_id = 1


func _run_tests() -> void:
	_test_starting_character_parent_model()
	_test_biological_baby_parent_links()
	_test_legacy_parent_link_migration()


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


func _make_parent(
	first_name: String,
	gender: String,
	age: int
) -> Dictionary:
	var character: Dictionary = (
		CharacterManager.create_base_starting_character(
			first_name,
			gender
		)
	)

	character["birth_date"] = (
		CharacterManager.generate_birth_date_for_age(
			age
		)
	)

	CharacterManager.characters.append(
		character
	)

	return character


func _test_starting_character_parent_model() -> void:
	_reset_world()

	var character: Dictionary = (
		CharacterManager.create_base_starting_character(
			"Alex",
			"female"
		)
	)

	var parent_ids_value = character.get(
		"parent_ids",
		null
	)

	var valid: bool = bool(
		typeof(
			parent_ids_value
		) == TYPE_ARRAY
		and parent_ids_value.is_empty()
		and not character.has(
			"mother_id"
		)
		and not character.has(
			"father_id"
		)
		and not bool(
			character.get(
				"is_adopted",
				true
			)
		)
	)

	_assert_true(
		valid,
		"Starting character uses empty parent_ids"
	)


func _test_biological_baby_parent_links() -> void:
	_reset_world()

	var parent_one: Dictionary = _make_parent(
		"Jordan",
		"female",
		30
	)

	var parent_two: Dictionary = _make_parent(
		"Taylor",
		"male",
		31
	)

	var parent_one_id: int = int(
		parent_one[
			"character_id"
		]
	)

	var parent_two_id: int = int(
		parent_two[
			"character_id"
		]
	)

	var baby: Dictionary = (
		CharacterManager.create_baby_character(
			"Robin",
			"female",
			parent_one_id,
			parent_two_id
		)
	)

	var parent_ids_value = baby.get(
		"parent_ids",
		[]
	)

	var valid: bool = bool(
		not baby.is_empty()
		and typeof(
			parent_ids_value
		) == TYPE_ARRAY
		and parent_ids_value.size() == 2
		and int(
			parent_ids_value[0]
		) == parent_one_id
		and int(
			parent_ids_value[1]
		) == parent_two_id
		and not baby.has(
			"mother_id"
		)
		and not baby.has(
			"father_id"
		)
		and parent_one.get(
			"children_ids",
			[]
		).has(
			int(
				baby[
					"character_id"
				]
			)
		)
		and parent_two.get(
			"children_ids",
			[]
		).has(
			int(
				baby[
					"character_id"
				]
			)
		)
	)

	_assert_true(
		valid,
		"Biological baby stores two parent_ids and updates both parents"
	)


func _test_legacy_parent_link_migration() -> void:
	_reset_world()

	var legacy_character: Dictionary = {
		"character_id": 3,
		"mother_id": 1,
		"father_id": 2
	}

	CharacterManager.characters = [
		legacy_character
	]

	CharacterManager.normalize_character_parent_links()

	var parent_ids_value = legacy_character.get(
		"parent_ids",
		[]
	)

	var valid: bool = bool(
		typeof(
			parent_ids_value
		) == TYPE_ARRAY
		and parent_ids_value.size() == 2
		and int(
			parent_ids_value[0]
		) == 1
		and int(
			parent_ids_value[1]
		) == 2
		and not legacy_character.has(
			"mother_id"
		)
		and not legacy_character.has(
			"father_id"
		)
		and not bool(
			legacy_character.get(
				"is_adopted",
				true
			)
		)
	)

	_assert_true(
		valid,
		"Legacy mother_id/father_id data migrates to parent_ids"
	)
