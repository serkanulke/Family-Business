extends Node


var passed := 0
var failed := 0
var registry: EventDataRegistry


func _ready() -> void:
	registry = EventDataRegistry.new()
	_assert(
		registry.load_all(),
		"Production Event registry validates",
		registry.get_diagnostic_text()
	)
	_assert(
		registry.get_events_for_category("job_offer", true).size() == 1,
		"Job Offer category contains one canonical production Event"
	)

	_test_unemployed_offer_acceptance()
	_test_rejection_and_repeatability()
	_test_better_offer_replaces_external_job()

	print("========================================")
	print("Event Job Offer production tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_unemployed_offer_acceptance() -> void:
	_setup_character()

	var character := CharacterManager.get_character_by_id(1)
	CareerManager.request_job_offer(
		character,
		{
			"job_id": 1001,
			"company_id": "metro_works_services",
			"salary": 1200
		}
	)

	_assert(
		EventManager.active_event != null
		and EventManager.active_event.event_id == "job_offer_external_offer",
		"Canonical CareerManager offer activates the production Job Offer Event"
	)

	_assert(
		EventManager.active_event != null
		and int(EventManager.active_event.context.get("job_id", 0)) == 1001
		and String(EventManager.active_event.context.get("company_id", "")) == "metro_works_services"
		and int(EventManager.active_event.context.get("salary", 0)) == 1200,
		"Exact CareerManager offer data is preserved in Event context for presentation"
	)

	var first_content := EventManager.active_event.get_resolved_content()
	_assert(
		String(first_content.get("description", ""))
		== "MetroWorks Services has offered Career Test a position as Cashier. They are offering a salary of 1200.",
		"Generic Job Offer content resolves Character, Job, Company, and Salary tags from canonical runtime data"
	)

	var resolved := EventManager.resolve_active_event("accept_offer")
	_assert(
		bool(resolved.get("resolved", false))
		and int(character.get("job_id", 0)) == 1001
		and String(character.get("company_id", "")) == "metro_works_services"
		and int(character.get("salary", 0)) == 1200
		and CareerManager.get_active_job_offer(1).is_empty(),
		"Accept Offer delegates canonical job, company, and salary mutation to CareerManager"
	)


func _test_rejection_and_repeatability() -> void:
	_setup_character()

	var character := CharacterManager.get_character_by_id(1)
	CareerManager.request_job_offer(
		character,
		{
			"job_id": 1001,
			"company_id": "metro_works_services",
			"salary": 1200
		}
	)

	var rejected := EventManager.resolve_active_event("decline_offer")
	_assert(
		bool(rejected.get("resolved", false))
		and character.get("job_id", null) == null
		and character.get("company_id", null) == null
		and int(character.get("salary", 0)) == 0
		and CareerManager.get_active_job_offer(1).is_empty(),
		"Decline Offer clears only the pending CareerManager offer"
	)

	CareerManager.request_job_offer(
		character,
		{
			"job_id": 1002,
			"company_id": "urban_link_staffing",
			"salary": 1800
		}
	)

	_assert(
		EventManager.active_event != null
		and EventManager.active_event.event_id == "job_offer_external_offer"
		and int(EventManager.active_event.context.get("job_id", 0)) == 1002,
		"Same Character can receive the repeatable Job Offer Event again"
	)

	var second_content := EventManager.active_event.get_resolved_content()
	_assert(
		String(second_content.get("description", ""))
		== "UrbanLink Staffing has offered Career Test a position as Warehouse Worker. They are offering a salary of 1800.",
		"The same generic Job Offer Event renders a different canonical offer without per-Job Event definitions"
	)

	EventManager.resolve_active_event("decline_offer")


func _test_better_offer_replaces_external_job() -> void:
	_setup_character()

	var character := CharacterManager.get_character_by_id(1)
	character["job_id"] = 1001
	character["company_id"] = "metro_works_services"
	character["salary"] = 1200
	character["unemployment_start_date"] = null

	CareerManager.request_job_offer(
		character,
		{
			"job_id": 1002,
			"company_id": "urban_link_staffing",
			"salary": 1800
		}
	)

	_assert(
		EventManager.active_event != null
		and EventManager.active_event.event_id == "job_offer_external_offer",
		"Better external offer uses the same canonical Job Offer Event"
	)

	var resolved := EventManager.resolve_active_event("accept_offer")
	_assert(
		bool(resolved.get("resolved", false))
		and int(character.get("job_id", 0)) == 1002
		and String(character.get("company_id", "")) == "urban_link_staffing"
		and int(character.get("salary", 0)) == 1800
		and CareerManager.get_active_job_offer(1).is_empty(),
		"Accepting a better offer replaces external employment through CareerManager"
	)


func _setup_character() -> void:
	EventManager.configure_runtime(registry, null, 59)
	TimeManager.current_year = 2000
	TimeManager.current_month = 1
	TimeManager.current_day = 1
	TimeManager.is_paused = false
	TimeManager.speed_multiplier = 1.0
	GameManager.family_money = 10000
	GameManager.diamonds = 0

	BusinessManager.businesses.clear()
	CareerManager.active_job_offers.clear()

	CharacterManager.characters = [{
		"character_id": 1,
		"character_type": "family",
		"first_name": "Career Test",
		"gender": "female",
		"birth_date": "1975-01-01",
		"life_stage": "young_adult",
		"is_alive": true,
		"is_player_family": true,
		"parent_ids": [],
		"children_ids": [],
		"partner_id": null,
		"flag_ids": [],
		"happiness": 50,
		"health": 100,
		"logic": 100,
		"attractiveness": 100,
		"social": 100,
		"confidence": 100,
		"discipline": 100,
		"creativity": 100,
		"school_id": 4001,
		"major_id": null,
		"education_status": "graduated",
		"education_start_date": null,
		"major_selection_date": null,
		"expected_graduation_date": null,
		"graduation_date": "1999-01-01",
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"unemployment_start_date": "1999-01-01",
		"job_offer_cooldown_until": null,
		"is_retired": false,
		"event_log": []
	}]
	CharacterManager.next_character_id = 2


func _assert(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty():
			print(detail)
