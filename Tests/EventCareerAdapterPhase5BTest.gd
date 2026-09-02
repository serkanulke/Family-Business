extends Node


var passed := 0
var failed := 0
var original_snapshot: Dictionary = {}
var original_registry: EventDataRegistry
var original_save_id := -1
var semantic_occurrences: Array[Dictionary] = []
var requested_offers: Array[Dictionary] = []
var accepted_offers: Array[Dictionary] = []
var removed_jobs: Array[Dictionary] = []
var completed_events: Array[Dictionary] = []


func _ready() -> void:
	original_snapshot = SaveManager.create_save_snapshot()
	original_registry = EventManager.registry
	original_save_id = SaveManager.current_save_id
	SaveManager.current_save_id = -1
	_connect_capture_signals()

	_test_offer_requested_and_duplicate_guard()
	_test_unemployed_acceptance_dispatches_job_started()
	_test_employed_acceptance_dispatches_job_changed()
	_test_failed_acceptance_dispatches_nothing()
	_test_rejection_remains_authoritative_without_semantic_trigger()
	_test_external_job_removal_dispatches_job_lost()
	_test_failed_job_removal_dispatches_nothing()
	_test_family_business_isolation()
	_test_salary_increase_remains_narrow()
	_test_save_load_without_semantic_replay()
	_test_nested_event_acceptance_queues_one_follow_up()

	_disconnect_capture_signals()
	EventManager.configure_runtime(original_registry)
	SaveManager.apply_save_snapshot(original_snapshot)
	SaveManager.current_save_id = original_save_id

	print("========================================")
	print("Event Phase 5B Career adapter tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_offer_requested_and_duplicate_guard() -> void:
	var character := _graduate()
	_setup_world(character, [_system_event("phase5b_offer", "job_offer_requested")])
	var offer := _first_unemployed_offer(character)
	CareerManager.request_job_offer(character, offer)
	var stored := CareerManager.get_active_job_offer(1)
	var occurrences := _semantic("job_offer_requested")
	_assert(not stored.is_empty() and stored == offer, "Offer is stored in CareerManager before presentation/adaptation")
	_assert(requested_offers.size() == 1 and bool(requested_offers[0].get("stored_when_emitted", false)), "Authoritative job_offer_requested signal emits once after active offer storage")
	_assert(occurrences.size() == 1 and _context_matches(occurrences[0], {"character_id":1,"job_id":offer.job_id,"company_id":offer.company_id,"salary":offer.salary}), "Offer request dispatches one semantic occurrence with canonical offer context")
	_assert(String(occurrences[0].occurrence_id) == "job_offer_requested:1:%d:%s:1985-01-26" % [int(offer.job_id), String(offer.company_id)], "Offer occurrence identity uses stable Character, Job, Company, and date values")
	_assert(EventManager.active_event != null and EventManager.active_event.event_id == "phase5b_offer" and int(EventManager.active_event.participants.primary) == 1 and EventManager.queued_events.is_empty(), "Offer request queues one controlled Event with primary participant binding")

	CareerManager.request_job_offer(character, offer)
	_assert(CareerManager.active_job_offers.size() == 1 and requested_offers.size() == 1 and _semantic("job_offer_requested").size() == 1 and EventManager.queued_events.is_empty(), "Existing active offer blocks a second domain request, semantic occurrence, and Event")
	EventManager.cancel_active_event()


func _test_unemployed_acceptance_dispatches_job_started() -> void:
	var character := _graduate()
	_setup_world(character, [_system_event("phase5b_started", "job_started"), _system_event("phase5b_changed", "job_changed")])
	var offer := _first_unemployed_offer(character)
	CareerManager.request_job_offer(character, offer)
	_clear_captures()
	var accepted := CareerManager.accept_job_offer(1)
	var started := _semantic("job_started")
	_assert(accepted and character.job_id == offer.job_id and character.company_id == offer.company_id and character.salary == offer.salary, "Unemployed acceptance assigns the canonical offer exactly once")
	_assert(CareerManager.get_active_job_offer(1).is_empty() and character.unemployment_start_date == null and character.job_offer_cooldown_until == null, "Successful acceptance clears only canonical pending/unemployment offer state")
	_assert(accepted_offers.size() == 1 and accepted_offers[0].previous_job_id == null and accepted_offers[0].previous_company_id == null and int(accepted_offers[0].previous_salary) == 0, "Acceptance domain signal preserves canonical unemployed previous values")
	_assert(started.size() == 1 and _semantic("job_changed").is_empty() and _context_matches(started[0], {"character_id":1,"job_id":offer.job_id,"company_id":offer.company_id,"salary":offer.salary}), "Unemployed acceptance dispatches job_started once and never job_changed")
	_assert(String(started[0].occurrence_id) == "job_started:1:%d:%s:1985-01-26" % [int(offer.job_id), String(offer.company_id)] and EventManager.active_event != null and EventManager.active_event.event_id == "phase5b_started" and int(EventManager.active_event.participants.primary) == 1, "job_started uses stable identity and primary Character binding")
	var second := CareerManager.accept_job_offer(1)
	_assert(not second and accepted_offers.size() == 1 and _semantic("job_started").size() == 1, "A consumed offer cannot be accepted or dispatched twice")
	EventManager.cancel_active_event()


func _test_employed_acceptance_dispatches_job_changed() -> void:
	var character := _graduate()
	character.job_id = 2076
	character.company_id = "central_city_administration"
	character.salary = 5600
	character.unemployment_start_date = null
	_setup_world(character, [_system_event("phase5b_started", "job_started"), _system_event("phase5b_changed", "job_changed")])
	var offer := _first_advancement_offer(character)
	var previous := {"job_id":character.job_id,"company_id":character.company_id,"salary":character.salary}
	CareerManager.request_job_offer(character, offer)
	_clear_captures()
	var accepted := CareerManager.accept_job_offer(1)
	var changed := _semantic("job_changed")
	_assert(accepted and character.job_id == offer.job_id and character.company_id == offer.company_id and character.salary == offer.salary and int(character.salary) > int(previous.salary), "Employed acceptance applies one valid higher-salary different-Job offer")
	_assert(accepted_offers.size() == 1 and accepted_offers[0].previous_job_id == previous.job_id and accepted_offers[0].previous_company_id == previous.company_id and accepted_offers[0].previous_salary == previous.salary, "Acceptance domain signal captures previous employment before mutation")
	_assert(changed.size() == 1 and _semantic("job_started").is_empty() and _context_matches(changed[0], {"character_id":1,"previous_job_id":previous.job_id,"previous_company_id":previous.company_id,"previous_salary":previous.salary,"job_id":offer.job_id,"company_id":offer.company_id,"salary":offer.salary}), "Employed acceptance dispatches job_changed once with complete old/new context")
	_assert(String(changed[0].occurrence_id) == "job_changed:1:%d:%s:%d:%s:1985-01-26" % [int(previous.job_id), String(previous.company_id), int(offer.job_id), String(offer.company_id)] and EventManager.active_event != null and EventManager.active_event.event_id == "phase5b_changed", "job_changed uses stable old/new identity and queues only its matching Event")
	EventManager.cancel_active_event()


func _test_failed_acceptance_dispatches_nothing() -> void:
	var character := _graduate()
	_setup_world(character, [_system_event("phase5b_started", "job_started"), _system_event("phase5b_changed", "job_changed")])
	var offer := _first_unemployed_offer(character)
	CareerManager.request_job_offer(character, offer)
	CareerManager.active_job_offers[1]["salary"] = int(offer.salary) + 1
	_clear_captures()
	var accepted := CareerManager.accept_job_offer(1)
	_assert(not accepted and character.job_id == null and CareerManager.get_active_job_offer(1).is_empty(), "Tampered active offer fails canonical validation and is removed")
	_assert(accepted_offers.is_empty() and _semantic("job_started").is_empty() and _semantic("job_changed").is_empty() and EventManager.active_event == null, "Failed acceptance emits no acceptance domain signal or Career semantic Event")
	_assert(not CareerManager.accept_job_offer(999) and accepted_offers.is_empty(), "Missing Character acceptance also emits nothing")


func _test_rejection_remains_authoritative_without_semantic_trigger() -> void:
	var character := _graduate()
	_setup_world(character, [_system_event("phase5b_started", "job_started"), _system_event("phase5b_changed", "job_changed"), _system_event("phase5b_lost", "job_lost")])
	var offer := _first_unemployed_offer(character)
	CareerManager.request_job_offer(character, offer)
	_clear_captures()
	var rejected := CareerManager.reject_job_offer(1)
	_assert(rejected and CareerManager.get_active_job_offer(1).is_empty() and character.job_id == null and character.company_id == null and int(character.salary) == 0, "CareerManager rejection clears only the active offer and leaves employment unchanged")
	_assert(accepted_offers.is_empty() and removed_jobs.is_empty() and _career_semantics().is_empty() and EventManager.active_event == null, "Rejection invents no Career semantic trigger")
	_assert(not CareerManager.reject_job_offer(1) and _career_semantics().is_empty(), "An already-consumed rejection cannot mutate or dispatch twice")


func _test_external_job_removal_dispatches_job_lost() -> void:
	var character := _employed_graduate()
	_setup_world(character, [_system_event("phase5b_lost", "job_lost")])
	CareerManager.active_job_offers[1] = {"job_id":2077,"company_id":"central_city_administration","salary":6000}
	var previous := {"job_id":character.job_id,"company_id":character.company_id,"salary":character.salary}
	var removed := CareerManager.remove_external_job(1)
	var lost := _semantic("job_lost")
	_assert(removed and character.job_id == null and character.company_id == null and int(character.salary) == 0 and character.unemployment_start_date == "1985-01-26" and character.job_offer_cooldown_until == null, "External job removal clears canonical Career state and starts unemployment on the current date")
	_assert(CareerManager.get_active_job_offer(1).is_empty(), "External job removal clears the same Character's pending offer")
	_assert(removed_jobs.size() == 1 and _dictionary_matches(removed_jobs[0], {"character_id":1,"previous_job_id":previous.job_id,"previous_company_id":previous.company_id,"previous_salary":previous.salary}), "Removal domain signal captures pre-mutation external employment")
	_assert(lost.size() == 1 and _context_matches(lost[0], {"character_id":1,"previous_job_id":previous.job_id,"previous_company_id":previous.company_id,"previous_salary":previous.salary}), "Successful removal dispatches one job_lost occurrence with canonical prior context")
	_assert(String(lost[0].occurrence_id) == "job_lost:1:%d:%s:1985-01-26" % [int(previous.job_id), String(previous.company_id)] and EventManager.active_event != null and EventManager.active_event.event_id == "phase5b_lost" and int(EventManager.active_event.participants.primary) == 1, "job_lost uses stable identity and primary Character binding")
	EventManager.cancel_active_event()


func _test_failed_job_removal_dispatches_nothing() -> void:
	_setup_world(_graduate(), [_system_event("phase5b_lost", "job_lost")])
	var removed := CareerManager.remove_external_job(1)
	_assert(not removed and removed_jobs.is_empty() and _semantic("job_lost").is_empty() and EventManager.active_event == null, "Already-unemployed removal emits no domain signal or job_lost Event")
	_assert(not CareerManager.remove_external_job(999) and removed_jobs.is_empty(), "Missing Character removal emits nothing")


func _test_family_business_isolation() -> void:
	var character := _graduate()
	_setup_world(character, [_system_event("phase5b_lost", "job_lost")])
	BusinessManager.businesses = [{"business_instance_id":"phase5b_business","slots":[{"slot_id":"slot_1","assigned_character_id":1,"assigned_npc_id":null}]}]
	CareerManager.check_unemployed_character_offer(character)
	_assert(CareerManager.is_character_assigned_to_family_business(1) and CareerManager.active_job_offers.is_empty() and requested_offers.is_empty(), "Family Business-assigned Character remains excluded before external-offer generation")
	character.job_id = 2076
	character.company_id = "central_city_administration"
	character.salary = 5600
	var removed := CareerManager.remove_external_job(1)
	var assignment := BusinessManager.get_character_assignment(1)
	_assert(removed and String(assignment.get("business_instance_id", "")) == "phase5b_business" and String(assignment.get("slot_id", "")) == "slot_1", "External job removal and job_lost adapter preserve the Family Business slot")
	_assert(EventManager.active_event != null and EventManager.active_event.event_id == "phase5b_lost" and BusinessManager.businesses.size() == 1, "job_lost queues without assigning or removing any Business slot")
	EventManager.cancel_active_event()


func _test_salary_increase_remains_narrow() -> void:
	var character := _employed_graduate()
	_setup_world(character, [_system_event("phase5b_started", "job_started"), _system_event("phase5b_changed", "job_changed"), _system_event("phase5b_lost", "job_lost")])
	var job_id = character.job_id
	var company_id = character.company_id
	var before := int(character.salary)
	var increased := CareerManager.increase_external_salary(1, 400)
	var rejected_zero := not CareerManager.increase_external_salary(1, 0)
	_assert(increased and rejected_zero and character.job_id == job_id and character.company_id == company_id and int(character.salary) == before + 400, "Positive salary increase applies once while preserving Job and Company")
	_assert(not character.has("career_level") and not character.has("career_xp") and _career_semantics().is_empty() and EventManager.active_event == null, "Narrative promotion adds no Career Level/XP or unapproved semantic trigger")


func _test_save_load_without_semantic_replay() -> void:
	var character := _graduate()
	_setup_world(character, [_system_event("phase5b_offer", "job_offer_requested")])
	var offer := _first_unemployed_offer(character)
	CareerManager.request_job_offer(character, offer)
	var active_instance_id := EventManager.active_event.instance_id
	var offer_snapshot = JSON.parse_string(JSON.stringify(SaveManager.create_save_snapshot()))
	CareerManager.active_job_offers.clear()
	EventManager.reset_runtime_state()
	_clear_captures()
	var offer_loaded := SaveManager.apply_save_snapshot(offer_snapshot)
	var restored_offer := CareerManager.get_active_job_offer(1)
	_assert(offer_loaded and int(offer_snapshot.save_version) == 6 and int(SaveManager.SAVE_VERSION) == 6 and int(restored_offer.get("job_id", -1)) == int(offer.job_id) and String(restored_offer.get("company_id", "")) == String(offer.company_id) and int(restored_offer.get("salary", -1)) == int(offer.salary), "Version 6 save/load restores the existing active_job_offers record")
	_assert(EventManager.active_event != null and EventManager.active_event.instance_id == active_instance_id and EventManager.active_event.event_id == "phase5b_offer", "Career offer Event persistence restores through the separate Phase 4B Event state")
	_assert(_career_semantics().is_empty() and requested_offers.is_empty() and accepted_offers.is_empty() and removed_jobs.is_empty(), "Active-offer deserialization replays no Career domain or semantic signal")

	character = _employed_graduate()
	_setup_world(character)
	var employment_snapshot = JSON.parse_string(JSON.stringify(SaveManager.create_save_snapshot()))
	character.job_id = null
	character.company_id = null
	character.salary = 0
	_clear_captures()
	var employment_loaded := SaveManager.apply_save_snapshot(employment_snapshot)
	var restored := CharacterManager.get_character_by_id(1)
	_assert(employment_loaded and restored.job_id == 2076 and restored.company_id == "central_city_administration" and int(restored.salary) == 5600, "Accepted external employment survives save/load")
	_assert(_semantic("job_started").is_empty() and _semantic("job_changed").is_empty(), "Employment deserialization emits neither job_started nor job_changed")

	character = _employed_graduate()
	_setup_world(character)
	CareerManager.remove_external_job(1)
	var removed_snapshot = JSON.parse_string(JSON.stringify(SaveManager.create_save_snapshot()))
	character.job_id = 2076
	character.company_id = "central_city_administration"
	character.salary = 5600
	character.unemployment_start_date = null
	_clear_captures()
	var removed_loaded := SaveManager.apply_save_snapshot(removed_snapshot)
	restored = CharacterManager.get_character_by_id(1)
	_assert(removed_loaded and restored.job_id == null and restored.company_id == null and int(restored.salary) == 0 and restored.unemployment_start_date == "1985-01-26", "Removed-job unemployment state survives save/load")
	_assert(_semantic("job_lost").is_empty() and removed_jobs.is_empty(), "Unemployment deserialization replays no job_lost operation")


func _test_nested_event_acceptance_queues_one_follow_up() -> void:
	var character := _graduate()
	var source := _chain_event("phase5b_accept_source", [{"type":"accept_job_offer","target":"primary"}])
	var follow_up := _system_event("phase5b_started_follow_up", "job_started")
	_setup_world(character, [source, follow_up])
	var offer := _first_unemployed_offer(character)
	CareerManager.request_job_offer(character, offer)
	_clear_captures()
	var activated := EventManager.activate_chain(source.event_id, {"primary":1})
	var source_instance_id := EventManager.active_event.instance_id if EventManager.active_event != null else ""
	var result := EventManager.resolve_active_event("continue")
	_assert(bool(activated.get("queued", false)) and bool(result.get("resolved", false)) and result.effect_results.size() == 1 and bool(result.effect_results[0].success), "Nested Job Offer Event delegates acceptance through the existing effect resolver")
	_assert(character.job_id == offer.job_id and character.company_id == offer.company_id and character.salary == offer.salary and CareerManager.get_active_job_offer(1).is_empty(), "Nested acceptance mutates canonical Career state exactly once")
	_assert(accepted_offers.size() == 1 and _semantic("job_started").size() == 1 and _semantic("job_changed").is_empty(), "Nested acceptance emits exactly one correct follow-up semantic occurrence")
	_assert(EventManager.active_event != null and EventManager.active_event.event_id == "phase5b_started_follow_up" and EventManager.queued_events.is_empty(), "Follow-up Event waits in the ordinary queue until the source Event completes")
	var source_completions := 0
	for completed in completed_events:
		if String(completed.get("instance_id", "")) == source_instance_id:
			source_completions += 1
	_assert(source_completions == 1 and int(character.salary) == int(offer.salary), "Source Job Offer Event resolves once without duplicate acceptance or salary mutation")
	EventManager.cancel_active_event()


func _setup_world(character: Dictionary, events: Array = []) -> void:
	SaveManager.current_save_id = -1
	CharacterManager.characters = [character]
	CharacterManager.next_character_id = 2
	CareerManager.active_job_offers.clear()
	BusinessManager.businesses = []
	GameManager.family_money = 50000
	TimeManager.current_year = 1985
	TimeManager.current_month = 1
	TimeManager.current_day = 26
	TimeManager.speed_multiplier = 2.0
	TimeManager.is_paused = false
	TimeManager.day_timer = 0.0
	_configure(events)
	_clear_captures()


func _configure(events: Array) -> void:
	var registry := EventDataRegistry.new()
	var loaded := registry.load_from_json_sources({"career.json":JSON.stringify({"schema_version":1,"category":"career","pools":[],"events":events})})
	_assert(loaded, "Phase 5B fixture registry validates", registry.get_diagnostic_text())
	EventManager.configure_runtime(registry, null, 52)


func _system_event(event_id: String, semantic_event: String) -> Dictionary:
	return {"event_id":event_id,"category":"career","domain":"career","subtype":"phase5b_fixture","enabled":true,"rarity":"common","weight":1.0,"priority":0,"exclusive_group":null,"trigger":{"type":"system","event":semantic_event},"participants":{"primary":{"type":"character","source":"trigger"}},"requirements":{"all":[]},"repeat":{"mode":"repeatable"},"cooldown":null,"behavior":{"blocking":false,"pause_game":false},"content":{"title":event_id,"description":"Phase 5B fixture"},"presentation":{"template":"standard_event"},"choices":[{"choice_id":"continue","title":"Continue","requirements":{"all":[]},"resolution":{"mode":"deterministic","effects":[]}}]}


func _chain_event(event_id: String, effects: Array) -> Dictionary:
	var event := _system_event(event_id, "")
	event.trigger = {"type":"chain"}
	event.choices[0].resolution.effects = effects
	return event


func _graduate() -> Dictionary:
	return {"character_id":1,"character_type":"family","linked_character_id":null,"first_name":"Career","last_name":"Adapter","gender":"female","birth_date":"1960-01-01","life_stage":"young_adult","is_alive":true,"is_player_family":true,"parent_ids":[],"children_ids":[],"partner_id":null,"relationship_cooldown_until":null,"flag_ids":[],"health":100,"happiness":100,"logic":100,"attractiveness":100,"social":100,"confidence":100,"discipline":100,"creativity":100,"job_id":null,"company_id":null,"salary":0,"school_id":4001,"major_id":5014,"education_status":"graduated","education_start_date":"1978-01-01","major_selection_date":"1981-01-01","expected_graduation_date":"1982-01-01","graduation_date":"1982-01-01","unemployment_start_date":"1982-01-01","job_offer_cooldown_until":null,"event_log":[],"is_retired":false,"last_salary":0,"pension":0,"avatar_theme":"default","genetics":{"skin_tone":"light"},"portrait_variant_id":"","portrait_path":"res://Resources/Characters/default_avatar.png"}


func _employed_graduate() -> Dictionary:
	var character := _graduate()
	character.job_id = 2076
	character.company_id = "central_city_administration"
	character.salary = 5600
	character.unemployment_start_date = null
	return character


func _first_unemployed_offer(character: Dictionary) -> Dictionary:
	var pool := CareerManager.get_unemployed_offer_pool(character)
	return pool[0] if not pool.is_empty() and typeof(pool[0]) == TYPE_DICTIONARY else {}


func _first_advancement_offer(character: Dictionary) -> Dictionary:
	var pool := CareerManager.get_employed_advancement_offer_pool(character)
	return pool[0] if not pool.is_empty() and typeof(pool[0]) == TYPE_DICTIONARY else {}


func _semantic(name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for occurrence in semantic_occurrences:
		if String(occurrence.get("semantic_event", "")) == name:
			result.append(occurrence)
	return result


func _career_semantics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for name in ["job_offer_requested", "job_started", "job_changed", "job_lost"]:
		result.append_array(_semantic(name))
	return result


func _context_matches(occurrence: Dictionary, expected: Dictionary) -> bool:
	var context = occurrence.get("context", {})
	return typeof(context) == TYPE_DICTIONARY and _dictionary_matches(context, expected)


func _dictionary_matches(actual: Dictionary, expected: Dictionary) -> bool:
	for key in expected:
		if actual.get(key, null) != expected[key]:
			return false
	return true


func _clear_captures() -> void:
	semantic_occurrences.clear()
	requested_offers.clear()
	accepted_offers.clear()
	removed_jobs.clear()
	completed_events.clear()


func _connect_capture_signals() -> void:
	EventManager.semantic_trigger_dispatched.connect(_on_semantic_trigger_dispatched)
	EventManager.event_completed.connect(_on_event_completed)
	CareerManager.job_offer_requested.connect(_on_job_offer_requested)
	CareerManager.job_offer_accepted.connect(_on_job_offer_accepted)
	CareerManager.external_job_removed.connect(_on_external_job_removed)


func _disconnect_capture_signals() -> void:
	EventManager.semantic_trigger_dispatched.disconnect(_on_semantic_trigger_dispatched)
	EventManager.event_completed.disconnect(_on_event_completed)
	CareerManager.job_offer_requested.disconnect(_on_job_offer_requested)
	CareerManager.job_offer_accepted.disconnect(_on_job_offer_accepted)
	CareerManager.external_job_removed.disconnect(_on_external_job_removed)


func _on_semantic_trigger_dispatched(occurrence: Dictionary) -> void:
	semantic_occurrences.append(occurrence.duplicate(true))


func _on_event_completed(instance: Dictionary) -> void:
	completed_events.append(instance.duplicate(true))


func _on_job_offer_requested(character_id: int, job_id: int, company_id: String, salary: int) -> void:
	var stored := CareerManager.get_active_job_offer(character_id)
	requested_offers.append({"character_id":character_id,"job_id":job_id,"company_id":company_id,"salary":salary,"stored_when_emitted":stored == {"job_id":job_id,"company_id":company_id,"salary":salary}})


func _on_job_offer_accepted(character_id: int, previous_job_id, previous_company_id, previous_salary: int, job_id: int, company_id: String, salary: int) -> void:
	accepted_offers.append({"character_id":character_id,"previous_job_id":previous_job_id,"previous_company_id":previous_company_id,"previous_salary":previous_salary,"job_id":job_id,"company_id":company_id,"salary":salary})


func _on_external_job_removed(character_id: int, previous_job_id: int, previous_company_id: String, previous_salary: int) -> void:
	removed_jobs.append({"character_id":character_id,"previous_job_id":previous_job_id,"previous_company_id":previous_company_id,"previous_salary":previous_salary})


func _assert(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty():
			print(detail)
