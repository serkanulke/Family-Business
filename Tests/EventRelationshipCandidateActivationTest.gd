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
	_run_tests()
	_restore_state()

	print("========================================")
	print(
		"Event Relationship candidate activation tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _run_tests() -> void:
	_setup_runtime()

	var first_result: Dictionary = EventManager.dispatch_system_trigger(
		"relationship_opportunity",
		{
			"trigger_character_id": 1,
			"trigger_participants": {"primary": 1}
		},
		"relationship_opportunity:first"
	)
	_assert(
		not first_result.get("queued_instances", []).is_empty()
		and EventManager.active_event != null,
		"Automatic Meet Someone fixture becomes active"
	)

	var first_candidate_id := (
		int(EventManager.active_event.participants.get("target", 0))
		if EventManager.active_event != null
		else 0
	)
	_assert(
		first_candidate_id > 0,
		"A new Relationship NPC is bound before the first Event is presented"
	)
	var first_candidate: Dictionary = (
		CharacterManager.get_character_by_id(first_candidate_id)
	)
	_assert(
		not first_candidate.is_empty()
		and String(first_candidate.get("relationship_status", "")) == "candidate"
		and int(first_candidate.get("linked_character_id", 0)) == 1
		and not bool(first_candidate.get("is_player_family", true)),
		"The first modal target is a canonical external candidate Character"
	)

	var first_reject: Dictionary = EventManager.resolve_active_event("reject")
	_assert(
		bool(first_reject.get("resolved", false))
		and not CharacterManager.get_character_by_id(first_candidate_id).is_empty(),
		"Rejecting the encounter keeps the shown candidate Character"
	)

	var second_result: Dictionary = EventManager.dispatch_system_trigger(
		"relationship_opportunity",
		{
			"trigger_character_id": 1,
			"trigger_participants": {"primary": 1}
		},
		"relationship_opportunity:second"
	)
	_assert(
		not second_result.get("queued_instances", []).is_empty()
		and EventManager.active_event != null,
		"The same family Character may receive another Meet Someone occurrence"
	)
	var second_candidate_id := (
		int(EventManager.active_event.participants.get("target", 0))
		if EventManager.active_event != null
		else 0
	)
	_assert(
		second_candidate_id > 0
		and second_candidate_id != first_candidate_id
		and int(
			CharacterManager.get_character_by_id(second_candidate_id).get(
				"linked_character_id",
				0
			)
		) == 1,
		"A later Meet Someone occurrence creates a different candidate for the same Character"
	)
	_assert(
		RelationshipNpcManager.get_relationship_candidate_ids_for(1).size() == 2,
		"Multiple pre-dating candidates remain concurrently available"
	)

	var second_reject: Dictionary = EventManager.resolve_active_event("reject")
	_assert(
		bool(second_reject.get("resolved", false)),
		"The second encounter resolves without deleting either candidate"
	)

	var married: bool = RelationshipNpcManager.make_candidate_family_member(
		first_candidate_id,
		1
	)
	_assert(
		married,
		"One of several candidates may be selected for marriage"
	)
	var second_candidate_after_marriage := (
		CharacterManager.get_character_by_id(second_candidate_id)
	)
	_assert(
		not second_candidate_after_marriage.is_empty()
		and second_candidate_after_marriage.get("linked_character_id", null) == null
		and not RelationshipNpcManager.relationship_candidate_ids.has(second_candidate_id)
		and RelationshipNpcManager.get_relationship_candidate_ids_for(1).is_empty(),
		"Marriage cuts the primary Character's links to all unselected Relationship NPCs"
	)

	var blocked_chain: Dictionary = EventManager.activate_chain(
		"candidate_followup",
		{"primary": 1, "target": second_candidate_id}
	)
	_assert(
		not bool(blocked_chain.get("queued", false)),
		"An old candidate cannot continue Relationship progression while the primary Character is married"
	)

	var divorced: bool = RelationshipNpcManager.divorce_characters(
		1,
		first_candidate_id
	)
	_assert(
		divorced,
		"The selected spouse can later divorce through the canonical manager"
	)
	_assert(
		not RelationshipNpcManager.get_relationship_candidate_ids_for(1).has(
			second_candidate_id
		)
		and CharacterManager.get_character_by_id(second_candidate_id).get(
			"linked_character_id",
			null
		) == null,
		"A cleared Relationship NPC link does not return after the selected marriage later ends"
	)

	var resumed_chain: Dictionary = EventManager.activate_chain(
		"candidate_followup",
		{"primary": 1, "target": second_candidate_id}
	)
	_assert(
		not bool(resumed_chain.get("queued", false)),
		"A Relationship NPC whose link was cleared by marriage cannot resume by exact ID"
	)

	var character_count_before := CharacterManager.characters.size()
	var candidate_count_before := RelationshipNpcManager.relationship_candidate_ids.size()
	EventManager.dispatch_system_trigger(
		"invalid_relationship_opportunity",
		{
			"trigger_character_id": 1,
			"trigger_participants": {"primary": 1}
		},
		"relationship_opportunity:invalid"
	)
	_assert(
		EventManager.active_event == null,
		"A generated candidate that fails final participant validation is never presented"
	)
	_assert(
		CharacterManager.characters.size() == character_count_before
		and RelationshipNpcManager.relationship_candidate_ids.size() == candidate_count_before,
		"Failed activation discards the unpresented generated candidate without orphan state"
	)


func _setup_runtime() -> void:
	SaveManager.current_save_id = -1
	TimeManager.current_year = 2000
	TimeManager.current_month = 1
	TimeManager.current_day = 1
	TimeManager.is_paused = true

	CharacterManager.characters = [_family_character()]
	CharacterManager.next_character_id = 2
	RelationshipNpcManager.relationship_candidate_ids = []

	var registry := EventDataRegistry.new()
	var document := {
		"schema_version": 1,
		"category": "relationship",
		"pools": [],
		"events": [
			_meet_event(
				"meet_someone_fixture",
				"relationship_opportunity",
				{"all": []}
			),
			_meet_event(
				"meet_invalid_fixture",
				"invalid_relationship_opportunity",
				{
					"all": [
						{
							"type": "is_family_member",
							"target": "target",
							"operator": "==",
							"value": true
						}
					]
				}
			),
			_followup_event()
		]
	}
	var loaded: bool = registry.load_from_json_sources(
		{"relationship.json": JSON.stringify(document)}
	)
	_assert(
		loaded,
		"Relationship candidate activation fixture registry validates",
		registry.get_diagnostic_text()
	)
	if loaded:
		EventManager.configure_runtime(registry, null, 29)


func _meet_event(
	event_id: String,
	semantic_event: String,
	target_requirements: Dictionary
) -> Dictionary:
	return {
		"event_id": event_id,
		"category": "relationship",
		"domain": "relationship",
		"subtype": "meet_someone_fixture",
		"enabled": true,
		"rarity": "common",
		"weight": 1.0,
		"priority": 0,
		"exclusive_group": null,
		"trigger": {
			"type": "system",
			"event": semantic_event
		},
		"participants": {
			"primary": {
				"type": "character",
				"source": "trigger"
			},
			"target": {
				"type": "relationship_npc",
				"source": "new_relationship_npc",
				"from": "primary",
				"requirements": target_requirements
			}
		},
		"requirements": {"all": []},
		"repeat": {"mode": "repeatable"},
		"cooldown": null,
		"behavior": {
			"blocking": true,
			"pause_game": true
		},
		"content": {
			"title": "Meet Someone",
			"description": "A new person appears."
		},
		"presentation": {"template": "standard_event"},
		"choices": [
			{
				"choice_id": "reject",
				"title": "Not interested",
				"requirements": {"all": []},
				"resolution": {
					"mode": "deterministic",
					"effects": []
				}
			}
		]
	}


func _followup_event() -> Dictionary:
	return {
		"event_id": "candidate_followup",
		"category": "relationship",
		"domain": "relationship",
		"subtype": "candidate_followup_fixture",
		"enabled": true,
		"rarity": "common",
		"weight": 1.0,
		"priority": 0,
		"exclusive_group": null,
		"trigger": {"type": "chain"},
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
		"requirements": {
			"all": [
				{
					"type": "relationship_status",
					"target": "target",
					"operator": "==",
					"value": "candidate"
				}
			]
		},
		"repeat": {"mode": "repeatable"},
		"cooldown": null,
		"behavior": {
			"blocking": true,
			"pause_game": true
		},
		"content": {
			"title": "Candidate Follow-up",
			"description": "Follow-up fixture."
		},
		"presentation": {"template": "standard_event"},
		"choices": [
			{
				"choice_id": "continue",
				"title": "Continue",
				"requirements": {"all": []},
				"resolution": {
					"mode": "deterministic",
					"effects": []
				}
			}
		]
	}


func _family_character() -> Dictionary:
	return {
		"character_id": 1,
		"character_type": "family",
		"first_name": "Primary",
		"gender": "male",
		"birth_date": "1975-01-01",
		"life_stage": "young_adult",
		"is_alive": true,
		"is_player_family": true,
		"linked_character_id": null,
		"relationship_status": "",
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
