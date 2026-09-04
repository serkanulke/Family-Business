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
		registry.get_events_for_category("age_lifecycle", true).size() == 2,
		"Age / Lifecycle category contains only Retirement and Farewell"
	)

	_test_retirement_notification()
	_test_farewell_private_choice()
	_test_farewell_costs()

	print("========================================")
	print("Event Age / Lifecycle production tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_retirement_notification() -> void:
	_setup_character(65, "elder")
	var character := CharacterManager.get_character_by_id(1)
	character["is_retired"] = true
	character["last_salary"] = 12000
	character["pension"] = 1200
	character["salary"] = 0

	EventManager.dispatch_system_trigger(
		"retired",
		{
			"trigger_character_id": 1,
			"trigger_participants": {"primary": 1},
			"context": {"character_id": 1}
		},
		"retirement_1",
		"age_lifecycle_production_test"
	)

	_assert(
		EventManager.active_event != null
		and EventManager.active_event.event_id == "age_lifecycle_retirement",
		"Canonical retirement fact activates the Retirement Event"
	)

	var resolved := EventManager.resolve_active_event("continue")
	_assert(
		bool(resolved.get("resolved", false))
		and bool(character.get("is_retired", false))
		and int(character.get("last_salary", 0)) == 12000
		and int(character.get("pension", 0)) == 1200
		and int(character.get("salary", -1)) == 0,
		"Retirement Event preserves canonical CharacterManager retirement state"
	)


func _test_farewell_private_choice() -> void:
	_setup_dead_character()
	var character := CharacterManager.get_character_by_id(1)
	GameManager.family_money = 15000
	_dispatch_character_died("farewell_private")

	_assert(
		EventManager.active_event != null
		and EventManager.active_event.event_id == "age_lifecycle_funeral"
		and int(EventManager.active_event.participants.get("primary", 0)) == 1,
		"Dead family primary remains valid for the Farewell Event"
	)

	var resolved := EventManager.resolve_active_event("private_farewell")
	_assert(
		bool(resolved.get("resolved", false))
		and String(resolved.get("choice_id", "")) == "private_farewell"
		and GameManager.family_money == 15000
		and not character.has("ashes")
		and not character.has("family_display"),
		"Private Farewell records the choice without inventing unresolved funeral-state data"
	)


func _test_farewell_costs() -> void:
	_setup_dead_character()
	GameManager.family_money = 499
	_dispatch_character_died("farewell_small_cost")

	var blocked := EventManager.resolve_active_event("small_farewell")
	_assert(
		not bool(blocked.get("resolved", false))
		and GameManager.family_money == 499
		and EventManager.active_event != null,
		"Small Farewell is unavailable below its 500 Money cost without mutation"
	)

	GameManager.family_money = 500
	var small_resolved := EventManager.resolve_active_event("small_farewell")
	_assert(
		bool(small_resolved.get("resolved", false))
		and GameManager.family_money == 0,
		"Small Farewell deducts exactly 500 Money"
	)

	_setup_dead_character()
	GameManager.family_money = 2000
	_dispatch_character_died("farewell_large_cost")
	var large_resolved := EventManager.resolve_active_event("large_farewell")
	_assert(
		bool(large_resolved.get("resolved", false))
		and GameManager.family_money == 0,
		"Large Farewell deducts exactly 2,000 Money"
	)


func _setup_character(age: int, life_stage: String) -> void:
	EventManager.configure_runtime(registry, null, 41)
	TimeManager.current_year = 2000
	TimeManager.current_month = 1
	TimeManager.current_day = 1
	TimeManager.is_paused = false
	TimeManager.speed_multiplier = 1.0
	GameManager.family_money = 15000
	GameManager.diamonds = 0

	CharacterManager.characters = [{
		"character_id": 1,
		"character_type": "family",
		"first_name": "Lifecycle Test",
		"gender": "female",
		"birth_date": "%04d-01-01" % (2000 - age),
		"life_stage": life_stage,
		"is_alive": true,
		"is_player_family": true,
		"parent_ids": [],
		"children_ids": [],
		"partner_id": null,
		"flag_ids": [],
		"happiness": 50,
		"health": 50,
		"logic": 50,
		"attractiveness": 50,
		"social": 50,
		"confidence": 50,
		"discipline": 50,
		"creativity": 50,
		"school_id": null,
		"major_id": null,
		"education_status": "none",
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"is_retired": false,
		"last_salary": 0,
		"pension": 0,
		"event_log": []
	}]
	CharacterManager.next_character_id = 2


func _setup_dead_character() -> void:
	_setup_character(80, "elder")
	var character := CharacterManager.get_character_by_id(1)
	character["is_alive"] = false
	character["death_date"] = "2000-01-01"


func _dispatch_character_died(occurrence_key: String) -> void:
	EventManager.dispatch_system_trigger(
		"character_died",
		{
			"trigger_character_id": 1,
			"trigger_participants": {"primary": 1},
			"context": {
				"character_id": 1,
				"death_date": "2000-01-01"
			}
		},
		occurrence_key,
		"age_lifecycle_production_test"
	)


func _assert(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty():
			print(detail)
