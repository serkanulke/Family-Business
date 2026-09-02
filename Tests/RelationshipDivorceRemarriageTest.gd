extends Node

const RELATIONSHIP_MANAGER_SCRIPT := preload(
	"res://Autoload/RelationshipNPCManager.gd"
)

var passed: int = 0
var failed: int = 0

var relationship_manager: Node

var original_characters: Array = []
var original_businesses: Array = []
var original_houses: Array = []
var original_time: Dictionary = {}
var original_settings: Dictionary = {}


func _ready() -> void:
	_backup_runtime_state()
	_prepare_test_runtime()

	relationship_manager = RELATIONSHIP_MANAGER_SCRIPT.new()
	add_child(relationship_manager)
	relationship_manager.load_relationship_npc_data()

	print("")
	print("========================================")
	print("Relationship divorce/remarriage tests starting")
	print("========================================")

	_test_divorce_clears_marriage_and_removes_external_spouse()
	_test_divorce_removes_external_spouse_house_resident()
	_test_child_parent_ids_survive_divorce()
	_test_divorce_releases_family_business_slot()
	_test_divorce_removes_external_spouse_house_role_only()
	_test_one_year_cooldown_blocks_immediate_return()
	_test_cooldown_completion_allows_returning_candidate()
	_test_remarriage_reuses_same_character_id()
	_test_same_sex_setting_blocks_only_new_marriage()
	_test_existing_same_sex_marriage_survives_setting_change()

	print("")
	print("========================================")
	print(
		"Relationship divorce/remarriage tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL RELATIONSHIP DIVORCE/REMARRIAGE TESTS PASSED."
		)
	else:
		push_error(
			"Relationship divorce/remarriage has %d failing test(s)."
			% failed
		)

	_restore_runtime_state()


func _backup_runtime_state() -> void:
	original_characters = CharacterManager.characters.duplicate(
		true
	)

	original_businesses = BusinessManager.businesses.duplicate(
		true
	)
	original_houses = HouseManager.houses.duplicate(
		true
	)

	original_time = {
		"year": TimeManager.current_year,
		"month": TimeManager.current_month,
		"day": TimeManager.current_day,
		"paused": TimeManager.is_paused
	}

	original_settings = {
		"same_sex": GameManager.allow_same_sex_marriage,
		"distant": GameManager.allow_distant_relative_marriage,
		"ex_spouse": GameManager.allow_ex_spouse_remarriage
	}


func _prepare_test_runtime() -> void:
	TimeManager.current_year = 2000
	TimeManager.current_month = 6
	TimeManager.current_day = 15
	TimeManager.is_paused = true

	GameManager.set_same_sex_marriage_enabled(
		true
	)
	GameManager.set_ex_spouse_remarriage_enabled(
		true
	)

	var family_parent := _make_character(
		1,
		"female",
		"1970-01-01",
		true,
		null,
		2,
		[3]
	)

	var external_spouse := _make_character(
		2,
		"male",
		"1968-01-01",
		true,
		"relationship_npc",
		1,
		[3]
	)
	external_spouse["relationship_status"] = "married"

	var child := _make_character(
		3,
		"female",
		"1995-01-01",
		true,
		null,
		null,
		[]
	)
	child["parent_ids"] = [
		1,
		2
	]

	var future_partner := _make_character(
		4,
		"female",
		"1972-01-01",
		true,
		null,
		null,
		[]
	)

	CharacterManager.characters = [
		family_parent,
		external_spouse,
		child,
		future_partner
	]

	BusinessManager.businesses = [
		{
			"business_instance_id": "business_test",
			"business_type_id": "test_type",
			"slots": [
				{
					"slot_id": "slot_test",
					"assigned_character_id": 2,
					"assigned_npc_id": null
				}
			]
		}
	]

	HouseManager.houses = [{
		"house_instance_id": "relationship_house",
		"house_definition_id": "family_house",
		"property_id": "relationship_house_plot",
		"level": 1,
		"role_assignments": {
			"head_of_household": 1,
			"cook": null,
			"housekeeper": null,
			"caregiver": null
		},
		"resident_character_ids": [2, 3]
	}]


