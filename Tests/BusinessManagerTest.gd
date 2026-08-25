extends Node


const APPROVED_BUSINESS_TYPE_IDS := [
	"cafe",
	"gym",
	"restaurant",
	"warehouse",
	"factory",
	"hospital",
	"tech_company",
	"bank",
	"stadium",
	"auto_service",
	"cruise",
	"hotel"
]


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
	_test_business_type_schema_integrity()
	_test_hospital_level_1_definition()
	_test_hospital_level_5_definition()
	_test_required_stats_are_enforced()
	_test_performance_tiers_and_gross()
	_test_static_visual_resolvers()
	_test_map_property_uses_map_visual_resolver()
	_test_new_business_type_lifecycles()
	_test_cruise_costs_and_expenses_exceed_stadium()

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
	var roster_is_complete := true
	var actual_ids: Array[String] = []
	var seen_ids: Dictionary = {}
	var has_duplicate := false

	for business_type_value in BusinessManager.business_types:
		if not business_type_value is Dictionary:
			roster_is_complete = false
			continue
		var business_type: Dictionary = business_type_value
		var business_type_id := str(business_type.get("business_type_id", ""))
		actual_ids.append(business_type_id)
		if seen_ids.has(business_type_id):
			has_duplicate = true
		seen_ids[business_type_id] = true

	for business_type_id in APPROVED_BUSINESS_TYPE_IDS:
		if BusinessManager.get_business_type_by_id(business_type_id).is_empty():
			roster_is_complete = false
			break
		if not actual_ids.has(business_type_id):
			roster_is_complete = false
			break

	_assert_true(
		BusinessManager.business_types.size() == 12
		and roster_is_complete
		and not has_duplicate
		and BusinessManager.get_business_type_by_id("bookshop").is_empty()
		and not hospital.is_empty()
		and str(
			hospital.get(
				"display_name",
				""
			)
		) == "Hospital",
		"Approved 12-type roster loads, Bookshop is absent, and Hospital resolves"
	)


