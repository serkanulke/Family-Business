extends Node


var passed := 0
var failed := 0

var saved_characters: Array = []
var saved_businesses: Array = []
var saved_active_offers: Dictionary = {}
var saved_date := Vector3i.ZERO
var saved_paused := false


func _ready() -> void:
	print("")
	print("========================================")
	print("BusinessManager backend tests starting")
	print("========================================")

	_save_state()
	_run_all_tests()
	_restore_state()

	print("")
	print("========================================")
	print(
		"Business tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print("ALL BUSINESS TESTS PASSED.")
	else:
		push_error(
			"Business backend has %d failing test(s)."
			% failed
		)


func _run_all_tests() -> void:
	_test_external_employee_moves_to_family_business()
	_test_pending_offer_is_removed_on_assignment()
	_test_family_business_employee_is_excluded_from_external_systems()
	_test_removed_character_returns_to_job_offer_pool()
	_test_same_character_cannot_fill_two_slots()
	_test_occupied_slot_rejects_second_character()


func _save_state() -> void:
	saved_characters = CharacterManager.characters.duplicate(true)
	saved_businesses = BusinessManager.businesses.duplicate(true)
	saved_active_offers = CareerManager.active_job_offers.duplicate(true)
	saved_date = Vector3i(
		TimeManager.current_day,
		TimeManager.current_month,
		TimeManager.current_year
	)
	saved_paused = TimeManager.is_paused


func _restore_state() -> void:
	CharacterManager.characters = saved_characters
	BusinessManager.businesses = saved_businesses
	CareerManager.active_job_offers = saved_active_offers

	TimeManager.current_day = saved_date.x
	TimeManager.current_month = saved_date.y
	TimeManager.current_year = saved_date.z
	TimeManager.is_paused = saved_paused


func _reset_world() -> void:
	CharacterManager.characters = []
	CareerManager.active_job_offers.clear()

	BusinessManager.businesses = [
		{
			"business_instance_id": "test_business_001",
			"slots": [
				{
					"slot_id": "slot_01",
					"assigned_character_id": null
				},
				{
					"slot_id": "slot_02",
					"assigned_character_id": null
				}
			]
		}
	]

	TimeManager.current_day = 15
	TimeManager.current_month = 3
	TimeManager.current_year = 1985
	TimeManager.is_paused = true


func _make_character(
	character_id: int
) -> Dictionary:
	var character := {
		"character_id": character_id,
		"first_name": "Business Test",
		"is_alive": true,
		"is_player_family": true,
		"is_retired": false,

		"education_status": "graduated",
		"major_id": 5014,

		"logic": 100,
		"social": 100,
		"confidence": 100,
		"discipline": 100,
		"creativity": 100,
		"health": 100,
		"happiness": 100,
		"attractiveness": 100,

		"job_id": 2076,
		"company_id": "central_city_administration",
		"salary": 5600,

		"unemployment_start_date": null,
		"job_offer_cooldown_until": null
	}

	CharacterManager.characters.append(
		character
	)

	return character


func _assert_true(
	condition: bool,
	test_name: String
) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error(
			"[FAIL] " + test_name
		)


func _test_external_employee_moves_to_family_business() -> void:
	_reset_world()

	var character := _make_character(1)

	var assigned := BusinessManager.assign_character_to_slot(
		"test_business_001",
		"slot_01",
		1
	)

	var slot := BusinessManager.get_slot(
		"test_business_001",
		"slot_01"
	)

	_assert_true(
		assigned
		and int(
			slot.get(
				"assigned_character_id",
				0
			)
		) == 1
		and character.get(
			"job_id",
			null
		) == null
		and character.get(
			"company_id",
			null
		) == null
		and int(
			character.get(
				"salary",
				-1
			)
		) == 0,
		"External employee moves to family business and external employment is cleared"
	)


func _test_pending_offer_is_removed_on_assignment() -> void:
	_reset_world()

	_make_character(1)

	CareerManager.active_job_offers[1] = {
		"job_id": 2069,
		"company_id": "titan_global_holdings",
		"salary": 25000
	}

	BusinessManager.assign_character_to_slot(
		"test_business_001",
		"slot_01",
		1
	)

	_assert_true(
		not CareerManager.active_job_offers.has(
			1
		),
		"Pending external offer is removed when character joins family business"
	)


func _test_family_business_employee_is_excluded_from_external_systems() -> void:
	_reset_world()

	var character := _make_character(1)

	BusinessManager.assign_character_to_slot(
		"test_business_001",
		"slot_01",
		1
	)

	_assert_true(
		BusinessManager.is_character_assigned(
			1
		)
		and CareerManager.get_unemployed_offer_pool(
			character
		).is_empty()
		and not EconomyManager.is_character_eligible_for_external_salary(
			character
		),
		"Family-business employee is excluded from external offers and external salary"
	)


func _test_removed_character_returns_to_job_offer_pool() -> void:
	_reset_world()

	var character := _make_character(1)

	BusinessManager.assign_character_to_slot(
		"test_business_001",
		"slot_01",
		1
	)

	var removed := BusinessManager.remove_character_from_slot(
		"test_business_001",
		"slot_01"
	)

	var offer_pool := CareerManager.get_unemployed_offer_pool(
		character
	)

	_assert_true(
		removed
		and not BusinessManager.is_character_assigned(
			1
		)
		and character.get(
			"job_id",
			null
		) == null
		and character.get(
			"company_id",
			null
		) == null
		and int(
			character.get(
				"salary",
				-1
			)
		) == 0
		and String(
			character.get(
				"unemployment_start_date",
				""
			)
		) == "1985-03-15"
		and character.get(
			"job_offer_cooldown_until",
			"invalid"
		) == null
		and not offer_pool.is_empty(),
		"Removed family-business employee becomes unemployed and returns to external job-offer pool"
	)


func _test_same_character_cannot_fill_two_slots() -> void:
	_reset_world()

	_make_character(1)

	var first_assignment := (
		BusinessManager.assign_character_to_slot(
			"test_business_001",
			"slot_01",
			1
		)
	)

	var second_assignment := (
		BusinessManager.assign_character_to_slot(
			"test_business_001",
			"slot_02",
			1
		)
	)

	_assert_true(
		first_assignment
		and not second_assignment,
		"One character cannot occupy two family-business slots"
	)


func _test_occupied_slot_rejects_second_character() -> void:
	_reset_world()

	_make_character(1)
	_make_character(2)

	var first_assignment := (
		BusinessManager.assign_character_to_slot(
			"test_business_001",
			"slot_01",
			1
		)
	)

	var second_assignment := (
		BusinessManager.assign_character_to_slot(
			"test_business_001",
			"slot_01",
			2
		)
	)

	var slot := BusinessManager.get_slot(
		"test_business_001",
		"slot_01"
	)

	_assert_true(
		first_assignment
		and not second_assignment
		and int(
			slot.get(
				"assigned_character_id",
				0
			)
		) == 1,
		"Occupied family-business slot rejects another character"
	)
