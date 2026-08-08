extends Node

var passed: int = 0
var failed: int = 0
var saved_characters: Array = []
var saved_active_job_offers: Dictionary = {}
var saved_day: int = 1
var saved_month: int = 1
var saved_year: int = 1985
var saved_paused: bool = false
var signal_count: int = 0

func _ready() -> void:
    print("")
    print("========================================")
    print("CareerManager offer tests starting")
    print("========================================")
    _save_state()
    if not CareerManager.job_offer_requested.is_connected(_on_job_offer_requested):
        CareerManager.job_offer_requested.connect(_on_job_offer_requested)
    _run_all_tests()
    _restore_state()
    print("")
    print("========================================")
    print("Career offer tests: ", passed, " passed / ", failed, " failed")
    print("========================================")
    if failed == 0:
        print("ALL CAREER OFFER TESTS PASSED.")
    else:
        push_error("Career offer backend has %d failing test(s)." % failed)

func _run_all_tests() -> void:
    _test_pending_offer_blocks_duplicate()
    _test_accept_offer()
    _test_reject_offer()
    _test_employed_accepts_better_offer()
    _test_tampered_offer_rejected()
    _test_existing_job_gets_valid_company()

func _save_state() -> void:
    saved_characters = CharacterManager.characters.duplicate(true)
    saved_active_job_offers = CareerManager.active_job_offers.duplicate(true)
    saved_day = TimeManager.current_day
    saved_month = TimeManager.current_month
    saved_year = TimeManager.current_year
    saved_paused = TimeManager.is_paused

func _restore_state() -> void:
    CharacterManager.characters = saved_characters
    CareerManager.active_job_offers = saved_active_job_offers
    TimeManager.current_day = saved_day
    TimeManager.current_month = saved_month
    TimeManager.current_year = saved_year
    TimeManager.is_paused = saved_paused
    if CareerManager.job_offer_requested.is_connected(_on_job_offer_requested):
        CareerManager.job_offer_requested.disconnect(_on_job_offer_requested)

func _reset_world() -> void:
    CharacterManager.characters = []
    CareerManager.active_job_offers.clear()
    TimeManager.current_day = 26
    TimeManager.current_month = 1
    TimeManager.current_year = 1985
    TimeManager.is_paused = true
    signal_count = 0

func _make_graduate() -> Dictionary:
    var c: Dictionary = {
        "character_id": 1,
        "first_name": "Career Offer Test",
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
        "major_id": 5014,
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
        "unemployment_start_date": "1982-01-01",
        "job_offer_cooldown_until": "1985-02-01",
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

func _first_unemployed_offer(c: Dictionary) -> Dictionary:
    var pool := CareerManager.get_unemployed_offer_pool(c)
    if pool.is_empty():
        return {}
    var value = pool[0]
    if typeof(value) != TYPE_DICTIONARY:
        return {}
    return value

func _first_advancement_offer(c: Dictionary) -> Dictionary:
    var pool := CareerManager.get_employed_advancement_offer_pool(c)
    if pool.is_empty():
        return {}
    var value = pool[0]
    if typeof(value) != TYPE_DICTIONARY:
        return {}
    return value

func _test_pending_offer_blocks_duplicate() -> void:
    _reset_world()
    var c := _make_graduate()
    var offer := _first_unemployed_offer(c)
    CareerManager.request_job_offer(c, offer)
    var stored := CareerManager.get_active_job_offer(1)
    CareerManager.request_job_offer(c, offer)
    _assert_true(
        not stored.is_empty()
        and signal_count == 1
        and CareerManager.active_job_offers.size() == 1,
        "Active offer is stored and duplicate pending offer is blocked"
    )

func _test_accept_offer() -> void:
    _reset_world()
    var c := _make_graduate()
    var offer := _first_unemployed_offer(c)
    CareerManager.request_job_offer(c, offer)
    var accepted := CareerManager.accept_job_offer(1)
    _assert_true(
        accepted
        and int(c.get("job_id", -1)) == int(offer.get("job_id", -2))
        and String(c.get("company_id", "")) == String(offer.get("company_id", ""))
        and int(c.get("salary", -1)) == int(offer.get("salary", -2))
        and c.get("unemployment_start_date", "x") == null
        and c.get("job_offer_cooldown_until", "x") == null
        and CareerManager.get_active_job_offer(1).is_empty(),
        "Accepting offer applies job, company and salary and clears pending state"
    )

func _test_reject_offer() -> void:
    _reset_world()
    var c := _make_graduate()
    var offer := _first_unemployed_offer(c)
    CareerManager.request_job_offer(c, offer)
    var rejected := CareerManager.reject_job_offer(1)
    _assert_true(
        rejected
        and c.get("job_id", null) == null
        and c.get("company_id", null) == null
        and int(c.get("salary", -1)) == 0
        and CareerManager.get_active_job_offer(1).is_empty(),
        "Rejecting offer clears pending offer without creating employment"
    )

func _test_employed_accepts_better_offer() -> void:
    _reset_world()
    var c := _make_graduate()
    c["job_id"] = 2076
    c["company_id"] = "central_city_administration"
    c["salary"] = 5600
    c["unemployment_start_date"] = null
    c["job_offer_cooldown_until"] = null
    var offer := _first_advancement_offer(c)
    var old_job := int(c["job_id"])
    var old_salary := int(c["salary"])
    CareerManager.request_job_offer(c, offer)
    var accepted := CareerManager.accept_job_offer(1)
    _assert_true(
        accepted
        and int(c["job_id"]) != old_job
        and int(c["salary"]) > old_salary,
        "Accepting better offer immediately replaces current external job"
    )

func _test_tampered_offer_rejected() -> void:
    _reset_world()
    var c := _make_graduate()
    var offer := _first_unemployed_offer(c)
    CareerManager.request_job_offer(c, offer)
    var active := CareerManager.get_active_job_offer(1)
    active["salary"] = int(active.get("salary", 0)) + 999999
    var accepted := CareerManager.accept_job_offer(1)
    _assert_true(
        not accepted
        and c.get("job_id", null) == null
        and CareerManager.get_active_job_offer(1).is_empty(),
        "Tampered active offer is rejected and removed"
    )

func _test_existing_job_gets_valid_company() -> void:
    _reset_world()
    var c := _make_graduate()
    c["job_id"] = 2076
    c["company_id"] = null
    c["salary"] = 5600
    var assigned := CareerManager.assign_company_for_existing_job(c)
    var company_id := String(c.get("company_id", ""))
    _assert_true(
        assigned
        and not company_id.is_empty()
        and CareerManager.company_offers_job(company_id, 2076)
        and int(c["job_id"]) == 2076
        and int(c["salary"]) == 5600,
        "Existing job receives valid company without changing job or salary"
    )

func _on_job_offer_requested(
    _character_id: int,
    _job_id: int,
    _company_id: String,
    _salary: int
) -> void:
    signal_count += 1
