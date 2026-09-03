extends Node


var passed: int = 0
var failed: int = 0

var original_characters: Array = []
var original_next_character_id: int = 1
var original_candidate_ids: Array[int] = []
var original_registry: EventDataRegistry
var original_save_id: int = -1
var original_time: Dictionary = {}


func _ready() -> void:
	_store_state()
	_run_test()
	_restore_state()

	print("========================================")
	print(
		"Event Relationship chain continuity tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _run_test() -> void:
	_setup_runtime()

	var source_result: Dictionary = EventManager.activate_chain(
		"relationship_set_dating",
		{"primary": 1, "target": 2}
	)
	_assert(
		bool(source_result.get("queued", false)),
		"Relationship source Event binds the existing candidate by exact ID"
	)

	var resolved: Dictionary = EventManager.resolve_active_event("continue")
	var candidate: Dictionary = CharacterManager.get_character_by_id(2)
	_assert(
		bool(resolved.get("resolved", false))
		and String(candidate.get("relationship_status", "")) == "dating",
		"Relationship status mutation changes candidate to dating"
	)
	_assert(
		not RelationshipNpcManager.get_relationship_candidate_ids_for(1).has(2),
		"Dating Character leaves the canonical candidate discovery pool"
	)

	var instance_value = resolved.get("instance", {})
	var finished_instance: Dictionary = (
		instance_value
		if typeof(instance_value) == TYPE_DICTIONARY
		else {}
	)
	var bound_value = finished_instance.get("participants", {})
	var bound_participants: Dictionary = (
		bound_value.duplicate(true)
		if typeof(bound_value) == TYPE_DICTIONARY
		else {}
	)
	_assert(
		int(bound_participants.get("primary", 0)) == 1
		and int(bound_participants.get("target", 0)) == 2,
		"Completed Event preserves the exact Relationship participant IDs"
	)

	var chain_result: Dictionary = EventManager.activate_chain(
		"relationship_dating_chain",
		bound_participants
	)
	_assert(
		bool(chain_result.get("queued", false))
		and EventManager.active_event != null
		and int(EventManager.active_event.participants.get("target", 0)) == 2,
		"Chain follow-up reuses the dating Character by exact ID without candidate-pool lookup"
	)
	EventManager.cancel_active_event()

	var scheduled: Dictionary = EventManager.schedule_event(
		"relationship_dating_scheduled",
		"2000-01-02",
		bound_participants
	)
	var scheduled_participants_value = scheduled.get("participants", {})
	var scheduled_participants: Dictionary = (
		scheduled_participants_value
		if typeof(scheduled_participants_value) == TYPE_DICTIONARY
		else {}
	)
	_assert(
		not scheduled.is_empty()
		and int(scheduled_participants.get("target", 0)) == 2,
		"Scheduled follow-up persists the exact Relationship participant ID"
	)

	var processed: Array = EventManager.process_scheduled_due("2000-01-02")
	var processed_record: Dictionary = {}
	if not processed.is_empty() and typeof(processed[0]) == TYPE_DICTIONARY:
		processed_record = processed[0]
	_assert(
		processed.size() == 1
		and String(processed_record.get("status", "")) == "queued"
		and EventManager.active_event != null
		and int(EventManager.active_event.participants.get("target", 0)) == 2,
		"Scheduled follow-up resolves the dating Character by exact ID after it left the candidate pool"
	)
	EventManager.cancel_active_event()


func _setup_runtime() -> void:
	SaveManager.current_save_id = -1
	TimeManager.current_year = 2000
	TimeManager.current_month = 1
	TimeManager.current_day = 1
	TimeManager.is_paused = true

	CharacterManager.characters = [
		_character(1, true, "family", null, ""),
		_character(2, false, "relationship_npc", 1, "candidate")
	]
	CharacterManager.next_character_id = 3
	RelationshipNpcManager.relationship_candidate_ids = [2]

	var registry := EventDataRegistry.new()
	var document := {
		"schema_version": 1,
		"category": "relationship",
		"pools": [],
		"events": [
			_event(
				"relationship_set_dating",
				"chain",
				[
					{
						"type": "relationship_status_set",
						"target": "target",
						"value": "dating"
					}
				],
				{"all": []}
			),
			_event(
				"relationship_dating_chain",
				"chain",
				[],
				{
					"all": [
						{
							"type": "relationship_status",
							"target": "target",
							"operator": "==",
							"value": "dating"
						}
					]
				}
			),
			_event(
				"relationship_dating_scheduled",
				"scheduled",
				[],
				{
					"all": [
						{
							"type": "relationship_status",
							"target": "target",
							"operator": "==",
							"value": "dating"
						}
					]
				}
			)
		]
	}
	var loaded: bool = registry.load_from_json_sources(
		{"relationship.json": JSON.stringify(document)}
	)
	_assert(
		loaded,
		"Relationship continuity fixture registry validates",
		registry.get_diagnostic_text()
	)
	if loaded:
		EventManager.configure_runtime(registry, null, 17)


func _event(
	event_id: String,
	trigger_type: String,
	effects: Array,
	requirements: Dictionary
) -> Dictionary:
	return {
		"event_id": event_id,
		"category": "relationship",
		"domain": "relationship",
		"subtype": "continuity_fixture",
		"enabled": true,
		"rarity": "common",
		"weight": 1.0,
		"priority": 0,
		"exclusive_group": null,
		"trigger": {"type": trigger_type},
		"participants": {
			"primary": {
				"type": "character",
				"source": "trigger"
			},
			"target": {
				"type": "relationship_npc",
				"source": "relationship_npc"
			}
		},
		"requirements": requirements,
		"repeat": {"mode": "repeatable"},
		"cooldown": null,
		"behavior": {
			"blocking": true,
			"pause_game": true
		},
		"content": {
			"title": event_id,
			"description": "Relationship continuity fixture"
		},
		"presentation": {"template": "standard_event"},
		"choices": [
			{
				"choice_id": "continue",
				"title": "Continue",
				"requirements": {"all": []},
				"resolution": {
					"mode": "deterministic",
					"effects": effects
				}
			}
		]
	}


func _character(
	character_id: int,
	is_family: bool,
	character_type: String,
	linked_character_id,
	relationship_status: String
) -> Dictionary:
	return {
		"character_id": character_id,
		"character_type": character_type,
		"first_name": "Character %d" % character_id,
		"gender": "female",
		"birth_date": "1980-01-01",
		"life_stage": "young_adult",
		"is_alive": true,
		"is_player_family": is_family,
		"linked_character_id": linked_character_id,
		"relationship_status": relationship_status,
		"relationship_cooldown_until": null,
		"parent_ids": [],
		"children_ids": [],
		"partner_id": null,
		"flag_ids": [],
		"health": 80,
		"happiness": 80,
		"logic": 80,
		"attractiveness": 80,
		"social": 80,
		"confidence": 80,
		"discipline": 80,
		"creativity": 80,
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"school_id": null,
		"major_id": null,
		"event_log": []
	}


func _store_state() -> void:
	original_characters = CharacterManager.characters.duplicate(true)
	original_next_character_id = CharacterManager.next_character_id
	original_candidate_ids = RelationshipNpcManager.relationship_candidate_ids.duplicate()
	original_registry = EventManager.registry
	original_save_id = SaveManager.current_save_id
	original_time = {
		"year": TimeManager.current_year,
		"month": TimeManager.current_month,
		"day": TimeManager.current_day,
		"paused": TimeManager.is_paused,
		"speed": TimeManager.speed_multiplier
	}


func _restore_state() -> void:
	if original_registry != null:
		EventManager.configure_runtime(original_registry)

	CharacterManager.characters = original_characters
	CharacterManager.next_character_id = original_next_character_id
	RelationshipNpcManager.relationship_candidate_ids = (
		original_candidate_ids.duplicate()
	)
	SaveManager.current_save_id = original_save_id

	TimeManager.current_year = int(original_time.get("year", 1985))
	TimeManager.current_month = int(original_time.get("month", 1))
	TimeManager.current_day = int(original_time.get("day", 26))
	TimeManager.is_paused = bool(original_time.get("paused", true))
	TimeManager.speed_multiplier = float(original_time.get("speed", 1.0))


func _assert(
	condition: bool,
	name: String,
	detail: String = ""
) -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty():
			print(detail)
