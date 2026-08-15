extends Node

var passed: int = 0
var failed: int = 0

const RELATIONSHIP_NPC_MANAGER_SCRIPT := preload(
	"res://Autoload/RelationshipNPCManager.gd"
)

var relationship_manager: Node

var saved_characters: Array = []
var saved_next_character_id: int = 1
var saved_generation_config: Dictionary = {}


func _ready() -> void:
	if has_node(
		"/root/RelationshipNPCManager"
	):
		relationship_manager = get_node(
			"/root/RelationshipNPCManager"
		)
	else:
		relationship_manager = (
			RELATIONSHIP_NPC_MANAGER_SCRIPT.new()
		)
		relationship_manager.name = (
			"RelationshipNPCManagerFamilyCreationTest"
		)
		add_child(
			relationship_manager
		)

	_save_state()

	print("")
	print("========================================")
	print("Family creation tests starting")
	print("========================================")

	_run_tests()
	_restore_state()

	print("")
	print("========================================")
	print(
		"Family creation tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL FAMILY CREATION TESTS PASSED."
		)
	else:
		push_error(
			"Family creation system has %d failing test(s)."
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

	saved_generation_config = (
		relationship_manager.generation_config.duplicate(
			true
		)
	)


func _restore_state() -> void:
	CharacterManager.characters = (
		saved_characters
	)

	CharacterManager.next_character_id = (
		saved_next_character_id
	)

	relationship_manager.generation_config = (
		saved_generation_config
	)


func _reset_world() -> void:
	CharacterManager.characters = []
	CharacterManager.next_character_id = 1


func _run_tests() -> void:
	_test_female_same_sex_donor_conception()
	_test_non_carrier_spouse_does_not_supply_genetic_stat_bonus()
	_test_donor_conception_fertility_limit()
	_test_same_sex_adoption()
	_test_opposite_sex_adoption_blocked()


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


func _make_character(
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

	character["is_player_family"] = true
	character["partner_id"] = null

	CharacterManager.characters.append(
		character
	)

	return character


func _marry(
	partner_one: Dictionary,
	partner_two: Dictionary
) -> void:
	partner_one["partner_id"] = int(
		partner_two[
			"character_id"
		]
	)

	partner_two["partner_id"] = int(
		partner_one[
			"character_id"
		]
	)


func _test_female_same_sex_donor_conception() -> void:
	_reset_world()

	var carrier: Dictionary = _make_character(
		"Avery",
		"female",
		30
	)

	var spouse: Dictionary = _make_character(
		"Riley",
		"female",
		31
	)

	_marry(
		carrier,
		spouse
	)

	carrier["logic"] = 100
	spouse["logic"] = 0

	var child: Dictionary = (
		relationship_manager.create_donor_conceived_child(
			"Robin",
			"female",
			int(
				carrier[
					"character_id"
				]
			),
			int(
				spouse[
					"character_id"
				]
			)
		)
	)

	var parent_ids_value = child.get(
		"parent_ids",
		[]
	)

	var child_id: int = int(
		child.get(
			"character_id",
			0
		)
	)

	var valid: bool = (
		not child.is_empty()
		and typeof(
			parent_ids_value
		) == TYPE_ARRAY
		and parent_ids_value.size() == 2
		and int(
			parent_ids_value[0]
		) == int(
			carrier[
				"character_id"
			]
		)
		and int(
			parent_ids_value[1]
		) == int(
			spouse[
				"character_id"
			]
		)
		and not bool(
			child.get(
				"is_adopted",
				true
			)
		)
		and int(
			child.get(
				"logic",
				0
			)
		) >= 2
		and carrier.get(
			"children_ids",
			[]
		).has(
			child_id
		)
		and spouse.get(
			"children_ids",
			[]
		).has(
			child_id
		)
	)

	_assert_true(
		valid,
		"Female same-sex marriage can create donor-conceived biological child"
	)


func _test_non_carrier_spouse_does_not_supply_genetic_stat_bonus() -> void:
	_reset_world()

	var carrier: Dictionary = _make_character(
		"Morgan",
		"female",
		30
	)

	var spouse: Dictionary = _make_character(
		"Jamie",
		"female",
		30
	)

	_marry(
		carrier,
		spouse
	)

	carrier["logic"] = 0
	spouse["logic"] = 100

	var child: Dictionary = (
		relationship_manager.create_donor_conceived_child(
			"Casey",
			"male",
			int(
				carrier[
					"character_id"
				]
			),
			int(
				spouse[
					"character_id"
				]
			)
		)
	)

	_assert_true(
		not child.is_empty()
		and int(
			child.get(
				"logic",
				99
			)
		) <= CharacterManager.BABY_STAT_MAX,
		"Donor conception separates genetic inheritance from family-tree parent"
	)


func _test_donor_conception_fertility_limit() -> void:
	_reset_world()

	var carrier: Dictionary = _make_character(
		"Taylor",
		"female",
		50
	)

	var spouse: Dictionary = _make_character(
		"Jordan",
		"female",
		49
	)

	_marry(
		carrier,
		spouse
	)

	var child: Dictionary = (
		relationship_manager.create_donor_conceived_child(
			"Blocked",
			"female",
			int(
				carrier[
					"character_id"
				]
			),
			int(
				spouse[
					"character_id"
				]
			)
		)
	)

	_assert_true(
		child.is_empty(),
		"Female age 50 cannot be selected as donor-conception carrier"
	)


func _test_same_sex_adoption() -> void:
	_reset_world()

	var parent_one: Dictionary = _make_character(
		"Chris",
		"male",
		35
	)

	var parent_two: Dictionary = _make_character(
		"Sam",
		"male",
		36
	)

	_marry(
		parent_one,
		parent_two
	)

	for stat_name in CharacterManager.CHARACTER_STAT_NAMES:
		parent_one[stat_name] = 100
		parent_two[stat_name] = 100

	var child: Dictionary = (
		relationship_manager.create_adopted_child(
			"Alex",
			"male",
			int(
				parent_one[
					"character_id"
				]
			),
			int(
				parent_two[
					"character_id"
				]
			)
		)
	)

	var stats_have_no_parent_bonus: bool = true

	for stat_name in CharacterManager.CHARACTER_STAT_NAMES:
		if int(
			child.get(
				stat_name,
				99
			)
		) > CharacterManager.BABY_STAT_MAX:
			stats_have_no_parent_bonus = false
			break

	var valid: bool = (
		not child.is_empty()
		and bool(
			child.get(
				"is_adopted",
				false
			)
		)
		and child.get(
			"parent_ids",
			[]
		).size() == 2
		and stats_have_no_parent_bonus
	)

	_assert_true(
		valid,
		"Same-sex marriage can adopt without genetic/stat inheritance"
	)


func _test_opposite_sex_adoption_blocked() -> void:
	_reset_world()

	var parent_one: Dictionary = _make_character(
		"Drew",
		"male",
		35
	)

	var parent_two: Dictionary = _make_character(
		"Emma",
		"female",
		35
	)

	_marry(
		parent_one,
		parent_two
	)

	var child: Dictionary = (
		relationship_manager.create_adopted_child(
			"Blocked",
			"female",
			int(
				parent_one[
					"character_id"
				]
			),
			int(
				parent_two[
					"character_id"
				]
			)
		)
	)

	_assert_true(
		child.is_empty(),
		"Opposite-sex marriage cannot adopt"
	)
