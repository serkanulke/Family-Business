extends Node


var passed := 0
var failed := 0

var saved_characters: Array = []
var saved_businesses: Array = []
var saved_family_money := 0
var saved_date := Vector3i.ZERO
var saved_last_business_payment_date := ""
var saved_last_business_breakdown: Array = []


func _ready() -> void:
	print("")
	print("========================================")
	print("Business monthly economy tests starting")
	print("========================================")

	_save_state()
	_run_all_tests()
	_restore_state()

	print("")
	print("========================================")
	print(
		"Business economy tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print("ALL BUSINESS ECONOMY TESTS PASSED.")
	else:
		push_error(
			"Business economy has %d failing test(s)."
			% failed
		)


func _run_all_tests() -> void:
	_test_empty_slots_produce_zero_gross()
	_test_s_tier_hospital_lv1_gross()
	_test_partial_staffing_breakdown()
	_test_positive_monthly_settlement_adds_net_profit()
	_test_negative_monthly_settlement_deducts_loss()
	_test_settlement_only_runs_on_first_day()
	_test_duplicate_same_day_settlement_is_blocked()
	_test_monthly_totals_match_business_breakdown()


func _save_state() -> void:
	saved_characters = CharacterManager.characters.duplicate(true)
	saved_businesses = BusinessManager.businesses.duplicate(true)
	saved_family_money = GameManager.family_money

	saved_date = Vector3i(
		TimeManager.current_day,
		TimeManager.current_month,
		TimeManager.current_year
	)

	saved_last_business_payment_date = (
		EconomyManager.last_family_business_payment_date
	)

	saved_last_business_breakdown = (
		EconomyManager.last_family_business_breakdown.duplicate(true)
	)


func _restore_state() -> void:
	CharacterManager.characters = saved_characters
	BusinessManager.businesses = saved_businesses
	GameManager.set_family_money(saved_family_money)

	TimeManager.current_day = saved_date.x
	TimeManager.current_month = saved_date.y
	TimeManager.current_year = saved_date.z

	EconomyManager.last_family_business_payment_date = (
		saved_last_business_payment_date
	)

	EconomyManager.last_family_business_breakdown = (
		saved_last_business_breakdown
	)


func _reset_world() -> void:
	CharacterManager.characters = []

	BusinessManager.businesses = [
		{
			"business_instance_id": "business_test_hospital",
			"business_type_id": "hospital",
			"visual_variant_id": "",
			"plot_id": "plot_test_001",
			"level": 1,
			"slots": [
				{
					"slot_id": "doctor_01",
					"assigned_character_id": null
				},
				{
					"slot_id": "nurse_01",
					"assigned_character_id": null
				},
				{
					"slot_id": "cleaner_01",
					"assigned_character_id": null
				}
			]
		}
	]

	GameManager.set_family_money(100000)

	TimeManager.current_day = 1
	TimeManager.current_month = 4
	TimeManager.current_year = 1985

	EconomyManager.last_family_business_payment_date = ""
	EconomyManager.last_family_business_breakdown = []


func _make_s_tier_character(
	character_id: int
) -> Dictionary:
	var character := {
		"character_id": character_id,
		"first_name": "Economy Test",
		"is_alive": true,
		"is_player_family": true,
		"is_retired": false,

		"logic": 90,
		"health": 90,
		"attractiveness": 90,
		"social": 90,
		"confidence": 90,
		"discipline": 90,
		"creativity": 90,
		"happiness": 90,

		"job_id": null,
		"company_id": null,
		"salary": 0
	}

	CharacterManager.characters.append(
		character
	)

	return character


func _assign_directly(
	slot_id: String,
	character_id: int
) -> void:
	var slot := BusinessManager.get_slot(
		"business_test_hospital",
		slot_id
	)

	slot["assigned_character_id"] = character_id


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


func _test_empty_slots_produce_zero_gross() -> void:
	_reset_world()

	var gross := BusinessManager.get_business_gross_income(
		"business_test_hospital"
	)

	var breakdown := BusinessManager.get_business_monthly_breakdown(
		"business_test_hospital"
	)

	_assert_true(
		gross == 0
		and int(
			breakdown.get(
				"fixed_expense",
				0
			)
		) == 6800
		and int(
			breakdown.get(
				"net_profit",
				0
			)
		) == -6800,
		"Empty Hospital slots produce zero gross while fixed expense remains 6800"
	)


func _test_s_tier_hospital_lv1_gross() -> void:
	_reset_world()

	_make_s_tier_character(1)
	_make_s_tier_character(2)
	_make_s_tier_character(3)

	_assign_directly("doctor_01", 1)
	_assign_directly("nurse_01", 2)
	_assign_directly("cleaner_01", 3)

	var gross := BusinessManager.get_business_gross_income(
		"business_test_hospital"
	)

	_assert_true(
		gross == 17000,
		"Fully staffed S-tier Hospital Lv1 produces 17000 gross"
	)


func _test_partial_staffing_breakdown() -> void:
	_reset_world()

	_make_s_tier_character(1)
	_assign_directly("doctor_01", 1)

	var breakdown := BusinessManager.get_business_monthly_breakdown(
		"business_test_hospital"
	)

	_assert_true(
		int(
			breakdown.get(
				"gross_income",
				0
			)
		) == 8000
		and int(
			breakdown.get(
				"fixed_expense",
				0
			)
		) == 6800
		and int(
			breakdown.get(
				"net_profit",
				0
			)
		) == 1200,
		"Partially staffed Hospital calculates gross, expense and net correctly"
	)


func _test_positive_monthly_settlement_adds_net_profit() -> void:
	_reset_world()

	_make_s_tier_character(1)
	_make_s_tier_character(2)
	_make_s_tier_character(3)

	_assign_directly("doctor_01", 1)
	_assign_directly("nurse_01", 2)
	_assign_directly("cleaner_01", 3)

	GameManager.set_family_money(50000)

	var settled := EconomyManager.settle_family_businesses()

	_assert_true(
		settled
		and GameManager.family_money == 60200
		and EconomyManager.last_family_business_payment_date
			== "1985-04-01"
		and EconomyManager.last_family_business_breakdown.size()
			== 1,
		"Positive monthly business net profit is added to family balance on day 1"
	)


func _test_negative_monthly_settlement_deducts_loss() -> void:
	_reset_world()

	GameManager.set_family_money(10000)

	var settled := EconomyManager.settle_family_businesses()

	_assert_true(
		settled
		and GameManager.family_money == 3200
		and EconomyManager.last_family_business_payment_date
			== "1985-04-01",
		"Negative monthly business result deducts the fixed loss from family balance"
	)


func _test_settlement_only_runs_on_first_day() -> void:
	_reset_world()

	TimeManager.current_day = 2
	GameManager.set_family_money(10000)

	var settled := EconomyManager.settle_family_businesses()

	_assert_true(
		not settled
		and GameManager.family_money == 10000
		and EconomyManager.last_family_business_payment_date.is_empty(),
		"Family-business settlement only runs on the first day of the month"
	)


func _test_duplicate_same_day_settlement_is_blocked() -> void:
	_reset_world()

	_make_s_tier_character(1)
	_assign_directly("doctor_01", 1)

	GameManager.set_family_money(10000)

	var first_settlement := EconomyManager.settle_family_businesses()
	var money_after_first := GameManager.family_money

	var second_settlement := EconomyManager.settle_family_businesses()

	_assert_true(
		first_settlement
		and not second_settlement
		and money_after_first == 11200
		and GameManager.family_money == money_after_first,
		"Same-day duplicate family-business settlement is blocked"
	)


func _test_monthly_totals_match_business_breakdown() -> void:
	_reset_world()

	_make_s_tier_character(1)
	_assign_directly("doctor_01", 1)

	var totals := EconomyManager.get_family_business_monthly_totals()

	_assert_true(
		int(
			totals.get(
				"gross_income",
				0
			)
		) == 8000
		and int(
			totals.get(
				"fixed_expense",
				0
			)
		) == 6800
		and int(
			totals.get(
				"net_profit",
				0
			)
		) == 1200
		and int(
			totals.get(
				"business_count",
				0
			)
		) == 1,
		"EconomyManager monthly totals match per-business breakdown values"
	)
