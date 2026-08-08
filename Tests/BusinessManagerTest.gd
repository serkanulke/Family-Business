extends Node


var passed := 0
var failed := 0

var saved_characters: Array = []
var saved_businesses: Array = []
var saved_active_offers: Dictionary = {}
var saved_date := Vector3i.ZERO
var saved_paused := false
var saved_family_money := 0
var saved_next_business_instance_number := 1


func _ready() -> void:
	print("")
	print("========================================")
	print("BusinessManager static + backend tests starting")
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
	_test_business_types_loaded()
	_test_hospital_level_1_definition()
	_test_hospital_level_5_definition()
	_test_required_stats_are_enforced()
	_test_performance_tiers_and_gross()
	_test_missing_visual_uses_placeholder()

	_test_existing_building_uses_lv1_cost()
	_test_new_construction_uses_1_4_multiplier()
	_test_create_existing_business_instance()
	_test_create_new_construction_instance()
	_test_insufficient_money_blocks_purchase()
	_test_occupied_plot_blocks_second_business()
	_test_upgrade_cost_and_level()
	_test_upgrade_preserves_existing_worker_and_adds_new_slot()
	_test_max_level_blocks_further_upgrade()

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
	saved_family_money = GameManager.family_money
	saved_next_business_instance_number = (
		BusinessManager.next_business_instance_number
	)

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
	GameManager.set_family_money(saved_family_money)
	BusinessManager.next_business_instance_number = (
		saved_next_business_instance_number
	)

	TimeManager.current_day = saved_date.x
	TimeManager.current_month = saved_date.y
	TimeManager.current_year = saved_date.z
	TimeManager.is_paused = saved_paused


