extends Node


const BIRTH_EVENT_ID := "relationship_birth_opportunity"
const WEDDING_EVENT_ID := "relationship_23_the_wedding"
const TEST_DATE := "2000-01-15"
const TEST_HOUSE_ID := "house_birth_event_test"


var passed := 0
var failed := 0
var registry: EventDataRegistry

var original_characters: Array = []
var original_next_character_id := 1
var original_houses: Dictionary = {}
var original_candidate_ids: Array[int] = []
var original_event_registry: EventDataRegistry
var original_event_state: Dictionary = {}
var original_time: Dictionary = {}
var original_money := 0
var original_save_id := -1


func _ready() -> void:
	_store_state()
	registry = EventDataRegistry.new()
	_assert(registry.load_all(), "Production Event registry validates with Birth scheduling", registry.get_diagnostic_text())
	if registry.get_event(BIRTH_EVENT_ID).is_empty():
		_finish()
		return

	_test_json_contract()
	_test_wedding_creates_one_plan()
	_test_deterministic_count_dates_and_no_age_compression()
	_test_invalid_future_opportunities_expire()
	_test_house_capacity_defers_without_refusal()
	_test_three_explicit_refusals()
	_test_twelve_month_propagation()
	_test_successful_birth_and_history()
	_test_persistence()

	_finish()


func _test_json_contract() -> void:
	var event := registry.get_event(BIRTH_EVENT_ID)
	var metadata: Dictionary = event.get("metadata", {}).get("birth_schedule", {})
	var counts: Array = metadata.get("opportunity_counts", [])
	var buckets: Array = metadata.get("timing_buckets", [])
	var participants: Dictionary = event.get("participants", {})
	var spouse: Dictionary = participants.get("spouse", {})
	var choices: Array = event.get("choices", [])

	_assert(
		counts.size() == 5
		and int(counts[0].get("count", -1)) == 0 and int(counts[0].get("weight", -1)) == 20
		and int(counts[1].get("count", -1)) == 1 and int(counts[1].get("weight", -1)) == 45
		and int(counts[2].get("count", -1)) == 2 and int(counts[2].get("weight", -1)) == 24
		and int(counts[3].get("count", -1)) == 3 and int(counts[3].get("weight", -1)) == 9
		and int(counts[4].get("count", -1)) == 4 and int(counts[4].get("weight", -1)) == 2,
		"Birth opportunity count weights remain JSON-driven and exact"
	)
	_assert(
		buckets.size() == 5
		and int(buckets[0].get("minimum_month", -1)) == 1 and int(buckets[0].get("maximum_month", -1)) == 12 and int(buckets[0].get("weight", -1)) == 10
		and int(buckets[1].get("minimum_month", -1)) == 13 and int(buckets[1].get("maximum_month", -1)) == 36 and int(buckets[1].get("weight", -1)) == 25
		and int(buckets[2].get("minimum_month", -1)) == 37 and int(buckets[2].get("maximum_month", -1)) == 72 and int(buckets[2].get("weight", -1)) == 30
		and int(buckets[3].get("minimum_month", -1)) == 73 and int(buckets[3].get("maximum_month", -1)) == 120 and int(buckets[3].get("weight", -1)) == 20
		and int(buckets[4].get("minimum_month", -1)) == 121 and int(buckets[4].get("maximum_month", -1)) == 240 and int(buckets[4].get("weight", -1)) == 15,
		"Birth timing buckets include the approved finite 121-240 month range"
	)
	_assert(
		String(event.get("category", "")) == "relationship"
		and String(event.get("trigger", {}).get("type", "")) == "scheduled"
		and String(spouse.get("source", "")) == "relation"
		and String(spouse.get("relation", "")) == "spouse"
		and String(spouse.get("from", "")) == "primary"
		and choices.size() == 2,
		"Birth remains a scheduled Relationship Event with the real spouse relation and two choices"
	)
	var birth_choice := _choice(event, "have_a_child")
	var no_choice := _choice(event, "not_now")
	_assert(
		_has_effect(birth_choice, "create_biological_child")
		and _has_effect(birth_choice, "resolve_birth_opportunity")
		and _has_effect(no_choice, "resolve_birth_opportunity")
		and birth_choice.get("resolution", {}).get("event_log", []).size() == 2,
		"Birth JSON owns creation, acceptance/refusal resolution, and both parent history entries"
	)


