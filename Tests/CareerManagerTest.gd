extends Node

var passed := 0
var failed := 0
var saved_characters: Array = []
var saved_date := Vector3i.ZERO
var saved_paused := false
var last_offer: Dictionary = {}

func _ready() -> void:
    print("")
    print("========================================")
    print("CareerManager backend tests starting")
    print("========================================")

    saved_characters = CharacterManager.characters.duplicate(true)
    saved_date = Vector3i(TimeManager.current_day, TimeManager.current_month, TimeManager.current_year)
    saved_paused = TimeManager.is_paused

    if not CareerManager.job_offer_requested.is_connected(_on_job_offer_requested):
        CareerManager.job_offer_requested.connect(_on_job_offer_requested)

    _run_all_tests()

    CharacterManager.characters = saved_characters
    TimeManager.current_day = saved_date.x
    TimeManager.current_month = saved_date.y
    TimeManager.current_year = saved_date.z
    TimeManager.is_paused = saved_paused

    if CareerManager.job_offer_requested.is_connected(_on_job_offer_requested):
        CareerManager.job_offer_requested.disconnect(_on_job_offer_requested)

    print("")
    print("========================================")
    print("Career tests: ", passed, " passed / ", failed, " failed")
    print("========================================")
    if failed == 0:
        print("ALL CAREER TESTS PASSED.")
    else:
        push_error("Career backend has %d failing test(s)." % failed)

func _run_all_tests() -> void:
    _test_eligibility()
    _test_major_matching()
    _test_general_studies()
    _test_offer_pools()
    _test_unemployment_chances()
    _test_cooldown()
    _test_random_offer_pair()
    _test_signal_payload()
    _test_company_coverage()

func _reset_world() -> void:
    CharacterManager.characters = []
    _set_date(26, 1, 1985)
    TimeManager.is_paused = true
    last_offer = {}

func _set_date(day: int, month: int, year: int) -> void:
    TimeManager.current_day = day
    TimeManager.current_month = month
    TimeManager.current_year = year

func _make_graduate(major_id = 5014) -> Dictionary:
    var c := {
        "character_id": 1,
        "first_name": "Career Test",
        "gender": "female",
        "birth_date": "1960-01-01",
        "is_alive": true,
        "is_player_family": true,
        "is_retired": false,
        "health": 100,
        "happiness": 100,
        "logic": 100,
        "attractiveness": 100,
        "social": 100,
        "confidence": 100,
        "discipline": 100,
        "creativity": 100,
        "school_id": 4001,
        "major_id": major_id,
        "education_status": "graduated",
        "education_start_date": "1978-01-01",
        "major_selection_date": "1981-01-01",
        "expected_graduation_date": "1982-01-01",
        "graduation_date": "1982-01-01",
        "job_id": null,
        "company_id": null,
        "salary": 0,
        "last_salary": 0,
        "pension": 0,
        "unemployment_start_date": null,
        "job_offer_cooldown_until": null,
        "event_log": []
    }
    CharacterManager.characters.append(c)
    return c

func _assert_true(condition: bool, name: String) -> void:
    if condition:
        passed += 1
        print("[PASS] ", name)
    else:
        failed += 1
        push_error("[FAIL] " + name)

func _test_eligibility() -> void:
    _reset_world()
    var c := _make_graduate()
    _assert_true(
        CareerManager.is_character_eligible_for_external_jobs(c),
        "Graduated living family character is eligible"
    )

    c["is_alive"] = false
    _assert_true(
        not CareerManager.is_character_eligible_for_external_jobs(c),
        "Dead character is ineligible"
    )

    c["is_alive"] = true
    c["is_player_family"] = false
    _assert_true(
        not CareerManager.is_character_eligible_for_external_jobs(c),
        "Non-family character is ineligible"
    )

    c["is_player_family"] = true
    c["is_retired"] = true
    _assert_true(
        not CareerManager.is_character_eligible_for_external_jobs(c),
        "Retired character is ineligible"
    )

    c["is_retired"] = false
    c["education_status"] = "studying"
    _assert_true(
        not CareerManager.is_character_eligible_for_external_jobs(c),
        "Student is ineligible before graduation"
    )

func _test_major_matching() -> void:
    _reset_world()
    var c := _make_graduate(5014)
    var job := CareerManager.get_job_by_id(2076)
    var correct := CareerManager.character_meets_job_requirements(c, job)
    c["major_id"] = 5003
    var wrong := CareerManager.character_meets_job_requirements(c, job)
    _assert_true(correct and not wrong, "Major-specific job requires matching major")

func _test_general_studies() -> void:
    _reset_world()
    var c := _make_graduate(5016)
    var jobs := CareerManager.get_eligible_external_jobs(c)
    var has_general := false
    var has_specific := false

    for value in jobs:
        if typeof(value) != TYPE_DICTIONARY:
            continue
        if value.get("required_major_id", null) == null:
            has_general = true
        else:
            has_specific = true

    _assert_true(
        has_general and not has_specific,
        "General Studies unlocks general jobs only"
    )

