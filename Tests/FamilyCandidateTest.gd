extends Node


var passed: int = 0
var failed: int = 0

var saved_characters: Array = []
var saved_businesses: Array = []
var saved_day: int
var saved_month: int
var saved_year: int


func _ready() -> void:
	print("")
	print("========================================")
	print("Family Member candidate tests starting")
	print("========================================")

	_save_state()
	_run_tests()
	_restore_state()

	print("")
	print("========================================")
	print(
		"Family Member candidate tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print("ALL FAMILY MEMBER CANDIDATE TESTS PASSED.")
	else:
		push_error(
			"Family Member candidate backend has %d failing test(s)."
			% failed
		)


func _save_state() -> void:
	saved_characters = CharacterManager.characters.duplicate(true)
	saved_businesses = BusinessManager.businesses.duplicate(true)

	saved_day = TimeManager.current_day
	saved_month = TimeManager.current_month
	saved_year = TimeManager.current_year


func _restore_state() -> void:
	CharacterManager.characters = saved_characters
	BusinessManager.businesses = saved_businesses

	TimeManager.current_day = saved_day
	TimeManager.current_month = saved_month
	TimeManager.current_year = saved_year


func _run_tests() -> void:
	_test_candidates_sorted_by_performance()
	_test_age_filters()
	_test_dead_character_is_excluded()
	_test_retired_character_is_excluded()
	_test_under_18_character_is_excluded()
	_test_assigned_family_member_is_excluded()
	_test_external_job_character_remains_candidate()


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


func _make_character(
	character_id: int,
	age: int,
	logic: int,
	health: int,
	is_alive: bool = true,
	is_retired: bool = false,
	job_id_value = null
) -> Dictionary:
	var birth_year: int = (
		TimeManager.current_year - age
	)

	var character: Dictionary = {
		"character_id": character_id,
		"first_name": "Family",
		"last_name": "Member%d" % character_id,
		"gender": "male",
		"birth_date": "%04d-01-01" % birth_year,
		"life_stage": CharacterManager.get_life_stage_from_age(age),
		"is_alive": is_alive,
		"is_retired": is_retired,
		"is_player_family": true,
		"job_id": job_id_value,
		"company_id": null,
		"salary": (
			5000
			if job_id_value != null
			else 0
		),
		"avatar_theme": "",
		"genetics": {
			"hair_color": "brown",
			"skin_tone": "light",
			"eye_color": "blue"
		},
		"health": health,
		"happiness": 50,
		"logic": logic,
		"attractiveness": 50,
		"social": 50,
		"confidence": 50,
		"discipline": 50,
		"creativity": 50
	}

	if job_id_value != null:
		character["company_id"] = 1001

	return character


func _make_hospital(
	assigned_character_id_value = null
) -> Dictionary:
	return {
		"business_instance_id": "business_test_001",
		"business_type_id": "hospital",
		"plot_id": "plot_test_001",
		"level": 1,
		"slots": [
			{
				"slot_id": "doctor_01",
				"assigned_character_id": assigned_character_id_value,
				"assigned_npc_id": null
			},
			{
				"slot_id": "nurse_01",
				"assigned_character_id": null,
				"assigned_npc_id": null
			},
			{
				"slot_id": "cleaner_01",
				"assigned_character_id": null,
				"assigned_npc_id": null
			}
		]
	}


func _reset_world() -> void:
	TimeManager.current_day = 1
	TimeManager.current_month = 1
	TimeManager.current_year = 1985

	CharacterManager.characters = []

	BusinessManager.businesses = [
		_make_hospital()
	]


func _test_candidates_sorted_by_performance() -> void:
	_reset_world()

	CharacterManager.characters = [
		_make_character(
			1,
			30,
			40,
			40
		),
		_make_character(
			2,
			30,
			90,
			90
		),
		_make_character(
			3,
			30,
			70,
			70
		)
	]

	var candidates: Array = (
		BusinessManager.get_family_candidates_for_slot(
			"hospital",
			"doctor_01"
		)
	)

	var valid: bool = candidates.size() == 3

	if valid:
		valid = (
			int(candidates[0].get("character_id", 0)) == 2
			and int(candidates[1].get("character_id", 0)) == 3
			and int(candidates[2].get("character_id", 0)) == 1
		)

	_assert_true(
		valid,
		"Family candidates are sorted from highest to lowest slot performance"
	)


func _test_age_filters() -> void:
	_reset_world()

	CharacterManager.characters = [
		_make_character(
			1,
			30,
			60,
			60
		),
		_make_character(
			2,
			45,
			60,
			60
		),
		_make_character(
			3,
			62,
			60,
			60
		)
	]

	var all_candidates: Array = (
		BusinessManager.get_family_candidates_for_slot(
			"hospital",
			"doctor_01",
			"all"
		)
	)

	var young_adults: Array = (
		BusinessManager.get_family_candidates_for_slot(
			"hospital",
			"doctor_01",
			"young_adult"
		)
	)

	var adults: Array = (
		BusinessManager.get_family_candidates_for_slot(
			"hospital",
			"doctor_01",
			"adult"
		)
	)

	var elders: Array = (
		BusinessManager.get_family_candidates_for_slot(
			"hospital",
			"doctor_01",
			"elder"
		)
	)

	_assert_true(
		all_candidates.size() == 3
		and young_adults.size() == 1
		and adults.size() == 1
		and elders.size() == 1,
		"All / Young Adult / Adult / Elder family filters work correctly"
	)


func _test_dead_character_is_excluded() -> void:
	_reset_world()

	CharacterManager.characters = [
		_make_character(
			1,
			30,
			90,
			90,
			false,
			false
		),
		_make_character(
			2,
			30,
			70,
			70
		)
	]

	var candidates: Array = (
		BusinessManager.get_family_candidates_for_slot(
			"hospital",
			"doctor_01"
		)
	)

	_assert_true(
		candidates.size() == 1
		and int(
			candidates[0].get(
				"character_id",
				0
			)
		) == 2,
		"Dead family characters are excluded from candidate list"
	)


func _test_retired_character_is_excluded() -> void:
	_reset_world()

	CharacterManager.characters = [
		_make_character(
			1,
			64,
			90,
			90,
			true,
			false
		),
		_make_character(
			2,
			65,
			90,
			90,
			true,
			true
		)
	]

	var candidates: Array = (
		BusinessManager.get_family_candidates_for_slot(
			"hospital",
			"doctor_01"
		)
	)

	_assert_true(
		candidates.size() == 1
		and int(
			candidates[0].get(
				"character_id",
				0
			)
		) == 1,
		"65+ retired family characters are excluded while age 64 remains eligible"
	)


func _test_under_18_character_is_excluded() -> void:
	_reset_world()

	CharacterManager.characters = [
		_make_character(
			1,
			17,
			90,
			90
		),
		_make_character(
			2,
			18,
			70,
			70
		)
	]

	var candidates: Array = (
		BusinessManager.get_family_candidates_for_slot(
			"hospital",
			"doctor_01"
		)
	)

	_assert_true(
		candidates.size() == 1
		and int(
			candidates[0].get(
				"character_id",
				0
			)
		) == 2,
		"Family characters under age 18 are excluded"
	)


func _test_assigned_family_member_is_excluded() -> void:
	_reset_world()

	CharacterManager.characters = [
		_make_character(
			1,
			30,
			90,
			90
		),
		_make_character(
			2,
			30,
			70,
			70
		)
	]

	BusinessManager.businesses = [
		_make_hospital(
			1
		)
	]

	var candidates: Array = (
		BusinessManager.get_family_candidates_for_slot(
			"hospital",
			"nurse_01"
		)
	)

	_assert_true(
		candidates.size() == 1
		and int(
			candidates[0].get(
				"character_id",
				0
			)
		) == 2,
		"Family member already assigned to another family-business slot is excluded"
	)


func _test_external_job_character_remains_candidate() -> void:
	_reset_world()

	CharacterManager.characters = [
		_make_character(
			1,
			30,
			90,
			90,
			true,
			false,
			2001
		)
	]

	var candidates: Array = (
		BusinessManager.get_family_candidates_for_slot(
			"hospital",
			"doctor_01"
		)
	)

	_assert_true(
		candidates.size() == 1
		and bool(
			candidates[0].get(
				"has_external_job",
				false
			)
		),
		"Family member with an external job remains selectable for family business"
	)