func _test_wedding_creates_one_plan() -> void:
	_setup_wedding_pair(41)
	var scheduled := EventManager.schedule_event(
		WEDDING_EVENT_ID,
		TEST_DATE,
		{"primary": 1, "candidate": 2}
	)
	var processed := EventManager.process_scheduled_due(TEST_DATE)
	var resolved := EventManager.resolve_active_event("keep_it_simple")
	var wedding_record: Dictionary = EventManager.story_history.records.back() if not EventManager.story_history.records.is_empty() else {}
	var opportunity_count := int(wedding_record.get("context", {}).get("birth_opportunity_count", -1))
	var birth_records := _birth_records()
	var before_duplicate := birth_records.duplicate(true)
	var duplicate_resolution := EventManager.resolve_active_event("keep_it_simple")

	_assert(
		not scheduled.is_empty()
		and processed.size() == 1
		and bool(resolved.get("resolved", false))
		and opportunity_count >= 0
		and opportunity_count <= 4
		and birth_records.size() == opportunity_count,
		"Wedding completion creates exactly one 0-4 Birth opportunity plan"
	)
	_assert(
		not bool(duplicate_resolution.get("resolved", true))
		and _birth_records() == before_duplicate,
		"The completed Wedding cannot reroll or duplicate the pair's Birth plan"
	)


func _test_deterministic_count_dates_and_no_age_compression() -> void:
	var found := false
	var selected_result: Dictionary = {}
	var selected_records: Array = []
	var selected_rng_state: Dictionary = {}
	for test_seed in range(1, 5001):
		_setup_married_pair(test_seed, 49, false)
		_set_fake_wedding_active("evt_birth_plan_%d" % test_seed)
		var result := EventManager.schedule_birth_opportunities_for_marriage(
			BIRTH_EVENT_ID,
			1,
			2,
			EventManager.active_event.instance_id
		)
		var records := _birth_records()
		var has_long_term := false
		for record in records:
			if GameCalendar.month_distance(TEST_DATE, String(record.get("due_date", ""))) >= 121:
				has_long_term = true
		if int(result.get("opportunity_count", 0)) == 4 and has_long_term:
			found = true
			selected_result = result
			selected_records = records
			selected_rng_state = EventManager.resolution_resolver.export_state()
			break

	var offsets: Array[int] = []
	for record in selected_records:
		offsets.append(GameCalendar.month_distance(TEST_DATE, String(record.get("due_date", ""))))
	var spaced := true
	for index in range(1, offsets.size()):
		if offsets[index] - offsets[index - 1] < 12:
			spaced = false
	var second_result := EventManager.schedule_birth_opportunities_for_marriage(
		BIRTH_EVENT_ID,
		1,
		2,
		EventManager.active_event.instance_id
	) if found else {}

	_assert(
		found
		and int(selected_result.get("opportunity_count", -1)) == 4
		and offsets.size() == 4
		and offsets.min() >= 1
		and offsets.max() <= 240
		and spaced,
		"Seeded Birth planning produces 0-4 exact ISO dates with at least 12 months between them",
		str(offsets)
	)
	_assert(
		found
		and offsets.max() >= 121
		and GameCalendar.compare(String(selected_records.back().get("due_date", "")), "2001-01-15") > 0,
		"A 49-year-old carrier keeps a selected long-term date instead of age-based compression",
		str(offsets)
	)
	_assert(
		found
		and second_result.get("scheduled_event_ids", []) == selected_result.get("scheduled_event_ids", [])
		and EventManager.resolution_resolver.export_state() == selected_rng_state
		and _birth_records().size() == 4,
		"Re-entering the same marriage plan is idempotent and consumes no new randomness"
	)


