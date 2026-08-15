extends Node

var passed := 0
var failed := 0

const RELATIONSHIP_NPC_MANAGER_SCRIPT := preload(
	"res://Autoload/RelationshipNPCManager.gd"
)

var manager: Node
var saved_characters: Array
var saved_next_character_id: int


func _ready() -> void:
	if has_node("/root/RelationshipNPCManager"):
		manager = get_node("/root/RelationshipNPCManager")
	else:
		manager = RELATIONSHIP_NPC_MANAGER_SCRIPT.new()
		add_child(manager)

	saved_characters = CharacterManager.characters.duplicate(true)
	saved_next_character_id = CharacterManager.next_character_id

	_run_tests()

	CharacterManager.characters = saved_characters
	CharacterManager.next_character_id = saved_next_character_id

	print(
		"Relationship NPC tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)


func _run_tests() -> void:
	_test_age_rules()
	_test_generation()
	_test_marriage_conversion()
	_test_fertility()
	_test_adoption_rule()


func _assert_true(
	condition: bool,
	test_name: String
) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)


func _make_family_character(
	age: int,
	gender: String
) -> Dictionary:
	var character := CharacterManager.create_base_starting_character(
		"Test",
		gender
	)

	character["birth_date"] = CharacterManager.generate_birth_date_for_age(
		age
	)
	character["is_player_family"] = true
	character["partner_id"] = null

	CharacterManager.characters.append(character)

	return character


func _reset_world() -> void:
	CharacterManager.characters = []
	CharacterManager.next_character_id = 1


func _test_age_rules() -> void:
	_reset_world()

	var age_54 := _make_family_character(54, "male")
	var age_55 := _make_family_character(55, "male")

	_assert_true(
		manager.is_character_relationship_eligible(age_54)
		and not manager.is_character_relationship_eligible(age_55),
		"Relationship events stop after age 54"
	)


func _test_generation() -> void:
	_reset_world()

	var family_character := _make_family_character(30, "male")
	var candidate: Dictionary = manager.create_relationship_candidate(
	int(family_character["character_id"])
)

	var age := CharacterManager.get_character_age(candidate)

	_assert_true(
		not candidate.is_empty()
		and age >= 18
		and age <= 44
		and int(candidate["linked_character_id"])
			== int(family_character["character_id"])
		and not bool(candidate["is_player_family"]),
		"Candidate respects 18-50 generation and 14-year age gap"
	)


func _test_marriage_conversion() -> void:
	_reset_world()

	var family_character := _make_family_character(30, "male")
	var candidate: Dictionary = manager.create_relationship_candidate(
	int(family_character["character_id"])
)

	var ok: bool = bool(
	manager.make_candidate_family_member(
		int(candidate["character_id"]),
		int(family_character["character_id"])
	)
)

	_assert_true(
		ok
		and bool(candidate["is_player_family"])
		and int(candidate["partner_id"])
			== int(family_character["character_id"])
		and int(family_character["partner_id"])
			== int(candidate["character_id"]),
		"Marriage converts candidate into playable family member"
	)


func _test_fertility() -> void:
	_reset_world()

	var female_49 := _make_family_character(49, "female")
	var female_50 := _make_family_character(50, "female")

	_assert_true(
		manager.can_have_biological_child(female_49)
		and not manager.can_have_biological_child(female_50),
		"Female fertility ends at age 50"
	)


func _test_adoption_rule() -> void:
	_reset_world()

	var female_one := _make_family_character(30, "female")
	var female_two := _make_family_character(31, "female")

	female_one["partner_id"] = female_two["character_id"]
	female_two["partner_id"] = female_one["character_id"]

	var same_sex_allowed: bool = bool(
	manager.can_adopt(
		female_one,
		female_two
	)
)

	_reset_world()

	var male := _make_family_character(30, "male")
	var female := _make_family_character(30, "female")

	male["partner_id"] = female["character_id"]
	female["partner_id"] = male["character_id"]

	var opposite_sex_blocked: bool = not bool(
	manager.can_adopt(
		male,
		female
	)
)

	_assert_true(
		same_sex_allowed
		and opposite_sex_blocked,
		"Adoption is restricted to same-sex marriages"
	)
