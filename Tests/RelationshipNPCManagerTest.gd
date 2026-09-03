extends Node

var passed := 0
var failed := 0

const RELATIONSHIP_NPC_MANAGER_SCRIPT := preload(
	"res://Autoload/RelationshipNPCManager.gd"
)

var manager: Node
var saved_characters: Array
var saved_next_character_id: int
var saved_relationship_settings: Dictionary = {}

const TEST_GLOBAL_SETTINGS_PATH := (
	"user://family_business_relationship_settings_test.cfg"
)


func _ready() -> void:
	if has_node("/root/RelationshipNPCManager"):
		manager = get_node("/root/RelationshipNPCManager")
	else:
		manager = RELATIONSHIP_NPC_MANAGER_SCRIPT.new()
		add_child(manager)

	saved_characters = CharacterManager.characters.duplicate(true)
	saved_next_character_id = CharacterManager.next_character_id
	saved_relationship_settings = {
		"same_sex": GameManager.allow_same_sex_marriage,
		"distant": GameManager.allow_distant_relative_marriage,
		"ex_spouse": GameManager.allow_ex_spouse_remarriage
	}

	_run_tests()

	CharacterManager.characters = saved_characters
	CharacterManager.next_character_id = saved_next_character_id
	GameManager.set_same_sex_marriage_enabled(
		bool(saved_relationship_settings["same_sex"]),
		false
	)
	GameManager.set_distant_relative_marriage_enabled(
		bool(saved_relationship_settings["distant"]),
		false
	)
	GameManager.set_ex_spouse_remarriage_enabled(
		bool(saved_relationship_settings["ex_spouse"]),
		false
	)

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
	_test_external_relationship_status_mutation()
	_test_marriage_conversion()
	_test_distant_relative_marriage_boundary()
	_test_global_relationship_settings_persistence()
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


func _make_family_character_with_parents(
	age: int,
	gender: String,
	parent_ids: Array
) -> Dictionary:
	var character := _make_family_character(
		age,
		gender
	)
	character["parent_ids"] = parent_ids.duplicate()
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
		and not bool(candidate["is_player_family"])
		and candidate.has("portrait_variant_id")
		and not String(
			candidate.get(
				"portrait_path",
				""
			)
		).is_empty(),
		"Candidate respects age rules and receives canonical portrait state"
	)


func _test_external_relationship_status_mutation() -> void:
	_reset_world()

	var family_character := _make_family_character(30, "male")
	var candidate: Dictionary = manager.create_relationship_candidate(
		int(family_character["character_id"])
	)

	var status_changed: bool = manager.set_external_relationship_status(
		int(candidate["character_id"]),
		"dating"
	)
	var manager_owned_rejected: bool = not manager.set_external_relationship_status(
		int(candidate["character_id"]),
		"married"
	)

	_assert_true(
		status_changed
		and manager_owned_rejected
		and String(candidate.get("relationship_status", "")) == "dating",
		"External Relationship status is mutable without bypassing marriage/divorce"
	)


func _test_marriage_conversion() -> void:
	_reset_world()
	GameManager.set_same_sex_marriage_enabled(
		true,
		false
	)

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


