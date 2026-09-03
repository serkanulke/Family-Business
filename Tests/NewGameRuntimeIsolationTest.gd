extends Node


const TEST_SAVE_DIRECTORY := "user://family_business_new_game_isolation_test"
const STARTING_MONEY_EVENT_ID := "new_game_initialized_money"
const OLD_MONEY_EVENT_ID := "new_game_old_money_leak"

var passed: int = 0
var failed: int = 0
var original_snapshot: Dictionary = {}
var original_registry: EventDataRegistry
var original_save_directory: String = ""
var original_save_id: int = -1


func _ready() -> void:
	original_snapshot = SaveManager.create_save_snapshot()
	original_registry = EventManager.registry
	original_save_directory = SaveManager.save_directory
	original_save_id = SaveManager.current_save_id

	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.current_save_id = -1
	_cleanup_test_saves()

	print("")
	print("========================================")
	print("New Game runtime isolation tests")
	print("========================================")

	_test_new_game_runtime_isolation_and_calendar_order()

	_cleanup_test_saves()
	EventManager.configure_runtime(original_registry)
	SaveManager.apply_save_snapshot(original_snapshot)
	SaveManager.save_directory = original_save_directory
	SaveManager.current_save_id = original_save_id

	print("")
	print(
		"New Game runtime isolation tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print("ALL NEW GAME RUNTIME ISOLATION TESTS PASSED.")
	else:
		push_error(
			"New Game runtime isolation has %d failing test(s)."
			% failed
		)

	get_tree().quit(0 if failed == 0 else 1)


func _test_new_game_runtime_isolation_and_calendar_order() -> void:
	var registry := EventDataRegistry.new()
	var loaded := registry.load_from_json_sources({
		"general.json": JSON.stringify({
			"schema_version": 1,
			"category": "general",
			"pools": [],
			"events": [
				_calendar_money_event(STARTING_MONEY_EVENT_ID, 15000, 10),
				_calendar_money_event(OLD_MONEY_EVENT_ID, 50000, 100)
			]
		})
	})
	_assert(
		loaded,
		"New Game calendar isolation fixture validates",
		registry.get_diagnostic_text()
	)
	EventManager.configure_runtime(registry, null, 73)

	# Deliberately populate save-scoped runtime with an old game's data.
	# New Game must clear these values before the fresh save is created.
	GameManager.family_money = 100000
	GameManager.diamonds = 99
	GameManager.family_name = "Old Runtime"
	CharacterManager.characters = [
		_old_family_character(),
		_old_relationship_candidate()
	]
	CharacterManager.next_character_id = 3
	BusinessManager.businesses = [{
		"business_instance_id": "business_0099",
		"business_type_id": "cafe",
		"plot_id": "old_plot",
		"level": 1,
		"slots": []
	}]
	BusinessManager.next_business_instance_number = 100
	CareerManager.active_job_offers = {
		1: {
			"character_id": 1,
			"job_id": 2001,
			"company_id": "old_company",
			"salary": 9999
		}
	}
	EducationManager.education_event_queue = [{
		"character_id": 1,
		"event_type": "school_enrollment",
		"education_stage": "primary_school"
	}]
	EducationManager.current_education_event = {
		"character_id": 1,
		"event_type": "school_enrollment",
		"education_stage": "primary_school"
	}
	EducationManager.is_education_event_active = true
	EducationManager.is_education_pause_active = true
	EducationManager.should_resume_time_after_education_events = true
	RelationshipNpcManager.relationship_candidate_ids = [2]

	var started := GameManager.start_new_game(
		"Fresh",
		"female",
		"Fresh Family"
	)

	_assert(
		not started.is_empty(),
		"New Game starts successfully from populated old runtime state"
	)
	_assert(
		BusinessManager.businesses.is_empty()
		and BusinessManager.next_business_instance_number == 1,
		"New Game clears old Business runtime state"
	)
	_assert(
		CareerManager.active_job_offers.is_empty(),
		"New Game clears old Career offer runtime state"
	)
	_assert(
		EducationManager.education_event_queue.is_empty()
		and EducationManager.current_education_event.is_empty()
		and not EducationManager.is_education_event_active
		and not EducationManager.is_education_pause_active
		and not EducationManager.should_resume_time_after_education_events,
		"New Game clears old Education queue and pause runtime state"
	)
	_assert(
		RelationshipNpcManager.relationship_candidate_ids.is_empty()
		and CharacterManager.characters.all(
			func(character_value): return (
				typeof(character_value) != TYPE_DICTIONARY
				or String(character_value.get("character_type", "")) != "relationship_npc"
			)
		),
		"New Game clears old Relationship candidate runtime state"
	)
	_assert(
		GameManager.family_money == GameManager.STARTING_FAMILY_MONEY
		and GameManager.diamonds == GameManager.STARTING_DIAMONDS,
		"Starting money and Diamonds are established before starting-date Event evaluation"
	)
	_assert(
		EventManager.active_event != null
		and EventManager.active_event.event_id == STARTING_MONEY_EVENT_ID
		and EventManager.queued_events.all(
			func(instance): return instance.event_id != OLD_MONEY_EVENT_ID
		),
		"Starting-date calendar Events see fresh New Game state, never old money"
	)

	var fresh_save_id := SaveManager.current_save_id
	_assert(
		fresh_save_id > 0,
		"Fresh New Game creates a dynamic save after initialization"
	)

	EventManager.reset_runtime_state()
	_assert(
		SaveManager.load_game(fresh_save_id)
		and EventManager.active_event != null
		and EventManager.active_event.event_id == STARTING_MONEY_EVENT_ID,
		"Initial save is created after the initialized starting-date Event is queued"
	)


func _calendar_money_event(
	event_id: String,
	minimum_money: int,
	priority: int
) -> Dictionary:
	return {
		"event_id": event_id,
		"category": "general",
		"domain": "general",
		"subtype": "new_game_runtime_isolation",
		"enabled": true,
		"rarity": "common",
		"weight": 1.0,
		"priority": priority,
		"exclusive_group": null,
		"trigger": {
			"type": "calendar",
			"exact_date": {"month": 1, "day": 26}
		},
		"participants": {},
		"requirements": {
			"all": [{
				"type": "money",
				"operator": ">=",
				"value": minimum_money
			}]
		},
		"repeat": {"mode": "repeatable"},
		"cooldown": null,
		"behavior": {"blocking": false, "pause_game": false},
		"content": {
			"title": event_id,
			"description": "New Game runtime isolation fixture"
		},
		"presentation": {"template": "standard_event"},
		"choices": [{
			"choice_id": "continue",
			"title": "Continue",
			"resolution": {"mode": "deterministic", "effects": []}
		}]
	}


func _old_family_character() -> Dictionary:
	return {
		"character_id": 1,
		"character_type": "family",
		"first_name": "Old",
		"gender": "male",
		"birth_date": "1960-01-01",
		"life_stage": "adult",
		"is_alive": true,
		"is_player_family": true,
		"parent_ids": [],
		"children_ids": [],
		"partner_id": null,
		"flag_ids": []
	}


func _old_relationship_candidate() -> Dictionary:
	return {
		"character_id": 2,
		"character_type": "relationship_npc",
		"first_name": "Old Candidate",
		"gender": "female",
		"birth_date": "1961-01-01",
		"life_stage": "adult",
		"is_alive": true,
		"is_player_family": false,
		"linked_character_id": 1,
		"relationship_status": "candidate",
		"parent_ids": [],
		"children_ids": [],
		"partner_id": null,
		"flag_ids": []
	}


func _cleanup_test_saves() -> void:
	var absolute_directory := ProjectSettings.globalize_path(TEST_SAVE_DIRECTORY)
	if not DirAccess.dir_exists_absolute(absolute_directory):
		return

	var directory := DirAccess.open(TEST_SAVE_DIRECTORY)
	if directory != null:
		directory.list_dir_begin()
		var file_name := directory.get_next()
		while not file_name.is_empty():
			if not directory.current_is_dir():
				DirAccess.remove_absolute(
					ProjectSettings.globalize_path(
						TEST_SAVE_DIRECTORY.path_join(file_name)
					)
				)
			file_name = directory.get_next()
		directory.list_dir_end()

	DirAccess.remove_absolute(absolute_directory)


func _assert(
	condition: bool,
	test_name: String,
	detail: String = ""
) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)
		if not detail.is_empty():
			print(detail)