func _test_invalid_future_opportunities_expire() -> void:
	_setup_married_pair(5, 30, false)
	_schedule_birth(TEST_DATE, "death_plan", 0)
	CharacterManager.get_character_by_id(2)["is_alive"] = false
	var death_processed := EventManager.process_scheduled_due(TEST_DATE)
	_assert(
		death_processed.size() == 1
		and String(EventManager.scheduled_events[0].get("status", "")) == "expired"
		and EventManager.scheduled_events.size() == 1
		and EventManager.active_event == null,
		"A dead spouse expires the due opportunity without replacement"
	)

	_setup_married_pair(6, 30, false)
	_schedule_birth(TEST_DATE, "divorce_plan", 0)
	CharacterManager.get_character_by_id(1)["partner_id"] = null
	CharacterManager.get_character_by_id(2)["partner_id"] = null
	var divorce_processed := EventManager.process_scheduled_due(TEST_DATE)
	_assert(
		divorce_processed.size() == 1
		and String(EventManager.scheduled_events[0].get("status", "")) == "expired"
		and EventManager.scheduled_events.size() == 1
		and EventManager.active_event == null,
		"Divorce expires the due opportunity without replacement"
	)

	_setup_married_pair(7, 49, false)
	_schedule_birth("2001-01-15", "age_plan", 0)
	_set_date("2001-01-15")
	var age_processed := EventManager.process_scheduled_due("2001-01-15")
	_assert(
		age_processed.size() == 1
		and String(EventManager.scheduled_events[0].get("status", "")) == "expired"
		and EventManager.scheduled_events.size() == 1
		and EventManager.active_event == null,
		"A long-term opportunity drops at due date when biological age eligibility has ended"
	)


func _test_house_capacity_defers_without_refusal() -> void:
	_setup_married_pair(8, 30, true)
	var scheduled := _schedule_birth(TEST_DATE, "house_plan", 0)
	var processed := EventManager.process_scheduled_due(TEST_DATE)
	var birth_state := EventManager.get_active_choice_availability("have_a_child")
	var no_state := EventManager.get_active_choice_availability("not_now")
	var reasons: Array = birth_state.get("failure_reasons", [])
	var resolved := EventManager.resolve_active_event("not_now")
	var record: Dictionary = EventManager.scheduled_events[0]

	_assert(
		not scheduled.is_empty()
		and processed.size() == 1
		and EventManager.story_history.records.size() == 1
		and not bool(birth_state.get("available", true))
		and bool(no_state.get("available", false))
		and not reasons.is_empty()
		and "House" in String(reasons[0].get("message", "")),
		"A full House still presents Birth while disabling its choice with readable House feedback"
	)
	_assert(
		bool(resolved.get("resolved", false))
		and EventManager.scheduled_events.size() == 1
		and String(record.get("scheduled_event_id", "")) == String(scheduled.get("scheduled_event_id", ""))
		and String(record.get("status", "")) == "scheduled"
		and String(record.get("due_date", "")) == "2000-02-15"
		and int(record.get("context", {}).get("birth_refusal_count", -1)) == 0
		and int(record.get("context", {}).get("birth_attempt", 0)) == 1
		and not bool(record.get("context", {}).get("birth_opportunity_resolved", true))
		and CharacterManager.characters.size() == 2,
		"House deferral reuses the opportunity next month without consumption or refusal"
	)


