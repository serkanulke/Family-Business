extends Node


const WEDDING_EVENT_ID := "relationship_23_the_wedding"
const EVENT_DATE := "2000-01-15"

var passed := 0
var failed := 0

var original_characters: Array = []
var original_next_character_id := 1
var original_candidate_ids: Array[int] = []
var original_registry: EventDataRegistry
var original_money := 0
var original_save_id := -1
var original_time: Dictionary = {}


func _ready() -> void:
	_store_state()
	_test_successful_wedding_logs()
	_test_failed_and_cancelled_wedding_logs()
	_test_expired_wedding_logs()
	_restore_state()

	print("========================================")
	print(
		"Character Event Log tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_successful_wedding_logs() -> void:
	_setup_wedding_pair()
	var activated := _activate_wedding()
	_assert(
		activated,
		"Production Wedding reaches the active Event through its scheduled trigger"
	)
	if not activated:
		return

	var participants := EventManager.active_event.participants.duplicate(true)
	var context := EventManager.active_event.context.duplicate(true)
	var choice := _wedding_choice("keep_it_simple")
	var authored_logs_value = choice.get("resolution", {}).get(
		"event_log",
		[]
	)
	var authored_logs: Array = (
		authored_logs_value
		if typeof(authored_logs_value) == TYPE_ARRAY
		else []
	)
	var expected_by_target: Dictionary = {}
	for entry_value in authored_logs:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		expected_by_target[String(entry.get("target", ""))] = (
			EventPresentationResolver.resolve_text(
				String(entry.get("description", "")),
				participants,
				context
			)
		)

	var resolved := EventManager.resolve_active_event(
		"keep_it_simple"
	)
	var primary := CharacterManager.get_character_by_id(1)
	var candidate := CharacterManager.get_character_by_id(2)
	var primary_log: Array = primary.get("event_log", [])
	var candidate_log: Array = candidate.get("event_log", [])

	_assert(
		bool(resolved.get("resolved", false)),
		"Production Wedding resolution completes successfully"
	)
	_assert(
		int(primary.get("partner_id", 0)) == 2
		and int(candidate.get("partner_id", 0)) == 1
		and bool(candidate.get("is_player_family", false)),
		"Wedding marriage state still uses the canonical Relationship flow"
	)
	_assert(
		primary_log.size() == 1
		and candidate_log.size() == 1,
		"Wedding appends exactly one Character event_log entry to each spouse"
	)
	_assert(
		String(primary_log[0].get("date", "")) == EVENT_DATE
		and String(candidate_log[0].get("date", "")) == EVENT_DATE,
		"Wedding Character event_log dates use the current game date"
	)
	_assert(
		String(primary_log[0].get("description", ""))
		== String(expected_by_target.get("primary", ""))
		and String(candidate_log[0].get("description", ""))
		== String(expected_by_target.get("candidate", ""))
		and String(primary_log[0].get("description", ""))
		== "💍 Married Noah"
		and String(candidate_log[0].get("description", ""))
		== "💍 Married Ava",
		"Wedding descriptions come from JSON and resolve participant-name tokens"
	)
	_assert(
		primary_log[0].size() == 2
		and candidate_log[0].size() == 2
		and primary_log[0].has("date")
		and primary_log[0].has("description")
		and candidate_log[0].has("date")
		and candidate_log[0].has("description"),
		"Character Event History stores only date and description"
	)
	_assert(
		EventManager.story_history.records.size() == 1
		and EventManager.story_history.has_completed(
			WEDDING_EVENT_ID,
			participants,
			context
		),
		"Event story_history remains separate and records the completed Wedding"
	)

	var duplicate_attempt := EventManager.resolve_active_event(
		"keep_it_simple"
	)
	_assert(
		not bool(duplicate_attempt.get("resolved", true))
		and primary_log.size() == 1
		and candidate_log.size() == 1,
		"A completed Wedding cannot append duplicate Character history entries"
	)


func _test_failed_and_cancelled_wedding_logs() -> void:
	_setup_wedding_pair()
	var activated := _activate_wedding()
	_assert(
		activated,
		"Failure fixture activates the production Wedding"
	)
	if not activated:
		return

	var money_before := GameManager.family_money
	CharacterManager.get_character_by_id(2)["linked_character_id"] = 999
	var failed_resolution := EventManager.resolve_active_event(
		"keep_it_simple"
	)
	var primary_log: Array = CharacterManager.get_character_by_id(1).get(
		"event_log",
		[]
	)
	var candidate_log: Array = CharacterManager.get_character_by_id(2).get(
		"event_log",
		[]
	)
	_assert(
		not bool(failed_resolution.get("resolved", true))
		and GameManager.family_money == money_before
		and EventManager.story_history.records.is_empty()
		and primary_log.is_empty()
		and candidate_log.is_empty(),
		"Failed Wedding effect leaves no Character log or completed story history"
	)

	_assert(
		EventManager.cancel_active_event()
		and primary_log.is_empty()
		and candidate_log.is_empty(),
		"Cancelled Wedding leaves no Character event_log entry"
	)


func _test_expired_wedding_logs() -> void:
	_setup_wedding_pair()
	var activated := _activate_wedding()
	_assert(
		activated,
		"Expiration fixture activates the production Wedding"
	)
	if not activated:
		return

	var expired := EventManager.expire_active_event()
	_assert(
		expired
		and CharacterManager.get_character_by_id(1).get(
			"event_log",
			[]
		).is_empty()
		and CharacterManager.get_character_by_id(2).get(
			"event_log",
			[]
		).is_empty(),
		"Expired Wedding leaves no Character event_log entry"
	)


func _setup_wedding_pair() -> void:
	EventManager.reset_runtime_state()
	SaveManager.current_save_id = -1
	TimeManager.current_year = 2000
	TimeManager.current_month = 1
	TimeManager.current_day = 15
	TimeManager.is_paused = true
	GameManager.set_family_money(100000)

	CharacterManager.characters = [
		_character(1, "Ava", "female", true, "family", null, ""),
		_character(2, "Noah", "male", false, "relationship_npc", 1, "dating")
	]
	CharacterManager.next_character_id = 3
	RelationshipNpcManager.relationship_candidate_ids = [2]


func _activate_wedding() -> bool:
	var scheduled := EventManager.schedule_event(
		WEDDING_EVENT_ID,
		EVENT_DATE,
		{"primary": 1, "candidate": 2}
	)
	var processed := EventManager.process_scheduled_due(
		EVENT_DATE
	)
	return (
		not scheduled.is_empty()
		and processed.size() == 1
		and EventManager.active_event != null
		and EventManager.active_event.event_id == WEDDING_EVENT_ID
	)


func _wedding_choice(choice_id: String) -> Dictionary:
	var event := EventManager.registry.get_event(
		WEDDING_EVENT_ID
	)
	for choice_value in event.get("choices", []):
		if (
			typeof(choice_value) == TYPE_DICTIONARY
			and String(choice_value.get("choice_id", "")) == choice_id
		):
			return choice_value
	return {}


func _character(
	character_id: int,
	first_name: String,
	gender: String,
	is_family: bool,
	character_type: String,
	linked_character_id,
	relationship_status: String
) -> Dictionary:
	return {
		"character_id": character_id,
		"character_type": character_type,
		"first_name": first_name,
		"gender": gender,
		"birth_date": "1980-01-01",
		"life_stage": "young_adult",
		"is_alive": true,
		"is_player_family": is_family,
		"linked_character_id": linked_character_id,
		"relationship_status": relationship_status,
		"relationship_cooldown_until": null,
		"rejected_by_character_ids": [],
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
	original_candidate_ids = (
		RelationshipNpcManager.relationship_candidate_ids.duplicate()
	)
	original_registry = EventManager.registry
	original_money = GameManager.family_money
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
		EventManager.configure_runtime(
			original_registry
		)
	CharacterManager.characters = original_characters
	CharacterManager.next_character_id = original_next_character_id
	RelationshipNpcManager.relationship_candidate_ids = (
		original_candidate_ids.duplicate()
	)
	GameManager.set_family_money(original_money)
	SaveManager.current_save_id = original_save_id
	TimeManager.current_year = int(original_time.get("year", 1985))
	TimeManager.current_month = int(original_time.get("month", 1))
	TimeManager.current_day = int(original_time.get("day", 26))
	TimeManager.is_paused = bool(original_time.get("paused", true))
	TimeManager.speed_multiplier = float(original_time.get("speed", 1.0))


func _assert(
	condition: bool,
	test_name: String
) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)