func _test_distant_relative_marriage_boundary() -> void:
	_reset_world()

	GameManager.set_same_sex_marriage_enabled(
		true,
		false
	)

	var root := _make_family_character_with_parents(
		80,
		"female",
		[]
	)
	var branch_a := _make_family_character_with_parents(
		60,
		"male",
		[int(root["character_id"])]
	)
	var branch_b := _make_family_character_with_parents(
		59,
		"female",
		[int(root["character_id"])]
	)
	var first_cousin_a := _make_family_character_with_parents(
		40,
		"female",
		[int(branch_a["character_id"])]
	)
	var first_cousin_b := _make_family_character_with_parents(
		39,
		"male",
		[int(branch_b["character_id"])]
	)
	var second_cousin_a := _make_family_character_with_parents(
		20,
		"male",
		[int(first_cousin_a["character_id"])]
	)
	var second_cousin_b := _make_family_character_with_parents(
		21,
		"female",
		[int(first_cousin_b["character_id"])]
	)
	var third_generation_a := _make_family_character_with_parents(
		18,
		"female",
		[int(second_cousin_a["character_id"])]
	)
	var third_generation_b := _make_family_character_with_parents(
		18,
		"male",
		[int(second_cousin_b["character_id"])]
	)
	var unrelated := _make_family_character_with_parents(
		30,
		"male",
		[]
	)

	GameManager.set_distant_relative_marriage_enabled(
		false,
		false
	)

	var unrelated_allowed: bool = manager.is_marriage_allowed_by_settings(
		second_cousin_a,
		unrelated
	)
	var second_cousins_blocked_when_disabled: bool = not (
		manager.is_marriage_allowed_by_settings(
			second_cousin_a,
			second_cousin_b
		)
	)

	GameManager.set_distant_relative_marriage_enabled(
		true,
		false
	)

	var direct_ancestor_blocked: bool = not (
		manager.is_marriage_allowed_by_settings(
			root,
			branch_a
		)
	)
	var siblings_blocked: bool = not (
		manager.is_marriage_allowed_by_settings(
			branch_a,
			branch_b
		)
	)
	var aunt_nephew_blocked: bool = not (
		manager.is_marriage_allowed_by_settings(
			branch_b,
			first_cousin_a
		)
	)
	var first_cousins_blocked: bool = not (
		manager.is_marriage_allowed_by_settings(
			first_cousin_a,
			first_cousin_b
		)
	)
	var first_cousin_once_removed_blocked: bool = not (
		manager.is_marriage_allowed_by_settings(
			first_cousin_a,
			second_cousin_b
		)
	)
	var first_cousin_twice_removed_blocked: bool = not (
		manager.is_marriage_allowed_by_settings(
			first_cousin_a,
			third_generation_b
		)
	)
	var second_cousins_allowed: bool = (
		manager.is_marriage_allowed_by_settings(
			second_cousin_a,
			second_cousin_b
		)
	)
	var second_cousin_once_removed_allowed: bool = (
		manager.is_marriage_allowed_by_settings(
			third_generation_a,
			second_cousin_b
		)
	)

	_assert_true(
		unrelated_allowed
		and second_cousins_blocked_when_disabled
		and direct_ancestor_blocked
		and siblings_blocked
		and aunt_nephew_blocked
		and first_cousins_blocked
		and first_cousin_once_removed_blocked
		and first_cousin_twice_removed_blocked
		and second_cousins_allowed
		and second_cousin_once_removed_allowed,
		"Distant Relative Marriage allows second cousins and more distant only"
	)


func _test_global_relationship_settings_persistence() -> void:
	if FileAccess.file_exists(
		TEST_GLOBAL_SETTINGS_PATH
	):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(
				TEST_GLOBAL_SETTINGS_PATH
			)
		)

	GameManager.set_same_sex_marriage_enabled(
		false,
		false
	)
	GameManager.set_distant_relative_marriage_enabled(
		true,
		false
	)
	GameManager.set_ex_spouse_remarriage_enabled(
		true,
		false
	)

	var saved := GameManager.save_global_relationship_settings(
		TEST_GLOBAL_SETTINGS_PATH
	)

	GameManager.set_same_sex_marriage_enabled(
		true,
		false
	)
	GameManager.set_distant_relative_marriage_enabled(
		false,
		false
	)
	GameManager.set_ex_spouse_remarriage_enabled(
		false,
		false
	)

	var loaded := GameManager.load_global_relationship_settings(
		TEST_GLOBAL_SETTINGS_PATH
	)

	var values_restored := (
		not GameManager.allow_same_sex_marriage
		and GameManager.allow_distant_relative_marriage
		and GameManager.allow_ex_spouse_remarriage
	)

	if FileAccess.file_exists(
		TEST_GLOBAL_SETTINGS_PATH
	):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(
				TEST_GLOBAL_SETTINGS_PATH
			)
		)

	_assert_true(
		saved
		and loaded
		and values_restored,
		"Relationship Gameplay settings persist globally outside save files"
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