func _test_three_explicit_refusals() -> void:
	_setup_married_pair(9, 30, false)
	_schedule_birth(TEST_DATE, "refusal_plan", 0)
	var dates := ["2000-01-15", "2000-02-15", "2000-03-15"]
	var states: Array = []
	var all_resolved := true
	for date_text in dates:
		_set_date(String(date_text))
		var processed := EventManager.process_scheduled_due(String(date_text))
		if processed.size() != 1 or EventManager.active_event == null:
			all_resolved = false
			break
		var resolved := EventManager.resolve_active_event("not_now")
		all_resolved = all_resolved and bool(resolved.get("resolved", false))
		states.append(EventManager.scheduled_events[0].duplicate(true))

	_assert(
		all_resolved
		and states.size() == 3
		and int(states[0].get("context", {}).get("birth_refusal_count", 0)) == 1
		and String(states[0].get("status", "")) == "scheduled"
		and String(states[0].get("due_date", "")) == "2000-02-15"
		and int(states[1].get("context", {}).get("birth_refusal_count", 0)) == 2
		and String(states[1].get("status", "")) == "scheduled"
		and String(states[1].get("due_date", "")) == "2000-03-15",
		"The first two explicit refusals preserve the same opportunity for the next month"
	)
	_assert(
		states.size() == 3
		and int(states[2].get("context", {}).get("birth_refusal_count", 0)) == 3
		and String(states[2].get("status", "")) == "queued"
		and bool(states[2].get("context", {}).get("birth_opportunity_resolved", false))
		and EventManager.scheduled_events.size() == 1
		and EventManager.story_history.records.size() == 3,
		"The third explicit refusal consumes the opportunity without creating a duplicate schedule"
	)


func _test_twelve_month_propagation() -> void:
	_setup_married_pair(10, 30, false)
	_schedule_birth("2000-03-15", "propagation_plan", 0, 2)
	_schedule_birth("2001-03-15", "propagation_plan", 1)
	_schedule_birth("2002-04-15", "propagation_plan", 2)
	_set_date("2000-03-15")
	EventManager.process_scheduled_due("2000-03-15")
	_set_date("2000-06-15")
	var resolved := EventManager.resolve_active_event("not_now")
	var records := _birth_records_for_plan("propagation_plan")

	_assert(
		bool(resolved.get("resolved", false))
		and records.size() == 3
		and String(records[1].get("due_date", "")) == "2001-06-15"
		and String(records[2].get("due_date", "")) == "2002-06-15",
		"Late resolution shifts each following opportunity only enough to preserve 12 months"
	)


func _test_successful_birth_and_history() -> void:
	_setup_married_pair(11, 30, false)
	_schedule_birth(TEST_DATE, "success_plan", 0)
	EventManager.process_scheduled_due(TEST_DATE)
	var story_before := EventManager.story_history.records.size()
	var resolved := EventManager.resolve_active_event("have_a_child")
	var child_id := 0
	for effect_result in resolved.get("effect_results", []):
		if String(effect_result.get("effect_type", "")) == "create_biological_child":
			child_id = int(effect_result.get("target_character_id", 0))
	var child := CharacterManager.get_character_by_id(child_id)
	var carrier := CharacterManager.get_character_by_id(1)
	var spouse := CharacterManager.get_character_by_id(2)
	var carrier_log: Array = carrier.get("event_log", [])
	var spouse_log: Array = spouse.get("event_log", [])

	_assert(
		bool(resolved.get("resolved", false))
		and not child.is_empty()
		and child.get("parent_ids", []) == [1, 2]
		and carrier.get("children_ids", []).count(child_id) == 1
		and spouse.get("children_ids", []).count(child_id) == 1
		and String(HouseManager.get_character_assignment(child_id).get("house_instance_id", "")) == TEST_HOUSE_ID,
		"Successful Birth uses the existing backend for parent links and mother's House assignment"
	)
	_assert(
		carrier_log.size() == 1
		and spouse_log.size() == 1
		and String(carrier_log[0].get("description", "")) == "👶 Welcomed a child with Noah"
		and String(spouse_log[0].get("description", "")) == "👶 Welcomed a child with Ava"
		and child.get("event_log", []).is_empty(),
		"Successful Birth writes JSON-defined history to both parents and none to the newborn"
	)
	_assert(
		EventManager.story_history.records.size() == story_before + 1
		and String(EventManager.story_history.records.back().get("event_id", "")) == BIRTH_EVENT_ID
		and bool(EventManager.scheduled_events[0].get("context", {}).get("birth_opportunity_resolved", false)),
		"Birth completion preserves normal story_history and consumes its scheduled opportunity"
	)


