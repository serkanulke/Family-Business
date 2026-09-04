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
		registry.get_events_for_category("education", true).size() == 5,
		"Education category contains the five mandatory production Events"
	)

	_test_primary_school_affordability_and_enrollment()
	_test_private_primary_uses_canonical_cost_and_bonus()
	_test_university_decline()
	_test_normal_major_selection()
	_test_fallback_major_selection()

	print("========================================")
	print("Event Education production tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_primary_school_affordability_and_enrollment() -> void:
	_setup_character(6)
	GameManager.family_money = 1000
	_set_education_event("school_enrollment", "primary_school")
	_dispatch_education_due("school_enrollment", "primary_school", "primary_affordability")

	_assert(
		EventManager.active_event != null
		and EventManager.active_event.event_id == "education_primary_school_choice",
		"Age-6 education fact activates the Primary School Event"
	)

	var blocked := EventManager.resolve_active_event("primary_private")
	_assert(
		not bool(blocked.get("resolved", false))
		and GameManager.family_money == 1000
		and EventManager.active_event != null,
		"Unaffordable paid school choice is rejected without mutation"
	)

	var resolved := EventManager.resolve_active_event("primary_public")
	var character := CharacterManager.get_character_by_id(1)
	_assert(
		bool(resolved.get("resolved", false))
		and int(character.get("school_id", 0)) == 1001
		and GameManager.family_money == 1000
		and int(character.get("logic", 0)) == 51
		and int(character.get("health", 0)) == 51
		and int(character.get("social", 0)) == 51,
		"Public Primary enrollment uses School.json and applies its canonical bonus"
	)


func _test_private_primary_uses_canonical_cost_and_bonus() -> void:
	_setup_character(6)
	GameManager.family_money = 10000
	_set_education_event("school_enrollment", "primary_school")
	_dispatch_education_due("school_enrollment", "primary_school", "primary_private")

	var resolved := EventManager.resolve_active_event("primary_private")
	var character := CharacterManager.get_character_by_id(1)
	_assert(
		bool(resolved.get("resolved", false))
		and int(character.get("school_id", 0)) == 1002
		and GameManager.family_money == 7800,
		"Private Primary enrollment deducts the canonical 2,200 School.json cost once"
	)
	_assert(
		int(character.get("happiness", 0)) == 51
		and int(character.get("logic", 0)) == 51
		and int(character.get("health", 0)) == 52
		and int(character.get("social", 0)) == 51
		and int(character.get("discipline", 0)) == 51
		and int(character.get("creativity", 0)) == 51,
		"Private Primary enrollment applies only the canonical School.json stat bonus"
	)


func _test_university_decline() -> void:
	_setup_character(18)
	var character := CharacterManager.get_character_by_id(1)
	character["school_id"] = 3001
	character["education_status"] = "graduated"
	character["graduation_date"] = "2000-01-01"
	GameManager.family_money = 10000
	_set_education_event("university_choice", "university")
	_dispatch_education_due("university_choice", "university", "university_decline")

	_assert(
		EventManager.active_event != null
		and EventManager.active_event.event_id == "education_university_choice",
		"Age-18 education fact activates the University Event"
	)

	var resolved := EventManager.resolve_active_event("skip_university")
	_assert(
		bool(resolved.get("resolved", false))
		and character.get("major_id", null) == null
		and String(character.get("education_status", "")) == "graduated"
		and EducationManager.current_education_event.is_empty(),
		"Do Not Attend University delegates to EducationManager.decline_university"
	)


func _test_normal_major_selection() -> void:
	_setup_university_student(21, 100)
	_set_education_event("major_selection", "university")
	_dispatch_education_due("major_selection", "university", "major_normal")

	_assert(
		EventManager.active_event != null
		and EventManager.active_event.event_id == "education_major_selection",
		"Age-21 major-selection fact activates the Major Event"
	)

	var fallback_blocked := EventManager.resolve_active_event("major_5016")
	_assert(
		not bool(fallback_blocked.get("resolved", false))
		and EventManager.active_event != null,
		"Fallback major is unavailable when at least one normal major is eligible"
	)

	var resolved := EventManager.resolve_active_event("major_5001")
	var character := CharacterManager.get_character_by_id(1)
	_assert(
		bool(resolved.get("resolved", false))
		and int(character.get("major_id", 0)) == 5001
		and String(character.get("education_status", "")) == "studying"
		and String(character.get("expected_graduation_date", "")) == "2003-01-01",
		"Normal major choice delegates selection and duration to EducationManager"
	)


func _test_fallback_major_selection() -> void:
	_setup_university_student(21, 0)
	_set_education_event("major_selection", "university")
	_dispatch_education_due("major_selection", "university", "major_fallback")

	var normal_blocked := EventManager.resolve_active_event("major_5001")
	_assert(
		not bool(normal_blocked.get("resolved", false))
		and EventManager.active_event != null,
		"Normal major is unavailable when its canonical stat requirements are not met"
	)

	var resolved := EventManager.resolve_active_event("major_5016")
	var character := CharacterManager.get_character_by_id(1)
	_assert(
		bool(resolved.get("resolved", false))
		and int(character.get("major_id", 0)) == 5016
		and String(character.get("education_status", "")) == "graduated"
		and String(character.get("graduation_date", "")) == "2000-01-01",
		"General Studies becomes available only as canonical fallback and graduates immediately at duration three"
	)


func _setup_character(age: int) -> void:
	EventManager.configure_runtime(registry, null, 37)
	TimeManager.current_year = 2000
	TimeManager.current_month = 1
	TimeManager.current_day = 1
	TimeManager.is_paused = false
	TimeManager.speed_multiplier = 1.0
	GameManager.family_money = 10000
	GameManager.diamonds = 0

	var life_stage := "child"
	if age >= 18:
		life_stage = "young_adult"
	elif age >= 12:
		life_stage = "teen"

	CharacterManager.characters = [{
		"character_id": 1,
		"character_type": "family",
		"first_name": "Education Test",
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
		"education_start_date": null,
		"major_selection_date": null,
		"expected_graduation_date": null,
		"graduation_date": null,
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"is_retired": false,
		"event_log": []
	}]
	CharacterManager.next_character_id = 2

	EducationManager.education_event_queue = []
	EducationManager.current_education_event = {}
	EducationManager.is_education_event_active = false
	EducationManager.is_education_pause_active = false
	EducationManager.should_resume_time_after_education_events = false


func _setup_university_student(age: int, stat_value: int) -> void:
	_setup_character(age)
	var character := CharacterManager.get_character_by_id(1)
	character["school_id"] = 4001
	character["education_status"] = "studying"
	character["education_start_date"] = "1997-01-01"
	for stat_name in CharacterManager.CHARACTER_STAT_NAMES:
		character[stat_name] = stat_value


func _set_education_event(event_type: String, education_stage: String) -> void:
	EducationManager.current_education_event = {
		"character_id": 1,
		"event_type": event_type,
		"education_stage": education_stage
	}
	EducationManager.is_education_event_active = true
	EducationManager.is_education_pause_active = true
	EducationManager.should_resume_time_after_education_events = false


func _dispatch_education_due(
	event_type: String,
	education_stage: String,
	occurrence_key: String
) -> void:
	EventManager.dispatch_system_trigger(
		"education_stage_due",
		{
			"trigger_character_id": 1,
			"trigger_participants": {"primary": 1},
			"context": {
				"character_id": 1,
				"event_type": event_type,
				"education_stage": education_stage
			}
		},
		occurrence_key,
		"education_production_test"
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