func _test_offer_pools() -> void:
    _reset_world()
    var c := _make_graduate()
    var unemployed := CareerManager.get_unemployed_offer_pool(c)

    c["job_id"] = 2076
    c["company_id"] = "central_city_administration"
    c["salary"] = 5600

    var no_unemployed_pool := CareerManager.get_unemployed_offer_pool(c)
    var advancement := CareerManager.get_employed_advancement_offer_pool(c)
    var all_better := not advancement.is_empty()

    for value in advancement:
        if typeof(value) != TYPE_DICTIONARY:
            all_better = false
            continue
        if int(value.get("job_id", -1)) == 2076:
            all_better = false
        if int(value.get("salary", 0)) <= 5600:
            all_better = false

    _assert_true(
        not unemployed.is_empty() and no_unemployed_pool.is_empty(),
        "Unemployed pool is only for unemployed characters"
    )
    _assert_true(
        all_better,
        "Employed advancement pool contains only better jobs"
    )

func _test_unemployment_chances() -> void:
    _reset_world()
    var c := _make_graduate()
    c["graduation_date"] = "1985-01-01"
    c["unemployment_start_date"] = "1985-01-01"

    _set_date(30, 1, 1985)
    var a := CareerManager.get_unemployed_daily_offer_chance(c)
    _set_date(10, 2, 1985)
    var b := CareerManager.get_unemployed_daily_offer_chance(c)
    _set_date(15, 3, 1985)
    var d := CareerManager.get_unemployed_daily_offer_chance(c)
    _set_date(1, 5, 1985)
    var e := CareerManager.get_unemployed_daily_offer_chance(c)
    _set_date(1, 8, 1985)
    var f := CareerManager.get_unemployed_daily_offer_chance(c)

    _assert_true(
        is_equal_approx(a, 0.005)
        and is_equal_approx(b, 0.01)
        and is_equal_approx(d, 0.015)
        and is_equal_approx(e, 0.02)
        and is_equal_approx(f, 0.03),
        "Five unemployment chance brackets are correct"
    )

func _test_cooldown() -> void:
    _reset_world()
    var c := _make_graduate()
    _set_date(1, 1, 1985)

    CareerManager.start_unemployed_offer_cooldown(c)
    var date_ok := String(c.get("job_offer_cooldown_until", "")) == "1985-01-08"
    var start_blocked := CareerManager.is_unemployed_offer_on_cooldown(c)

    _set_date(8, 1, 1985)
    var day_seven_blocked := CareerManager.is_unemployed_offer_on_cooldown(c)

    _set_date(9, 1, 1985)
    var finished := not CareerManager.is_unemployed_offer_on_cooldown(c)

    _assert_true(
        date_ok and start_blocked and day_seven_blocked and finished,
        "Seven-day unemployed offer cooldown works"
    )

func _test_random_offer_pair() -> void:
    _reset_world()
    var c := _make_graduate()
    var pool := CareerManager.get_unemployed_offer_pool(c)
    var offer := CareerManager.select_random_offer_from_pool(pool)
    var job_id := int(offer.get("job_id", -1))
    var company_id := String(offer.get("company_id", ""))

    _assert_true(
        not offer.is_empty()
        and CareerManager.company_offers_job(company_id, job_id),
        "Random offer preserves a valid job-company pair"
    )

func _test_signal_payload() -> void:
    _reset_world()
    var c := _make_graduate()
    var pool := CareerManager.get_unemployed_offer_pool(c)

    if pool.is_empty():
        _assert_true(false, "Signal test has eligible offer data")
        return

    var offer: Dictionary = pool[0]
    CareerManager.request_job_offer(c, offer)

    _assert_true(
        int(last_offer.get("character_id", 0)) == 1
        and int(last_offer.get("job_id", -1)) == int(offer.get("job_id", -2))
        and String(last_offer.get("company_id", "")) == String(offer.get("company_id", ""))
        and int(last_offer.get("salary", -1)) == int(offer.get("salary", -2)),
        "job_offer_requested signal payload is correct"
    )

func _test_company_coverage() -> void:
    _reset_world()
    var valid := true

    for value in CharacterManager.jobs:
        if typeof(value) != TYPE_DICTIONARY:
            valid = false
            continue

        var job_id := int(value.get("job_id", -1))
        if CareerManager.get_companies_for_job(job_id).size() < 5:
            valid = false

    _assert_true(valid, "Every job is offered by at least five companies")

func _on_job_offer_requested(
    character_id: int,
    job_id: int,
    company_id: String,
    salary: int
) -> void:
    last_offer = {
        "character_id": character_id,
        "job_id": job_id,
        "company_id": company_id,
        "salary": salary
    }