func _test_persistence() -> void:
	_setup_married_pair(12, 30, false)
	_schedule_birth(TEST_DATE, "persistence_plan", 0)
	EventManager.process_scheduled_due(TEST_DATE)
	EventManager.resolve_active_event("not_now")
	var before: Dictionary = EventManager.scheduled_events[0].duplicate(true)
	var snapshot := SaveManager.create_save_snapshot()
	EventManager.reset_runtime_state()
	var restored := SaveManager.apply_save_snapshot(snapshot)
	var after: Dictionary = EventManager.scheduled_events[0] if EventManager.scheduled_events.size() == 1 else {}

	_assert(
		restored
		and String(after.get("scheduled_event_id", "")) == String(before.get("scheduled_event_id", ""))
		and String(after.get("due_date", "")) == "2000-02-15"
		and int(after.get("context", {}).get("birth_refusal_count", 0)) == 1
		and int(after.get("context", {}).get("birth_attempt", 0)) == 1
		and String(after.get("context", {}).get("birth_plan_id", "")) == "persistence_plan",
		"Save/load preserves the planned opportunity, due date, and current refusal count"
	)


func _setup_wedding_pair(random_seed: int) -> void:
	_configure_runtime(random_seed)
	CharacterManager.characters = [
		_character(1, "Ava", "female", 30, true, "family", null, ""),
		_character(2, "Noah", "male", 31, false, "relationship_npc", 1, "dating")
	]
	CharacterManager.next_character_id = 3
	RelationshipNpcManager.relationship_candidate_ids = [2]
	_set_house(false)


func _setup_married_pair(random_seed: int, carrier_age: int, full_house: bool) -> void:
	_configure_runtime(random_seed)
	var carrier := _character(1, "Ava", "female", carrier_age, true, "family", null, "married")
	var spouse := _character(2, "Noah", "male", 31, true, "family", null, "married")
	carrier["partner_id"] = 2
	spouse["partner_id"] = 1
	CharacterManager.characters = [carrier, spouse]
	CharacterManager.next_character_id = 3
	RelationshipNpcManager.relationship_candidate_ids = []
	_set_house(full_house)


func _configure_runtime(random_seed: int) -> void:
	EventManager.configure_runtime(registry, null, random_seed)
	SaveManager.current_save_id = -1
	GameManager.set_family_money(100000)
	_set_date(TEST_DATE)
	TimeManager.is_paused = false


func _set_fake_wedding_active(instance_id: String) -> void:
	EventManager.active_event = EventInstance.new(
		instance_id,
		WEDDING_EVENT_ID,
		1,
		"scheduled",
		TEST_DATE,
		"active",
		{"primary": 1, "candidate": 2},
		{}
	)


func _schedule_birth(
	due_date: String,
	plan_id: String,
	opportunity_index: int,
	refusal_count: int = 0
) -> Dictionary:
	return EventManager.schedule_event(
		BIRTH_EVENT_ID,
		due_date,
		{"primary": 1, "spouse": 2},
		{
			"birth_plan_id": plan_id,
			"birth_opportunity_index": opportunity_index,
			"birth_refusal_count": refusal_count,
			"birth_attempt": 0,
			"birth_opportunity_resolved": false
		},
		"wedding_source"
	)


func _birth_records() -> Array:
	var result: Array = []
	for record in EventManager.scheduled_events:
		if String(record.get("event_id", "")) == BIRTH_EVENT_ID:
			result.append(record.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("context", {}).get("birth_opportunity_index", -1)) < int(right.get("context", {}).get("birth_opportunity_index", -1))
	)
	return result


func _birth_records_for_plan(plan_id: String) -> Array:
	var result: Array = []
	for record in _birth_records():
		if String(record.get("context", {}).get("birth_plan_id", "")) == plan_id:
			result.append(record)
	return result


func _choice(event: Dictionary, choice_id: String) -> Dictionary:
	for choice_value in event.get("choices", []):
		if typeof(choice_value) == TYPE_DICTIONARY and String(choice_value.get("choice_id", "")) == choice_id:
			return choice_value
	return {}