func _test_business_type_schema_integrity() -> void:
	var schema_is_valid := true

	for business_type_value in BusinessManager.business_types:
		if not business_type_value is Dictionary:
			schema_is_valid = false
			continue

		var business_type: Dictionary = business_type_value
		var slot_definitions_value = business_type.get("slot_definitions", [])
		var levels_value = business_type.get("levels", [])
		if (
			int(business_type.get("max_level", 0)) != 5
			or not slot_definitions_value is Array
			or not levels_value is Array
			or levels_value.size() != 5
			or str(business_type.get("map_visual_path", "")).is_empty()
			or str(business_type.get("modal_visual_path", "")).is_empty()
			or business_type.has("building_folder")
			or business_type.has("visual_variants")
			or business_type.has("placeholder_visual_path")
		):
			schema_is_valid = false
			continue

		var slot_ids: Dictionary = {}
		for slot_definition_value in slot_definitions_value:
			if not slot_definition_value is Dictionary:
				schema_is_valid = false
				continue
			var slot_definition: Dictionary = slot_definition_value
			var slot_id := str(slot_definition.get("slot_id", ""))
			if slot_id.is_empty() or slot_ids.has(slot_id):
				schema_is_valid = false
			slot_ids[slot_id] = true

		var level_numbers: Dictionary = {}
		for level_value in levels_value:
			if not level_value is Dictionary:
				schema_is_valid = false
				continue
			var level_definition: Dictionary = level_value
			var level := int(level_definition.get("level", 0))
			var level_slot_ids_value = level_definition.get("slot_ids", [])
			if (
				level < 1
				or level > 5
				or level_numbers.has(level)
				or int(level_definition.get("cost", 0)) <= 0
				or int(level_definition.get("fixed_monthly_expense", 0)) <= 0
				or not level_slot_ids_value is Array
				or (level == 1 and level_slot_ids_value.is_empty())
			):
				schema_is_valid = false
			level_numbers[level] = true

			for slot_id_value in level_slot_ids_value:
				if not slot_ids.has(str(slot_id_value)):
					schema_is_valid = false

		for expected_level in range(1, 6):
			if not level_numbers.has(expected_level):
				schema_is_valid = false

	_assert_true(
		schema_is_valid,
		"All 12 business types have valid five-level slot/economy data and only the new visual schema"
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
		"Required stats are performance references; only missing stat data blocks assignment"
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


func _test_static_visual_resolvers() -> void:
	var hospital := BusinessManager.get_business_type_by_id(
		"hospital"
	)
	var expected_map_path := str(hospital.get("map_visual_path", ""))
	var expected_modal_path := str(hospital.get("modal_visual_path", ""))
	var map_path := BusinessManager.get_business_map_visual_path("hospital")
	var modal_path := BusinessManager.get_business_modal_visual_path("hospital")

	_assert_true(
		not expected_map_path.is_empty()
		and not expected_modal_path.is_empty()
		and map_path == expected_map_path
		and modal_path == expected_modal_path
		and map_path != modal_path
		and BusinessManager.get_business_map_visual_path("missing").is_empty()
		and BusinessManager.get_business_modal_visual_path("missing").is_empty(),
		"Map and modal visual resolvers return their independent static JSON paths"
	)


func _test_map_property_uses_map_visual_resolver() -> void:
	var map_property := MapProperty.new()
	map_property.property_data = {
		"category": "family_business",
		"business_type_id": "hotel",
		"visual_path": "res://incorrect_map_fallback.png"
	}
	var actual_path := str(map_property.call("_resolve_visual_path"))
	map_property.free()

	_assert_true(
		actual_path == BusinessManager.get_business_map_visual_path("hotel"),
		"Family-business map properties resolve the map-specific BusinessTypes path"
	)


func _test_new_business_type_lifecycles() -> void:
	var lifecycle_is_valid := true
	var type_index := 0

	for business_type_id in ["auto_service", "hotel", "cruise"]:
		BusinessManager.businesses = []
		BusinessManager.next_business_instance_number = 1
		GameManager.set_family_money(100000000)

		var business_type := BusinessManager.get_business_type_by_id(business_type_id)
		if business_type.is_empty() or business_type.has("configuration_status"):
			lifecycle_is_valid = false
			continue

		var existing := BusinessManager.create_business_instance(
			business_type_id,
			"plot_existing_%d" % type_index,
			false
		)
		if (
			existing.is_empty()
			or existing.has("visual_variant_id")
			or int(existing.get("level", 0)) != 1
			or str(existing.get("plot_id", "")) != "plot_existing_%d" % type_index
			or existing.get("slots", []).size()
				!= BusinessManager.get_level_definition(business_type_id, 1).get("slot_ids", []).size()
		):
			lifecycle_is_valid = false
			continue

		var existing_id := str(existing.get("business_instance_id", ""))
		var map_path_at_level_one := (
			BusinessManager.get_business_map_visual_path(business_type_id)
		)
		for next_level in range(2, 6):
			if not BusinessManager.upgrade_business(existing_id):
				lifecycle_is_valid = false
				break
			if (
				int(existing.get("level", 0)) != next_level
				or existing.get("slots", []).size()
					!= BusinessManager.get_level_definition(
						business_type_id,
						next_level
					).get("slot_ids", []).size()
			):
				lifecycle_is_valid = false

		if (
			BusinessManager.get_business_map_visual_path(business_type_id)
			!= map_path_at_level_one
		):
			lifecycle_is_valid = false

		var constructed := BusinessManager.create_business_instance(
			business_type_id,
			"plot_constructed_%d" % type_index,
			true
		)
		if (
			constructed.is_empty()
			or int(constructed.get("level", 0)) != 1
			or constructed.has("visual_variant_id")
		):
			lifecycle_is_valid = false

		type_index += 1

	_assert_true(
		lifecycle_is_valid,
		"Auto Service, Hotel, and Cruise support generic purchase, construction, Lv1 creation, Lv2-Lv5 upgrades, and slot progression"
	)


func _test_cruise_costs_and_expenses_exceed_stadium() -> void:
	var cruise_exceeds_stadium := true

	for level in range(1, 6):
		var cruise_level := BusinessManager.get_level_definition("cruise", level)
		var stadium_level := BusinessManager.get_level_definition("stadium", level)
		if (
			int(cruise_level.get("cost", 0))
				<= int(stadium_level.get("cost", 0))
			or int(cruise_level.get("fixed_monthly_expense", 0))
				<= int(stadium_level.get("fixed_monthly_expense", 0))
		):
			cruise_exceeds_stadium = false

	_assert_true(
		cruise_exceeds_stadium,
		"Cruise cost and fixed monthly expense exceed Stadium at every level"
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
		and not created.has("visual_variant_id")
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
		"cafe",
		"plot_shared_001",
		false
	)

	var money_after_first := GameManager.family_money

	var second := BusinessManager.create_business_instance(
		"restaurant",
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
		"cafe",
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