func _make_character(
	character_id: int,
	gender: String,
	birth_date: String,
	is_player_family: bool,
	character_type: Variant,
	partner_id: Variant,
	children_ids: Array
) -> Dictionary:
	var character: Dictionary = {
		"character_id": character_id,
		"first_name": "C" + str(character_id),
		"gender": gender,
		"birth_date": birth_date,
		"is_alive": true,
		"is_player_family": is_player_family,
		"partner_id": partner_id,
		"parent_ids": [],
		"children_ids": children_ids.duplicate(),
		"linked_character_id": null,
		"relationship_status": "",
		"relationship_cooldown_until": null,
		"is_retired": false,
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"last_salary": 0,
		"pension": 0,
		"unemployment_start_date": null,
		"job_offer_cooldown_until": null
	}

	if character_type != null:
		character["character_type"] = character_type

	return character


func _test_divorce_clears_marriage_and_removes_external_spouse() -> void:
	var result: bool = relationship_manager.divorce_characters(
		1,
		2
	)

	var family_parent := CharacterManager.get_character_by_id(
		1
	)
	var external_spouse := CharacterManager.get_character_by_id(
		2
	)

	var valid: bool = (
		result
		and family_parent.get("partner_id", null) == null
		and external_spouse.get("partner_id", null) == null
		and not bool(
			external_spouse.get(
				"is_player_family",
				true
			)
		)
		and String(
			external_spouse.get(
				"relationship_status",
				""
			)
		) == "divorced"
		and String(
			external_spouse.get(
				"relationship_cooldown_until",
				""
			)
		) == "2001-06-15"
	)

	_assert_true(
		valid,
		"Divorce clears partner links and returns external spouse to NPC state"
	)


func _test_child_parent_ids_survive_divorce() -> void:
	var child := CharacterManager.get_character_by_id(
		3
	)

	var parent_ids_value = child.get(
		"parent_ids",
		[]
	)

	var valid: bool = (
		typeof(parent_ids_value) == TYPE_ARRAY
		and parent_ids_value.size() == 2
		and parent_ids_value.has(1)
		and parent_ids_value.has(2)
	)

	_assert_true(
		valid,
		"Divorce never changes the child's parent_ids"
	)


func _test_divorce_removes_external_spouse_house_resident() -> void:
	var former_spouse_assignment := HouseManager.get_character_assignment(2)
	var remaining_spouse_assignment := HouseManager.get_character_assignment(1)
	var child_assignment := HouseManager.get_character_assignment(3)

	_assert_true(
		former_spouse_assignment.is_empty()
		and String(remaining_spouse_assignment.get("house_instance_id", "")) == "relationship_house"
		and String(remaining_spouse_assignment.get("assignment_type", "")) == "role"
		and String(child_assignment.get("house_instance_id", "")) == "relationship_house",
		"D-158 removes only the departing resident spouse from the House"
	)


func _test_divorce_releases_family_business_slot() -> void:
	var slot := BusinessManager.get_slot(
		"business_test",
		"slot_test"
	)

	_assert_true(
		not slot.is_empty()
		and slot.get(
			"assigned_character_id",
			null
		) == null,
		"Departing external spouse is removed from family-business slot"
	)


func _test_divorce_removes_external_spouse_house_role_only() -> void:
	var family_spouse := _make_character(7, "female", "1970-01-01", true, null, 8, [])
	var external_spouse := _make_character(8, "male", "1969-01-01", true, "relationship_npc", 7, [])
	external_spouse["relationship_status"] = "married"
	var unrelated_resident := _make_character(9, "female", "1975-01-01", true, null, null, [])
	CharacterManager.characters.append(family_spouse)
	CharacterManager.characters.append(external_spouse)
	CharacterManager.characters.append(unrelated_resident)
	HouseManager.houses.append({
		"house_instance_id": "relationship_role_house",
		"house_definition_id": "family_house",
		"property_id": "relationship_role_house_plot",
		"level": 1,
		"role_assignments": {
			"head_of_household": 8,
			"cook": null,
			"housekeeper": null,
			"caregiver": null
		},
		"resident_character_ids": [7, 9]
	})

	var divorced: bool = relationship_manager.divorce_characters(7, 8)
	var house := HouseManager.get_house_by_instance_id("relationship_role_house")
	var roles: Dictionary = house.get("role_assignments", {})
	var residents: Array = house.get("resident_character_ids", [])

	_assert_true(
		divorced
		and roles.get("head_of_household", -1) == null
		and residents.has(7)
		and residents.has(9)
		and residents.size() == 2
		and HouseManager.get_character_assignment(8).is_empty(),
		"D-158 clears a departing spouse House role without removing unrelated occupants"
	)