func _has_effect(choice: Dictionary, effect_type: String) -> bool:
	for effect_value in choice.get("resolution", {}).get("effects", []):
		if typeof(effect_value) == TYPE_DICTIONARY and String(effect_value.get("type", "")) == effect_type:
			return true
	return false


func _set_house(full_house: bool) -> void:
	HouseManager.restore_save_state({
		"houses": [
			{
				"house_instance_id": TEST_HOUSE_ID,
				"house_definition_id": "family_house",
				"property_id": "house_birth_event_property",
				"level": 1 if full_house else 2,
				"role_assignments": {
					"head_of_household": 1,
					"cook": null,
					"housekeeper": null,
					"caregiver": null
				},
				"resident_character_ids": [2]
			}
		],
		"next_house_instance_number": 2,
		"last_unhoused_penalty_date": ""
	})


func _character(
	character_id: int,
	first_name: String,
	gender: String,
	age: int,
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
		"birth_date": "%04d-01-15" % (2000 - age),
		"life_stage": "adult",
		"is_alive": true,
		"death_date": null,
		"is_player_family": is_family,
		"linked_character_id": linked_character_id,
		"relationship_status": relationship_status,
		"relationship_cooldown_until": null,
		"rejected_by_character_ids": [],
		"parent_ids": [],
		"is_adopted": false,
		"partner_id": null,
		"children_ids": [],
		"school_id": null,
		"major_id": null,
		"education_status": "graduated",
		"education_start_date": null,
		"major_selection_date": null,
		"expected_graduation_date": null,
		"graduation_date": null,
		"is_retired": false,
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"last_salary": 0,
		"pension": 0,
		"unemployment_start_date": null,
		"job_offer_cooldown_until": null,
		"flag_ids": [],
		"event_log": [],
		"avatar_theme": "classic",
		"genetics": {"skin_tone": "light"},
		"portrait_variant_id": "",
		"portrait_path": "res://Resources/Characters/default_avatar.png",
		"health": 50,
		"happiness": 50,
		"logic": 50,
		"attractiveness": 50,
		"social": 50,
		"confidence": 50,
		"discipline": 50,
		"creativity": 50
	}


func _set_date(date_text: String) -> void:
	var parsed := GameCalendar.parse_iso_date(date_text)
	TimeManager.current_year = int(parsed.get("year", 2000))
	TimeManager.current_month = int(parsed.get("month", 1))
	TimeManager.current_day = int(parsed.get("day", 15))


func _store_state() -> void:
	original_characters = CharacterManager.characters.duplicate(true)
	original_next_character_id = CharacterManager.next_character_id
	original_houses = HouseManager.create_save_state()
	original_candidate_ids = RelationshipNpcManager.relationship_candidate_ids.duplicate()
	original_event_registry = EventManager.registry
	original_event_state = EventManager.export_runtime_state()
	original_time = {
		"year": TimeManager.current_year,
		"month": TimeManager.current_month,
		"day": TimeManager.current_day,
		"paused": TimeManager.is_paused,
		"speed": TimeManager.speed_multiplier
	}
	original_money = GameManager.family_money
	original_save_id = SaveManager.current_save_id


func _restore_state() -> void:
	CharacterManager.characters = original_characters
	CharacterManager.next_character_id = original_next_character_id
	HouseManager.restore_save_state(original_houses)
	RelationshipNpcManager.relationship_candidate_ids = original_candidate_ids.duplicate()
	GameManager.set_family_money(original_money)
	SaveManager.current_save_id = original_save_id
	TimeManager.current_year = int(original_time.get("year", 1985))
	TimeManager.current_month = int(original_time.get("month", 1))
	TimeManager.current_day = int(original_time.get("day", 26))
	TimeManager.is_paused = bool(original_time.get("paused", true))
	TimeManager.speed_multiplier = float(original_time.get("speed", 1.0))
	if original_event_registry != null:
		EventManager.configure_runtime(original_event_registry)
		EventManager.import_runtime_state(original_event_state)


func _finish() -> void:
	_restore_state()
	print("========================================")
	print("Birth Event scheduling tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _assert(condition: bool, test_name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name + (" | " + detail if not detail.is_empty() else ""))
