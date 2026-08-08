extends Node

var passed := 0
var failed := 0
var saved_characters: Array = []
var saved_money := 0
var saved_payment_date := ""
var saved_date := Vector3i.ZERO
var saved_paused := false
var signal_count := 0
var signal_total := 0
var signal_characters := 0
var signal_date := ""

func _ready() -> void:
    print("")
    print("========================================")
    print("EconomyManager salary tests starting")
    print("========================================")
    _save_state()
    if not EconomyManager.external_salaries_paid.is_connected(_on_external_salaries_paid):
        EconomyManager.external_salaries_paid.connect(_on_external_salaries_paid)
    _run_tests()
    _restore_state()
    print("")
    print("========================================")
    print("Economy salary tests: ", passed, " passed / ", failed, " failed")
    print("========================================")
    if failed == 0:
        print("ALL ECONOMY SALARY TESTS PASSED.")
    else:
        push_error("Economy salary backend has %d failing test(s)." % failed)

func _run_tests() -> void:
    _test_eligibility_filters()
    _test_total_and_count()
    _test_not_paid_before_first_day()
    _test_paid_on_first_day()
    _test_duplicate_same_day_blocked()
    _test_next_month_pays_again()
    _test_signal_payload()

func _save_state() -> void:
    saved_characters = CharacterManager.characters.duplicate(true)
    saved_money = GameManager.family_money
    saved_payment_date = EconomyManager.last_external_salary_payment_date
    saved_date = Vector3i(TimeManager.current_day, TimeManager.current_month, TimeManager.current_year)
    saved_paused = TimeManager.is_paused

func _restore_state() -> void:
    CharacterManager.characters = saved_characters
    GameManager.family_money = saved_money
    EconomyManager.last_external_salary_payment_date = saved_payment_date
    TimeManager.current_day = saved_date.x
    TimeManager.current_month = saved_date.y
    TimeManager.current_year = saved_date.z
    TimeManager.is_paused = saved_paused
    if EconomyManager.external_salaries_paid.is_connected(_on_external_salaries_paid):
        EconomyManager.external_salaries_paid.disconnect(_on_external_salaries_paid)

func _reset_world() -> void:
    CharacterManager.characters = []
    GameManager.family_money = 15000
    EconomyManager.last_external_salary_payment_date = ""
    TimeManager.current_day = 26
    TimeManager.current_month = 1
    TimeManager.current_year = 1985
    TimeManager.is_paused = true
    signal_count = 0
    signal_total = 0
    signal_characters = 0
    signal_date = ""

func _make_character(id: int, salary: int) -> Dictionary:
    var c := {
        "character_id": id,
        "first_name": "Economy Test %d" % id,
        "is_alive": true,
        "is_player_family": true,
        "is_retired": false,
        "job_id": 1001,
        "company_id": "metro_works_services",
        "salary": salary
    }
    CharacterManager.characters.append(c)
    return c

func _set_date(day: int, month: int, year: int) -> void:
    TimeManager.current_day = day
    TimeManager.current_month = month
    TimeManager.current_year = year

func _assert_true(condition: bool, name: String) -> void:
    if condition:
        passed += 1
        print("[PASS] ", name)
    else:
        failed += 1
        push_error("[FAIL] " + name)

func _test_eligibility_filters() -> void:
    _reset_world()
    var valid := _make_character(1, 1200)
    var dead := _make_character(2, 1200)
    dead["is_alive"] = false
    var retired := _make_character(3, 1200)
    retired["is_retired"] = true
    var non_family := _make_character(4, 1200)
    non_family["is_player_family"] = false
    var unemployed := _make_character(5, 0)
    unemployed["job_id"] = null
    unemployed["company_id"] = null
    var no_company := _make_character(6, 1200)
    no_company["company_id"] = null

    _assert_true(
        EconomyManager.is_character_eligible_for_external_salary(valid)
        and not EconomyManager.is_character_eligible_for_external_salary(dead)
        and not EconomyManager.is_character_eligible_for_external_salary(retired)
        and not EconomyManager.is_character_eligible_for_external_salary(non_family)
        and not EconomyManager.is_character_eligible_for_external_salary(unemployed)
        and not EconomyManager.is_character_eligible_for_external_salary(no_company),
        "Only valid playable external employees are salary-eligible"
    )

func _test_total_and_count() -> void:
    _reset_world()
    _make_character(1, 1200)
    _make_character(2, 5600)
    var retired := _make_character(3, 25000)
    retired["is_retired"] = true
    _assert_true(
        EconomyManager.get_external_salary_total() == 6800
        and EconomyManager.get_external_salary_character_count() == 2,
        "Salary total and employee count include only eligible characters"
    )

func _test_not_paid_before_first_day() -> void:
    _reset_world()
    _make_character(1, 1200)
    _set_date(28, 1, 1985)
    var paid := EconomyManager.pay_external_salaries()
    _assert_true(
        not paid
        and GameManager.family_money == 15000
        and EconomyManager.last_external_salary_payment_date == "",
        "Salaries are not paid before the first day"
    )

func _test_paid_on_first_day() -> void:
    _reset_world()
    _make_character(1, 1200)
    _make_character(2, 5600)
    _set_date(1, 2, 1985)
    var paid := EconomyManager.pay_external_salaries()
    _assert_true(
        paid
        and GameManager.family_money == 21800
        and EconomyManager.last_external_salary_payment_date == "1985-02-01",
        "Eligible salaries are paid into family money on the first day"
    )

func _test_duplicate_same_day_blocked() -> void:
    _reset_world()
    _make_character(1, 1200)
    _set_date(1, 2, 1985)
    var first_paid := EconomyManager.pay_external_salaries()
    var money_after_first := GameManager.family_money
    var second_paid := EconomyManager.pay_external_salaries()
    _assert_true(
        first_paid
        and not second_paid
        and money_after_first == 16200
        and GameManager.family_money == 16200,
        "Same-day duplicate salary payment is blocked"
    )

func _test_next_month_pays_again() -> void:
    _reset_world()
    _make_character(1, 1200)
    _set_date(1, 2, 1985)
    var first_paid := EconomyManager.pay_external_salaries()
    _set_date(1, 3, 1985)
    var second_paid := EconomyManager.pay_external_salaries()
    _assert_true(
        first_paid
        and second_paid
        and GameManager.family_money == 17400
        and EconomyManager.last_external_salary_payment_date == "1985-03-01",
        "Next month allows another salary payment"
    )

func _test_signal_payload() -> void:
    _reset_world()
    _make_character(1, 1200)
    _make_character(2, 5600)
    _set_date(1, 2, 1985)
    EconomyManager.pay_external_salaries()
    _assert_true(
        signal_count == 1
        and signal_total == 6800
        and signal_characters == 2
        and signal_date == "1985-02-01",
        "Salary signal reports total, character count and date"
    )

func _on_external_salaries_paid(
    total_amount: int,
    character_count: int,
    payment_date: String
) -> void:
    signal_count += 1
    signal_total = total_amount
    signal_characters = character_count
    signal_date = payment_date