func _test_one_year_cooldown_blocks_immediate_return() -> void:
	var candidates: Array = (
		relationship_manager.get_returning_relationship_candidates_for(
			4
		)
	)

	_assert_true(
		candidates.is_empty(),
		"One-year divorce cooldown blocks immediate re-entry"
	)


func _test_cooldown_completion_allows_returning_candidate() -> void:
	TimeManager.current_year = 2001
	TimeManager.current_month = 6
	TimeManager.current_day = 15

	var candidates: Array = (
		relationship_manager.get_returning_relationship_candidates_for(
			4
		)
	)

	var found := false

	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = candidate_value

		if int(
			candidate.get(
				"character_id",
				0
			)
		) == 2:
			found = true
			break

	var prepared: bool = (
		relationship_manager.prepare_returning_relationship_candidate(
			2,
			4
		)
	)

	_assert_true(
		found and prepared,
		"Former spouse becomes eligible again on the exact one-year date"
	)


func _test_remarriage_reuses_same_character_id() -> void:
	GameManager.set_ex_spouse_remarriage_enabled(
		false
	)

	var blocked_when_disabled: bool = not (
		relationship_manager.make_candidate_family_member(
			2,
			4
		)
	)

	GameManager.set_ex_spouse_remarriage_enabled(
		true
	)

	var remarried: bool = (
		relationship_manager.make_candidate_family_member(
			2,
			4
		)
	)

	var former_spouse := CharacterManager.get_character_by_id(
		2
	)
	var new_partner := CharacterManager.get_character_by_id(
		4
	)

	var valid: bool = (
		blocked_when_disabled
		and remarried
		and int(
			former_spouse.get(
				"character_id",
				0
			)
		) == 2
		and bool(
			former_spouse.get(
				"is_player_family",
				false
			)
		)
		and former_spouse.get(
			"partner_id",
			null
		) == 4
		and new_partner.get(
			"partner_id",
			null
		) == 2
	)

	_assert_true(
		valid,
		"Remarriage reuses the same persistent Character ID"
	)


func _test_same_sex_setting_blocks_only_new_marriage() -> void:
	var candidate := _make_character(
		5,
		"female",
		"1975-01-01",
		false,
		"relationship_npc",
		null,
		[]
	)
	candidate["relationship_status"] = "candidate"
	candidate["linked_character_id"] = 6

	var target := _make_character(
		6,
		"female",
		"1976-01-01",
		true,
		null,
		null,
		[]
	)

	CharacterManager.characters.append(candidate)
	CharacterManager.characters.append(target)

	GameManager.set_same_sex_marriage_enabled(
		false
	)

	var blocked: bool = not relationship_manager.make_candidate_family_member(
		5,
		6
	)

	GameManager.set_same_sex_marriage_enabled(
		true
	)

	var allowed: bool = relationship_manager.make_candidate_family_member(
		5,
		6
	)

	_assert_true(
		blocked and allowed,
		"Same-sex setting affects new marriages without changing Character data"
	)


func _test_existing_same_sex_marriage_survives_setting_change() -> void:
	GameManager.set_same_sex_marriage_enabled(
		false
	)

	var first := CharacterManager.get_character_by_id(
		5
	)
	var second := CharacterManager.get_character_by_id(
		6
	)

	var valid: bool = relationship_manager.are_married_partners(
		first,
		second
	)

	_assert_true(
		valid,
		"Disabling Same-sex Marriage does not break an existing marriage"
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


func _restore_runtime_state() -> void:
	CharacterManager.characters = original_characters
	BusinessManager.businesses = original_businesses
	HouseManager.houses = original_houses

	TimeManager.current_year = int(
		original_time.get(
			"year",
			1985
		)
	)
	TimeManager.current_month = int(
		original_time.get(
			"month",
			1
		)
	)
	TimeManager.current_day = int(
		original_time.get(
			"day",
			26
		)
	)
	TimeManager.is_paused = bool(
		original_time.get(
			"paused",
			true
		)
	)

	GameManager.set_same_sex_marriage_enabled(
		bool(
			original_settings.get(
				"same_sex",
				true
			)
		)
	)
	GameManager.set_distant_relative_marriage_enabled(
		bool(
			original_settings.get(
				"distant",
				false
			)
		)
	)
	GameManager.set_ex_spouse_remarriage_enabled(
		bool(
			original_settings.get(
				"ex_spouse",
				false
			)
		)
	)
