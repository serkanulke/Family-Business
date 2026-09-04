extends Node


var passed := 0
var failed := 0
var original_characters: Array = []
var original_money := 0
var original_diamonds := 0
var original_date: Dictionary = {}
var original_paused := false
var original_speed := 1.0


func _ready() -> void:
	_store_state()
	_test_save_scoped_pool_caps_eighty_characters()
	_test_zero_activation_allows_no_event()
	_test_factual_bound_primary_bypasses_random_pacing()
	_test_save_scoped_pool_validation_guards()
	EventManager.configure_runtime(_registry([], []))
	_restore_state()
	print("========================================")
	print("Event Random Pacing tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_save_scoped_pool_caps_eighty_characters() -> void:
	_setup_family(80)
	var pool := {
		"pool_id": "test_save_random",
		"selection_mode": "weighted_one",
		"selection_scope": "save",
		"activation_chance": 1.0,
		"max_events": 1
	}
	var first := _random_calendar_event("random_a", "test_save_random", 1.0)
	var second := _random_calendar_event("random_b", "test_save_random", 3.0)
	var registry := _registry([first, second], [pool])
	_assert(registry.is_valid, "Save-scoped random-pool fixture validates", registry.get_diagnostic_text())
	EventManager.configure_runtime(registry, null, 77, "2024-01-01")
	_set_date(2024, 1, 2)

	var result := EventManager.process_calendar_date("2024-01-02")
	var primary_id := 0
	if result.queued_instances.size() == 1:
		primary_id = int(result.queued_instances[0].get("participants", {}).get("primary", 0))
	_assert(
		result.queued_instances.size() == 1
		and result.selected_event_ids.size() == 1
		and primary_id >= 1
		and primary_id <= 80,
		"Eighty eligible Characters produce at most one Event from a max_events = 1 save pool"
	)
	if EventManager.active_event != null:
		EventManager.cancel_active_event()


func _test_zero_activation_allows_no_event() -> void:
	_setup_family(80)
	var pool := {
		"pool_id": "test_never_random",
		"selection_mode": "weighted_one",
		"selection_scope": "save",
		"activation_chance": 0.0,
		"max_events": 1
	}
	var event := _random_calendar_event("random_never", "test_never_random", 1.0)
	var registry := _registry([event], [pool])
	_assert(registry.is_valid, "Zero-activation random-pool fixture validates", registry.get_diagnostic_text())
	EventManager.configure_runtime(registry, null, 91, "2024-01-01")
	_set_date(2024, 1, 2)

	var result := EventManager.process_calendar_date("2024-01-02")
	_assert(
		result.selected_event_ids.is_empty()
		and result.queued_instances.is_empty()
		and EventManager.active_event == null,
		"A failed save-level activation roll may produce no random Event"
	)


func _test_factual_bound_primary_bypasses_random_pacing() -> void:
	_setup_family(80)
	var event := _event("factual_death", {"type":"system", "event":"character_died"})
	event.participants = {"primary":{"type":"character", "source":"trigger"}}
	var registry := _registry([event], [])
	_assert(registry.is_valid, "Factual Event fixture validates", registry.get_diagnostic_text())
	EventManager.configure_runtime(registry, null, 101)

	var result := EventManager.dispatch_system_trigger(
		"character_died",
		{
			"trigger_character_id": 37,
			"trigger_participants": {"primary": 37},
			"context": {"character_id": 37}
		},
		"factual_death_37",
		"random_pacing_test"
	)
	_assert(
		result.queued_instances.size() == 1
		and EventManager.active_event != null
		and int(EventManager.active_event.participants.get("primary", 0)) == 37,
		"A factual bound-primary Event still fires for its exact Character"
	)
	if EventManager.active_event != null:
		EventManager.cancel_active_event()


func _test_save_scoped_pool_validation_guards() -> void:
	var missing_chance_pool := {
		"pool_id": "invalid_missing_chance",
		"selection_mode": "weighted_one",
		"selection_scope": "save",
		"max_events": 1
	}
	var invalid_event := _random_calendar_event("invalid_random", "invalid_missing_chance", 1.0)
	var missing_chance_registry := _registry([invalid_event], [missing_chance_pool])
	_assert(
		not missing_chance_registry.is_valid
		and missing_chance_registry.get_diagnostic_text().contains("activation_chance"),
		"Save-scoped pools require explicit activation_chance"
	)

	var save_pool := {
		"pool_id": "invalid_manual_save_pool",
		"selection_mode": "weighted_one",
		"selection_scope": "save",
		"activation_chance": 0.5,
		"max_events": 1
	}
	var manual := _event(
		"invalid_manual_random",
		{
			"type":"manual",
			"source":"lifestyle",
			"mode":"pool",
			"pool_id":"invalid_manual_save_pool"
		}
	)
	manual.pool_id = "invalid_manual_save_pool"
	var manual_registry := _registry([manual], [save_pool])
	_assert(
		not manual_registry.is_valid
		and manual_registry.get_diagnostic_text().contains("automatic system or calendar"),
		"Manual/chain/scheduled flows cannot use save-scoped random pacing"
	)


func _random_calendar_event(event_id: String, pool_id: String, weight: float) -> Dictionary:
	var event := _event(
		event_id,
		{"type":"calendar", "cadence":{"unit":"day", "interval":1}}
	)
	event.pool_id = pool_id
	event.weight = weight
	event.participants = {"primary":{"type":"character", "source":"trigger"}}
	event.requirements = {
		"all": [
			{"type":"is_alive", "target":"primary", "operator":"==", "value":true},
			{"type":"is_family_member", "target":"primary", "operator":"==", "value":true}
		]
	}
	event.behavior.blocking = false
	return event


func _event(event_id: String, trigger: Dictionary) -> Dictionary:
	return {
		"event_id": event_id,
		"category": "general",
		"domain": "general",
		"subtype": "random_pacing_fixture",
		"enabled": true,
		"rarity": "common",
		"weight": 1.0,
		"priority": 0,
		"exclusive_group": null,
		"pool_id": null,
		"trigger": trigger,
		"participants": {},
		"requirements": {"all": []},
		"repeat": {"mode":"repeatable"},
		"cooldown": null,
		"behavior": {"blocking":true, "pause_game":true},
		"content": {"title":event_id, "description":"Random pacing fixture"},
		"presentation": {"template":"standard_event"},
		"choices": [
			{
				"choice_id":"continue",
				"title":"Continue",
				"resolution":{"mode":"deterministic", "effects":[]}
			}
		]
	}


func _registry(events: Array, pools: Array) -> EventDataRegistry:
	var registry := EventDataRegistry.new()
	var document := {
		"schema_version": 1,
		"category": "general",
		"pools": pools,
		"events": events
	}
	registry.load_from_json_sources({"general.json": JSON.stringify(document)})
	return registry


func _setup_family(count: int) -> void:
	CharacterManager.characters.clear()
	for character_id in range(1, count + 1):
		CharacterManager.characters.append(_character(character_id))
	CharacterManager.next_character_id = count + 1
	GameManager.family_money = 10000
	GameManager.diamonds = 0


func _character(character_id: int) -> Dictionary:
	return {
		"character_id": character_id,
		"character_type": "family",
		"first_name": "Character %d" % character_id,
		"gender": "female",
		"birth_date": "1980-01-01",
		"life_stage": "adult",
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
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"is_retired": false,
		"event_log": []
	}


func _set_date(year: int, month: int, day: int) -> void:
	TimeManager.current_year = year
	TimeManager.current_month = month
	TimeManager.current_day = day


func _store_state() -> void:
	original_characters = CharacterManager.characters.duplicate(true)
	original_money = GameManager.family_money
	original_diamonds = GameManager.diamonds
	original_date = {
		"year": TimeManager.current_year,
		"month": TimeManager.current_month,
		"day": TimeManager.current_day
	}
	original_paused = TimeManager.is_paused
	original_speed = TimeManager.speed_multiplier


func _restore_state() -> void:
	CharacterManager.characters = original_characters
	GameManager.family_money = original_money
	GameManager.diamonds = original_diamonds
	TimeManager.current_year = int(original_date.get("year", TimeManager.current_year))
	TimeManager.current_month = int(original_date.get("month", TimeManager.current_month))
	TimeManager.current_day = int(original_date.get("day", TimeManager.current_day))
	TimeManager.is_paused = original_paused
	TimeManager.speed_multiplier = original_speed


func _assert(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty():
			print(detail)