func _reset_world() -> void:
	CharacterManager.characters = []
	CareerManager.active_job_offers.clear()
	GameManager.set_family_money(10000000)
	BusinessManager.next_business_instance_number = 1

	BusinessManager.businesses = [
		{
			"business_instance_id": "test_business_001",
			"business_type_id": "hospital",
			"level": 1,
			"visual_variant_id": "",
			"plot_id": "test_plot_001",
			"slots": [
				{
					"slot_id": "doctor_01",
					"assigned_character_id": null
				},
				{
					"slot_id": "nurse_01",
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
		"health": 100,
		"attractiveness": 100,
		"social": 100,
		"confidence": 100,
		"discipline": 100,
		"creativity": 100,
		"happiness": 100,

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


func _make_nurse_worker(
	score: int
) -> Dictionary:
	return {
		"health": score,
		"social": score,
		"discipline": score
	}


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


func _test_business_types_loaded() -> void:
	var hospital := BusinessManager.get_business_type_by_id(
		"hospital"
	)

	_assert_true(
		BusinessManager.business_types.size() == 10
		and not hospital.is_empty()
		and str(
			hospital.get(
				"display_name",
				""
			)
		) == "Hospital",
		"10 business types load and Hospital can be resolved"
	)


func _test_hospital_level_1_definition() -> void:
	var level_definition := BusinessManager.get_level_definition(
		"hospital",
		1
	)

	var slot_definitions := BusinessManager.get_level_slot_definitions(
		"hospital",
		1
	)

	_assert_true(
		not level_definition.is_empty()
		and int(
			level_definition.get(
				"cost",
				0
			)
		) == 120000
		and int(
			level_definition.get(
				"fixed_monthly_expense",
				0
			)
		) == 6800
		and slot_definitions.size() == 3
		and BusinessManager.get_level_max_gross(
			"hospital",
			1
		) == 17000,
		"Hospital Lv1 cost, expense, slots and max gross match BusinessTypes.json"
	)


func _test_hospital_level_5_definition() -> void:
	var level_definition := BusinessManager.get_level_definition(
		"hospital",
		5
	)

	var slot_definitions := BusinessManager.get_level_slot_definitions(
		"hospital",
		5
	)

	_assert_true(
		not level_definition.is_empty()
		and int(
			level_definition.get(
				"cost",
				0
			)
		) == 390000
		and int(
			level_definition.get(
				"fixed_monthly_expense",
				0
			)
		) == 29200
		and slot_definitions.size() == 8
		and BusinessManager.get_level_max_gross(
			"hospital",
			5
		) == 73000,
		"Hospital Lv5 cost, expense, slots and max gross match BusinessTypes.json"
	)


func _test_required_stats_are_enforced() -> void:
	var nurse_slot := BusinessManager.get_slot_definition(
		"hospital",
		"nurse_01"
	)

	var valid_worker := {
		"health": 45,
		"social": 45,
		"discipline": 40
	}

	var invalid_worker := {
		"health": 44,
		"social": 100,
		"discipline": 100
	}

	_assert_true(
		BusinessManager.worker_meets_slot_requirements(
			valid_worker,
			nurse_slot
		)
		and not BusinessManager.worker_meets_slot_requirements(
			invalid_worker,
			nurse_slot
		),
		"Worker must meet every required stat for the selected business slot"
	)


func _test_performance_tiers_and_gross() -> void:
	var nurse_slot := BusinessManager.get_slot_definition(
		"hospital",
		"nurse_01"
	)

	var s_result := BusinessManager.get_worker_slot_performance(
		_make_nurse_worker(90),
		nurse_slot
	)

	var a_result := BusinessManager.get_worker_slot_performance(
		_make_nurse_worker(80),
		nurse_slot
	)

	var b_result := BusinessManager.get_worker_slot_performance(
		_make_nurse_worker(70),
		nurse_slot
	)

	var c_result := BusinessManager.get_worker_slot_performance(
		_make_nurse_worker(55),
		nurse_slot
	)

	var d_result := BusinessManager.get_worker_slot_performance(
		_make_nurse_worker(45),
		nurse_slot
	)

	_assert_true(
		str(s_result.get("tier", "")) == "S"
		and is_equal_approx(
			float(s_result.get("multiplier", 0.0)),
			1.0
		)
		and BusinessManager.calculate_worker_slot_gross(
			_make_nurse_worker(90),
			nurse_slot
		) == 6000

		and str(a_result.get("tier", "")) == "A"
		and is_equal_approx(
			float(a_result.get("multiplier", 0.0)),
			0.85
		)
		and BusinessManager.calculate_worker_slot_gross(
			_make_nurse_worker(80),
			nurse_slot
		) == 5100

		and str(b_result.get("tier", "")) == "B"
		and is_equal_approx(
			float(b_result.get("multiplier", 0.0)),
			0.70
		)
		and BusinessManager.calculate_worker_slot_gross(
			_make_nurse_worker(70),
			nurse_slot
		) == 4200

		and str(c_result.get("tier", "")) == "C"
		and is_equal_approx(
			float(c_result.get("multiplier", 0.0)),
			0.55
		)
		and BusinessManager.calculate_worker_slot_gross(
			_make_nurse_worker(55),
			nurse_slot
		) == 3300

		and str(d_result.get("tier", "")) == "D"
		and is_equal_approx(
			float(d_result.get("multiplier", 0.0)),
			0.40
		)
		and BusinessManager.calculate_worker_slot_gross(
			_make_nurse_worker(45),
			nurse_slot
		) == 2400,
		"S/A/B/C/D tiers apply the correct gross contribution multipliers"
	)


func _test_missing_visual_uses_placeholder() -> void:
	var hospital := BusinessManager.get_business_type_by_id(
		"hospital"
	)

	var expected_placeholder := str(
		hospital.get(
			"placeholder_visual_path",
			""
		)
	)

	var actual_path := BusinessManager.get_business_visual_path(
		"hospital",
		"",
		3
	)

	_assert_true(
		not expected_placeholder.is_empty()
		and actual_path == expected_placeholder,
		"Missing business visual variant uses the configured placeholder path"
	)


func _test_existing_building_uses_lv1_cost() -> void:
	_reset_world()

	_assert_true(
		BusinessManager.get_business_acquisition_cost(
			"hospital",
			false
		) == 120000,
		"Existing Hospital uses the Lv1 base purchase cost"
	)


func _test_new_construction_uses_1_4_multiplier() -> void:
	_reset_world()

	_assert_true(
		is_equal_approx(
			EconomyManager.NEW_CONSTRUCTION_MULTIPLIER,
			1.40
		)
		and EconomyManager.get_new_construction_cost(
			120000
		) == 168000
		and BusinessManager.get_business_acquisition_cost(
			"hospital",
			true
		) == 168000,
		"New construction applies the shared 1.4 multiplier to Lv1 cost"
	)


func _test_create_existing_business_instance() -> void:
	_reset_world()
	BusinessManager.businesses = []
	GameManager.set_family_money(200000)

	var created := BusinessManager.create_business_instance(
		"hospital",
		"plot_existing_001",
		false
	)

	_assert_true(
		not created.is_empty()
		and str(
			created.get(
				"business_instance_id",
				""
			)
		) == "business_0001"
		and str(
			created.get(
				"business_type_id",
				""
			)
		) == "hospital"
		and str(
			created.get(
				"plot_id",
				""
			)
		) == "plot_existing_001"
		and int(
			created.get(
				"level",
				0
			)
		) == 1
		and created.get(
			"slots",
			[]
		).size() == 3
		and GameManager.family_money == 80000,
		"Existing Hospital purchase creates Lv1 instance and deducts 120000"
	)


func _test_create_new_construction_instance() -> void:
	_reset_world()
	BusinessManager.businesses = []
	GameManager.set_family_money(200000)

	var created := BusinessManager.create_business_instance(
		"hospital",
		"plot_empty_001",
		true
	)

	_assert_true(
		not created.is_empty()
		and GameManager.family_money == 32000
		and int(
			created.get(
				"level",
				0
			)
		) == 1
		and created.get(
			"slots",
			[]
		).size() == 3,
		"New Hospital construction creates Lv1 instance and deducts 168000"
	)


func _test_insufficient_money_blocks_purchase() -> void:
	_reset_world()
	BusinessManager.businesses = []
	GameManager.set_family_money(100000)

	var created := BusinessManager.create_business_instance(
		"hospital",
		"plot_empty_002",
		true
	)

	_assert_true(
		created.is_empty()
		and BusinessManager.businesses.is_empty()
		and GameManager.family_money == 100000,
		"Business purchase is blocked when family money is insufficient"
	)


func _test_occupied_plot_blocks_second_business() -> void:
	_reset_world()
	BusinessManager.businesses = []
	GameManager.set_family_money(500000)

	var first := BusinessManager.create_business_instance(
		"bookshop",
		"plot_shared_001",
		false
	)

	var money_after_first := GameManager.family_money

	var second := BusinessManager.create_business_instance(
		"cafe",
		"plot_shared_001",
		false
	)

	_assert_true(
		not first.is_empty()
		and second.is_empty()
		and BusinessManager.businesses.size() == 1
		and GameManager.family_money == money_after_first,
		"Occupied plot rejects a second family business without charging money"
	)


func _test_upgrade_cost_and_level() -> void:
	_reset_world()
	BusinessManager.businesses = []
	GameManager.set_family_money(500000)

	var created := BusinessManager.create_business_instance(
		"hospital",
		"plot_upgrade_001",
		false
	)

	var upgraded := BusinessManager.upgrade_business(
		str(
			created.get(
				"business_instance_id",
				""
			)
		)
	)

	_assert_true(
		upgraded
		and int(
			created.get(
				"level",
				0
			)
		) == 2
		and created.get(
			"slots",
			[]
		).size() == 4
		and GameManager.family_money == 230000,
		"Hospital Lv1 to Lv2 upgrade deducts 150000 and opens the Lv2 slot"
	)


func _test_upgrade_preserves_existing_worker_and_adds_new_slot() -> void:
	_reset_world()
	BusinessManager.businesses = []
	GameManager.set_family_money(500000)

	var created := BusinessManager.create_business_instance(
		"hospital",
		"plot_upgrade_002",
		false
	)

	var doctor_slot := BusinessManager.get_slot(
		str(
			created.get(
				"business_instance_id",
				""
			)
		),
		"doctor_01"
	)

	doctor_slot["assigned_character_id"] = 77

	var upgraded := BusinessManager.upgrade_business(
		str(
			created.get(
				"business_instance_id",
				""
			)
		)
	)

	var preserved_doctor := BusinessManager.get_slot(
		str(
			created.get(
				"business_instance_id",
				""
			)
		),
		"doctor_01"
	)

	var new_surgeon := BusinessManager.get_slot(
		str(
			created.get(
				"business_instance_id",
				""
			)
		),
		"surgeon_01"
	)

	_assert_true(
		upgraded
		and int(
			preserved_doctor.get(
				"assigned_character_id",
				0
			)
		) == 77
		and not new_surgeon.is_empty()
		and new_surgeon.get(
			"assigned_character_id",
			"invalid"
		) == null,
		"Upgrade preserves existing workers and adds newly unlocked slots empty"
	)


func _test_max_level_blocks_further_upgrade() -> void:
	_reset_world()
	BusinessManager.businesses = []
	GameManager.set_family_money(5000000)

	var created := BusinessManager.create_business_instance(
		"bookshop",
		"plot_max_001",
		false
	)

	var business_id := str(
		created.get(
			"business_instance_id",
			""
		)
	)

	var all_upgrades_succeeded := true

	for _step in range(4):
		if not BusinessManager.upgrade_business(
			business_id
		):
			all_upgrades_succeeded = false
			break

	var money_at_level_five := GameManager.family_money

	var sixth_level_attempt := (
		BusinessManager.upgrade_business(
			business_id
		)
	)

	_assert_true(
		all_upgrades_succeeded
		and int(
			created.get(
				"level",
				0
			)
		) == 5
		and not sixth_level_attempt
		and GameManager.family_money == money_at_level_five,
		"Max-level business rejects further upgrades without charging money"
	)


func _test_external_employee_moves_to_family_business() -> void:
	_reset_world()

	var character := _make_character(1)

	var assigned := BusinessManager.assign_character_to_slot(
		"test_business_001",
		"doctor_01",
		1
	)

	var slot := BusinessManager.get_slot(
		"test_business_001",
		"doctor_01"
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
		"doctor_01",
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
		"doctor_01",
		1
	)

	_assert_true(
		BusinessManager.is_character_assigned(
			1
		)
		and CareerManager.is_character_assigned_to_family_business(
			1
		)
		and not EconomyManager.is_character_eligible_for_external_salary(
			character
		),
		"Family-business employee is excluded from external offer checks and external salary"
	)


func _test_removed_character_returns_to_job_offer_pool() -> void:
	_reset_world()

	var character := _make_character(1)

	BusinessManager.assign_character_to_slot(
		"test_business_001",
		"doctor_01",
		1
	)

	var removed := BusinessManager.remove_character_from_slot(
		"test_business_001",
		"doctor_01"
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
		and str(
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
			"doctor_01",
			1
		)
	)

	var second_assignment := (
		BusinessManager.assign_character_to_slot(
			"test_business_001",
			"nurse_01",
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
			"doctor_01",
			1
		)
	)

	var second_assignment := (
		BusinessManager.assign_character_to_slot(
			"test_business_001",
			"doctor_01",
			2
		)
	)

	var slot := BusinessManager.get_slot(
		"test_business_001",
		"doctor_01"
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
