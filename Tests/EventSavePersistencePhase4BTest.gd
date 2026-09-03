extends Node


const TEST_SAVE_DIRECTORY := "user://event_phase4b_persistence_test"
const TEST_SAVE_ID := 46001
const ITEM_ID := "accessory_common_black_gold_browline_sunglasses_007"
const FLAG_ID := 1001

var passed := 0
var failed := 0
var original_snapshot: Dictionary = {}
var original_registry: EventDataRegistry
var original_save_directory := ""
var original_save_id := -1


func _ready() -> void:
	original_registry = EventManager.registry
	original_snapshot = SaveManager.create_save_snapshot()
	original_save_directory = SaveManager.save_directory
	original_save_id = SaveManager.current_save_id
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.current_save_id = -1
	_cleanup_test_saves()

	_test_schema_empty_migration_and_corruption()
	_test_disk_round_trip_without_effect_replay()
	_test_active_blocking_and_queue_round_trip()
	_test_history_repeat_and_cooldown_round_trip()
	_test_schedule_counters_ledgers_and_rng_round_trip()
	_test_flag_persistence_and_new_game_reset()

	EventManager.configure_runtime(original_registry)
	SaveManager.apply_save_snapshot(original_snapshot)
	SaveManager.save_directory = original_save_directory
	SaveManager.current_save_id = original_save_id
	_cleanup_test_saves()

	print("========================================")
	print("Event Phase 4B persistence tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_schema_empty_migration_and_corruption() -> void:
	_setup_domain_state()
	_configure([])
	var empty_snapshot := SaveManager.create_save_snapshot()
	_assert(int(empty_snapshot.get("save_version", 0)) == 6 and typeof(empty_snapshot.get("event_system", null)) == TYPE_DICTIONARY, "Save version 6 stores one canonical event_system payload")
	var serialized = JSON.parse_string(JSON.stringify(empty_snapshot["event_system"]))
	_assert(typeof(serialized) == TYPE_DICTIONARY and EventManager.import_runtime_state(serialized), "Complete Event export is JSON-compatible", EventManager.last_import_error)
	_assert(SaveManager.apply_save_snapshot(JSON.parse_string(JSON.stringify(empty_snapshot))) and _event_state_is_empty(), "Empty Event state survives a complete snapshot round trip")

	var v5_snapshot := empty_snapshot.duplicate(true)
	v5_snapshot["save_version"] = 5
	v5_snapshot.erase("event_system")
	v5_snapshot["game_manager"]["family_money"] = 43210
	EventManager.state_provider.completed_repeat_records.append({"event_id":"stale","mode":"once","repeat_key":"stale|once","completed_date":"2000-01-01"})
	_assert(SaveManager.apply_save_snapshot(v5_snapshot) and GameManager.family_money == 43210 and _event_state_is_empty(), "Version 5 migrates existing gameplay with a clean Event runtime")
	_assert(int(SaveManager.create_save_snapshot().get("save_version", 0)) == 6, "A migrated game writes the current version 6 schema")
	_assert(_write_snapshot(TEST_SAVE_ID + 1, v5_snapshot), "Representative version 5 fixture writes to the real save path")
	GameManager.family_money = 1
	EventManager.story_history.records.append({"instance_id":"stale","event_id":"stale","status":"completed"})
	_assert(SaveManager.load_game(TEST_SAVE_ID + 1) and GameManager.family_money == 43210 and _event_state_is_empty(), "Representative version 5 save loads with gameplay preserved and clean Event state")

	var missing_snapshot := empty_snapshot.duplicate(true)
	missing_snapshot.erase("event_system")
	EventManager.story_history.records.append({"instance_id":"stale","event_id":"stale","status":"completed"})
	_assert(SaveManager.apply_save_snapshot(missing_snapshot) and _event_state_is_empty(), "A version 6 save missing event_system recovers with empty Event state")

	var wrong_root := empty_snapshot.duplicate(true)
	wrong_root["event_system"] = []
	GameManager.family_money = 1
	_assert(SaveManager.apply_save_snapshot(wrong_root) and GameManager.family_money == int(empty_snapshot.game_manager.family_money) and _event_state_is_empty(), "Wrong Event root type resets only Event state and preserves loaded gameplay")

	var bad_counter := empty_snapshot.duplicate(true)
	bad_counter["event_system"]["next_event_instance_number"] = "invalid"
	_assert(SaveManager.apply_save_snapshot(bad_counter) and _event_state_is_empty() and EventManager.last_import_error.contains("next_event_instance_number"), "Invalid Event counter is rejected with a diagnostic and safe reset")

	var active := _event("corrupt_active")
	_configure([active])
	EventManager.activate_chain(active.event_id, {"primary":1})
	var bad_instance := SaveManager.create_save_snapshot()
	bad_instance["event_system"]["active_event"]["participants"] = []
	_assert(SaveManager.apply_save_snapshot(bad_instance) and _event_state_is_empty() and EventManager.last_import_error.contains("participant"), "Malformed EventInstance executes nothing and resets the Event subsection")

	_configure([active])
	EventManager.activate_chain(active.event_id, {"primary":1})
	var missing_definition := SaveManager.create_save_snapshot()
	_configure([])
	_assert(SaveManager.apply_save_snapshot(missing_definition) and _event_state_is_empty() and EventManager.last_import_error.contains("missing definition"), "Missing active definition is rejected without substitution or effect execution")


func _test_disk_round_trip_without_effect_replay() -> void:
	_setup_domain_state()
	var effect_event := _event("no_replay", [
		{"type":"stat_change","target":"primary","stat":"health","amount":7},
		{"type":"money_change","amount":125},
		{"type":"add_item","target":"primary","item_id":ITEM_ID},
		{"type":"salary_increase","target":"primary","amount":300},
	])
	_configure([effect_event])
	GameManager.family_money = 1000
	CharacterManager.characters[0].health = 50
	CharacterManager.characters[0].merge({"job_id":1001,"company_id":"metro_works_services","salary":2000}, true)
	EventManager.activate_chain(effect_event.event_id, {"primary":1}, {"token":"saved"})
	var resolution := EventManager.resolve_active_event("continue")
	_assert(resolution.resolved, "Representative stat, money, Item, and salary effects resolve before save")
	var saved_health := int(CharacterManager.characters[0].health)
	var saved_money := GameManager.family_money
	var saved_salary := int(CharacterManager.characters[0].salary)
	var saved_items := ItemManager.family_inventory.size()
	var saved_history := EventManager.story_history.records.size()
	_assert(SaveManager.save_game(TEST_SAVE_ID), "Version 6 Event state writes through the real SaveManager file path")

	CharacterManager.characters[0].health = 1
	GameManager.family_money = 1
	CharacterManager.characters[0].salary = 1
	ItemManager.family_inventory.clear()
	EventManager.reset_runtime_state()
	_assert(SaveManager.load_game(TEST_SAVE_ID), "Version 6 Event state loads through the real SaveManager file path")
	SaveManager.current_save_id = -1
	_assert(int(CharacterManager.characters[0].health) == saved_health and GameManager.family_money == saved_money, "Load restores stat and money exactly once without replay")
	_assert(int(CharacterManager.characters[0].salary) == saved_salary, "Authoritative Career salary effect is not replayed")
	_assert(ItemManager.family_inventory.size() == saved_items, "Item creation effect is not replayed or duplicated")
	_assert(EventManager.story_history.records.size() == saved_history and EventManager.story_history.has_completed(effect_event.event_id, {"primary":1}, {"token":"saved"}), "Completed history restores without executing historical effects")


func _test_active_blocking_and_queue_round_trip() -> void:
	for speed in [1.0, 2.0, 3.0]:
		_setup_domain_state()
		var active := _event("active_speed_%d" % int(speed))
		_configure([active])
		TimeManager.is_paused = false
		TimeManager.speed_multiplier = speed
		var activated := EventManager.activate_chain(active.event_id, {"primary":1}, {"speed":speed}, null, "speed_%d" % int(speed))
		var instance_id := String(activated.instance.instance_id)
		var snapshot := _json_snapshot()
		_assert(SaveManager.apply_save_snapshot(snapshot), "Active blocking x%d snapshot imports" % int(speed))
		_assert(EventManager.active_event != null and EventManager.active_event.instance_id == instance_id and EventManager.active_event.status == "active" and EventManager.active_event.context.speed == speed and TimeManager.is_paused, "Active blocking x%d Event restores the same bound instance while paused" % int(speed))
		EventManager.resolve_active_event("continue")
		_assert(not TimeManager.is_paused and is_equal_approx(TimeManager.speed_multiplier, speed), "Completing restored Event resumes exact x%d state" % int(speed))

	_setup_domain_state()
	var paused_event := _event("active_manual_pause")
	_configure([paused_event])
	TimeManager.is_paused = true
	TimeManager.speed_multiplier = 3.0
	EventManager.activate_chain(paused_event.event_id, {"primary":1})
	_assert(SaveManager.apply_save_snapshot(_json_snapshot()) and EventManager.active_event != null and TimeManager.is_paused, "Manually paused active Event restores as active and paused")
	EventManager.resolve_active_event("continue")
	_assert(TimeManager.is_paused and is_equal_approx(TimeManager.speed_multiplier, 3.0), "Completing restored Event preserves manual pause")

	_setup_domain_state()
	var first := _event("queue_first"); first.priority = 10
	var second := _event("queue_second"); second.priority = 5
	_configure([first, second])
	TimeManager.is_paused = false
	TimeManager.speed_multiplier = 2.0
	EventManager.activate_chain(first.event_id, {"primary":1}, {"order":"a"}, null, "queue_a")
	EventManager.activate_chain(second.event_id, {"primary":1}, {"order":"b"}, null, "queue_b")
	var first_id := EventManager.active_event.instance_id
	var second_id := EventManager.queued_events[0].instance_id
	_assert(SaveManager.apply_save_snapshot(_json_snapshot()) and EventManager.active_event.instance_id == first_id and EventManager.queued_events[0].instance_id == second_id, "Active A and queued B retain stable IDs and order")
	EventManager.resolve_active_event("continue")
	_assert(EventManager.active_event != null and EventManager.active_event.instance_id == second_id and TimeManager.is_paused, "Queued B activates without resuming simulation between blocking Events")
	EventManager.resolve_active_event("continue")
	_assert(EventManager.active_event == null and not TimeManager.is_paused and is_equal_approx(TimeManager.speed_multiplier, 2.0), "Queue completion restores the original x2 state")


func _test_history_repeat_and_cooldown_round_trip() -> void:
	_setup_domain_state()
	var history := _pair_event("history_weighted")
	history.choices[0].resolution = {"mode":"weighted","outcomes":[{"outcome_id":"remembered","weight":1.0,"effects":[]}]}
	var repeat_modes := ["once", "once_per_character", "once_per_character_pair", "once_per_family", "once_per_house", "once_per_business"]
	var repeat_events: Array = []
	for mode in repeat_modes:
		var event := _pair_event("repeat_%s" % mode) if mode == "once_per_character_pair" else _event("repeat_%s" % mode)
		event.repeat = {"mode":mode}
		repeat_events.append(event)
	var cooldown_scopes := ["event", "character", "character_pair", "family", "house", "business"]
	var cooldown_events: Array = []
	for scope in cooldown_scopes:
		var event := _pair_event("cooldown_%s" % scope) if scope == "character_pair" else _event("cooldown_%s" % scope)
		event.cooldown = {"scope":scope,"unit":"month","value":1}
		cooldown_events.append(event)
	var all_events := [history]
	all_events.append_array(repeat_events)
	all_events.append_array(cooldown_events)
	_configure(all_events)

	var pair := {"primary":1,"target":2}
	var context := {"house_instance_id":"house_0001","business_instance_id":"business_0001","story":"bound"}
	EventManager.activate_chain(history.event_id, pair, context)
	EventManager.resolve_active_event("continue")
	var bindings_by_id: Dictionary = {}
	for event in repeat_events + cooldown_events:
		var bindings := pair if String(event.event_id).contains("character_pair") else {"primary":1}
		bindings_by_id[event.event_id] = bindings
		EventManager.activate_chain(event.event_id, bindings, context, null, "complete_%s" % event.event_id)
		EventManager.resolve_active_event("continue")
	_assert(SaveManager.apply_save_snapshot(_json_snapshot()), "History, repeat, and cooldown snapshot imports")

	var evaluator := EventManager.runtime_service.requirement_evaluator
	var story_requirements := {"all":[
		{"type":"event_seen","operator":"==","value":history.event_id},
		{"type":"event_completed","operator":"==","value":history.event_id},
		{"type":"event_not_completed","operator":"==","value":"never_completed"},
		{"type":"choice_made","operator":"==","value":{"event_id":history.event_id,"choice_id":"continue"}},
		{"type":"outcome_reached","operator":"==","value":{"event_id":history.event_id,"outcome_id":"remembered"}},
	]}
	_assert(bool(evaluator.evaluate(story_requirements, pair, context).eligible), "All five story-history queries remain true after load")
	_assert(not EventManager.story_history.has_completed(history.event_id, {"primary":3}, context), "History remains distinguishable for another Character")
	_assert(EventManager.story_history.has_completed(history.event_id, {"primary":1,"target":2}, context) and not EventManager.story_history.has_completed(history.event_id, {"primary":1,"target":3}, context), "Participant pair and House/Business context remain bound")

	for event in repeat_events:
		var bindings: Dictionary = bindings_by_id[event.event_id]
		_assert(EventManager.state_provider.is_completed_non_repeatable(event, bindings, context), "Repeat mode %s remains consumed after load" % event.repeat.mode)
	matchable_repeat_scope_checks(repeat_events, context)

	for event in cooldown_events:
		var bindings: Dictionary = bindings_by_id[event.event_id]
		var record := _cooldown_record(event.event_id)
		TimeManager.current_year = 2000; TimeManager.current_month = 1; TimeManager.current_day = 31
		_assert(EventManager.state_provider.is_on_cooldown(event, bindings, context), "Cooldown scope %s remains locked before expiry" % event.cooldown.scope)
		_set_date(String(record.available_date))
		_assert(not EventManager.state_provider.is_on_cooldown(event, bindings, context), "Cooldown scope %s opens exactly at saved expiry" % event.cooldown.scope)


func matchable_repeat_scope_checks(events: Array, context: Dictionary) -> void:
	var by_mode: Dictionary = {}
	for event in events: by_mode[String(event.repeat.mode)] = event
	_assert(not EventManager.state_provider.is_completed_non_repeatable(by_mode.once_per_character, {"primary":2}, context), "once_per_character leaves another Character eligible")
	_assert(not EventManager.state_provider.is_completed_non_repeatable(by_mode.once_per_character_pair, {"primary":1,"target":3}, context), "once_per_character_pair leaves another normalized pair eligible")
	var other_house := context.duplicate(true); other_house.house_instance_id = "house_0002"
	_assert(not EventManager.state_provider.is_completed_non_repeatable(by_mode.once_per_house, {"primary":1}, other_house), "once_per_house leaves another House eligible")
	var other_business := context.duplicate(true); other_business.business_instance_id = "business_0002"
	_assert(not EventManager.state_provider.is_completed_non_repeatable(by_mode.once_per_business, {"primary":1}, other_business), "once_per_business leaves another Business eligible")


func _test_schedule_counters_ledgers_and_rng_round_trip() -> void:
	_setup_domain_state()
	var scheduled := _event("scheduled_valid"); scheduled.trigger = {"type":"scheduled"}
	var scheduled_locked := _event("scheduled_locked"); scheduled_locked.trigger = {"type":"scheduled"}; scheduled_locked.requirements = {"all":[{"type":"money","operator":">=","value":999999}]}
	var system_event := _event("semantic_once"); system_event.trigger = {"type":"system","event":"phase4b_semantic"}
	var chain := _event("counter_chain")
	var weighted := _event("rng_weighted")
	weighted.choices[0].resolution = {"mode":"weighted","outcomes":[{"outcome_id":"a","weight":1.0,"effects":[]},{"outcome_id":"b","weight":1.0,"effects":[]}]}
	_configure([scheduled, scheduled_locked, system_event, chain, weighted], 2468)
	var due_date := "2000-02-01"
	var first_schedule := EventManager.schedule_event(scheduled.event_id, due_date, {"primary":1}, {"token":"kept"}, "evt_source")
	var cancelled := EventManager.schedule_event(scheduled.event_id, "2000-03-01", {"primary":1}, {"token":"cancelled"}, "evt_source")
	EventManager.cancel_scheduled_event(cancelled.scheduled_event_id)
	var invalid := EventManager.schedule_event(scheduled_locked.event_id, due_date, {"primary":1}, {"token":"invalid"}, "evt_source")
	var system_context := {"trigger_character_id":1,"trigger_participants":{"primary":1},"context":{"semantic":"kept"}}
	EventManager.dispatch_system_trigger("phase4b_semantic", system_context, "semantic_occurrence", "test")
	EventManager.resolve_active_event("continue")
	EventManager.activate_chain(weighted.event_id, {"primary":1}, {}, null, "weighted_first")
	EventManager.resolve_active_event("continue")
	var before := EventManager.export_runtime_state()
	var expected_next_event := int(before.next_event_instance_number)
	var expected_next_schedule := int(before.next_scheduled_event_number)
	_assert(SaveManager.apply_save_snapshot(_json_snapshot()), "Schedules, counters, ledgers, and RNG snapshot imports")
	var after := EventManager.export_runtime_state()
	_assert(after.pool_random_state == before.pool_random_state and after.resolution_random_state == before.resolution_random_state, "Pool and resolution RNG streams continue from saved state", JSON.stringify({"before_pool":before.pool_random_state,"after_pool":after.pool_random_state,"before_resolution":before.resolution_random_state,"after_resolution":after.resolution_random_state}))
	_assert(after.processed_selection_occurrences == before.processed_selection_occurrences and after.calendar_occurrence_keys == before.calendar_occurrence_keys, "Selection and calendar occurrence ledgers survive load")
	var duplicate := EventManager.dispatch_system_trigger("phase4b_semantic", system_context, "semantic_occurrence", "test")
	_assert(bool(duplicate.get("duplicate_occurrence", false)) and EventManager.active_event == null, "Same semantic occurrence cannot queue twice after load")

	var new_chain := EventManager.activate_chain(chain.event_id, {"primary":1}, {}, null, "counter_after_load")
	_assert(String(new_chain.instance.instance_id) == "evt_%08d" % expected_next_event, "EventInstance counter continues without collision")
	EventManager.cancel_active_event()
	var new_schedule := EventManager.schedule_event(scheduled.event_id, "2000-04-01", {"primary":1})
	_assert(String(new_schedule.scheduled_event_id) == "sched_%08d" % expected_next_schedule, "ScheduledEvent counter continues without collision")

	var restored := EventManager.get_scheduled_events()
	_assert(_scheduled_record(restored, first_schedule.scheduled_event_id).source_instance_id == "evt_source" and _scheduled_record(restored, first_schedule.scheduled_event_id).context.token == "kept" and _scheduled_record(restored, first_schedule.scheduled_event_id).due_date == due_date, "Scheduled identity, due date, source, participants, and context are preserved")
	_assert(_scheduled_record(restored, cancelled.scheduled_event_id).status == "cancelled", "Scheduled cancellation persists across load")
	_assert(EventManager.process_scheduled_due("2000-01-31").is_empty(), "Restored schedule never fires early")
	var due := EventManager.process_scheduled_due(due_date)
	_assert(due.size() == 2 and _scheduled_record(EventManager.scheduled_events, first_schedule.scheduled_event_id).status == "queued" and _scheduled_record(EventManager.scheduled_events, invalid.scheduled_event_id).status == "expired", "Due processing queues valid schedule and expires revalidation failure normally")
	var active_id := EventManager.active_event.instance_id if EventManager.active_event != null else ""
	EventManager.process_scheduled_due(due_date)
	_assert(EventManager.active_event != null and EventManager.active_event.instance_id == active_id and EventManager.queued_events.is_empty(), "A restored scheduled occurrence fires only once")
	var terminal_snapshot := _json_snapshot()
	EventManager.cancel_active_event()
	_assert(SaveManager.apply_save_snapshot(terminal_snapshot) and _scheduled_record(EventManager.scheduled_events, invalid.scheduled_event_id).status == "expired" and _scheduled_record(EventManager.scheduled_events, cancelled.scheduled_event_id).status == "cancelled", "Cancelled and expired scheduled state cannot return as pending after load")


func _test_flag_persistence_and_new_game_reset() -> void:
	_setup_domain_state()
	var add_flag := _event("persistent_flag", [{"type":"add_flag","target":"primary","flag_id":FLAG_ID}])
	_configure([add_flag])
	EventManager.activate_chain(add_flag.event_id, {"primary":1}, {}, null, "flag_persistence")
	_assert(
		EventManager.resolve_active_event("continue").resolved
		and FLAG_ID in CharacterManager.characters[0].flag_ids,
		"add_flag writes only canonical Character flag state"
	)
	var snapshot := _json_snapshot()
	_assert(
		not snapshot["event_system"].has("effect_runtime_state"),
		"Event runtime no longer persists Event-owned temporary flag state"
	)

	var legacy_snapshot := snapshot.duplicate(true)
	legacy_snapshot["event_system"]["effect_runtime_state"] = {"temporary_flags": []}
	CharacterManager.set_character_flag(1, FLAG_ID, false)
	_assert(
		SaveManager.apply_save_snapshot(legacy_snapshot)
		and FLAG_ID in CharacterManager.characters[0].flag_ids,
		"Legacy version 6 effect_runtime_state is ignored while canonical Character flags restore normally"
	)

	EventManager.activate_chain(add_flag.event_id, {"primary":1}, {}, null, "before_new_game")
	EventManager.resolve_active_event("continue")
	_assert(not EventManager.story_history.records.is_empty(), "New-game reset fixture contains prior Event state")
	var started := GameManager.start_new_game("Reset", "male", "EventReset")
	SaveManager.current_save_id = -1
	_assert(not started.is_empty() and _event_state_is_empty(), "Normal new-game flow clears all Event runtime state and counters")


func _setup_domain_state() -> void:
	SaveManager.current_save_id = -1
	GameManager.family_name = "Phase4B"
	GameManager.family_money = 10000
	GameManager.diamonds = 100
	TimeManager.current_year = 2000; TimeManager.current_month = 1; TimeManager.current_day = 1
	TimeManager.is_paused = true; TimeManager.speed_multiplier = 1.0; TimeManager.day_timer = 0.0
	CharacterManager.characters = [_character(1), _character(2), _character(3)]
	CharacterManager.next_character_id = 4
	HouseManager.restore_save_state({"houses":[{"house_instance_id":"house_0001","house_definition_id":"family_house","property_id":"house_01","level":1,"role_assignments":{"head_of_household":1,"cook":null,"housekeeper":null,"caregiver":null},"resident_character_ids":[2,3]}],"next_house_instance_number":2,"last_unhoused_penalty_date":""})
	BusinessManager.businesses = [{"business_instance_id":"business_0001","business_type_id":"hospital","plot_id":"test_plot","level":1,"slots":[{"slot_id":"doctor_01","assigned_character_id":null,"assigned_npc_id":null},{"slot_id":"nurse_01","assigned_character_id":null,"assigned_npc_id":null}]}]
	BusinessManager.next_business_instance_number = 2
	NPCManager.worker_npcs = []; NPCManager.next_worker_npc_number = 1; NPCManager.months_until_next_generation = 1; NPCManager.last_processed_month_key = -1
	RelationshipNpcManager.relationship_candidate_ids = []
	CareerManager.active_job_offers = {}
	EducationManager.education_event_queue = []; EducationManager.current_education_event = {}; EducationManager.is_education_event_active = false; EducationManager.is_education_pause_active = false; EducationManager.should_resume_time_after_education_events = false
	EconomyManager.last_external_salary_payment_date = ""; EconomyManager.last_family_business_payment_date = ""; EconomyManager.last_family_business_breakdown = []; EconomyManager.last_house_payment_date = ""; EconomyManager.last_house_expense = 0
	ItemManager.reset_runtime_state()


func _character(id: int) -> Dictionary:
	return {"character_id":id,"character_type":"family","linked_character_id":null,"first_name":"Character %d" % id,"last_name":"Phase4B","gender":"male","birth_date":"1980-01-01","life_stage":"young_adult","is_alive":true,"is_player_family":true,"parent_ids":[],"children_ids":[],"partner_id":null,"relationship_cooldown_until":null,"flag_ids":[],"health":80,"happiness":80,"logic":80,"attractiveness":80,"social":80,"confidence":80,"discipline":80,"creativity":80,"job_id":null,"company_id":null,"salary":0,"school_id":null,"major_id":null,"education_status":"none","event_log":[],"is_retired":false,"last_salary":0,"pension":0,"avatar_theme":"default","genetics":{"skin_tone":"mixed"},"portrait_variant_id":"","portrait_path":"res://Resources/Characters/default_avatar.png"}


func _event(event_id: String, effects: Array = []) -> Dictionary:
	return {"event_id":event_id,"category":"general","domain":"general","subtype":"phase4b_fixture","enabled":true,"rarity":"common","weight":1.0,"priority":0,"exclusive_group":null,"trigger":{"type":"chain"},"participants":{"primary":{"type":"character","source":"trigger"}},"requirements":{"all":[]},"repeat":{"mode":"repeatable"},"cooldown":null,"behavior":{"blocking":true,"pause_game":true},"content":{"title":event_id,"description":"Phase 4B fixture"},"presentation":{"template":"standard_event"},"choices":[{"choice_id":"continue","title":"Continue","requirements":{"all":[]},"resolution":{"mode":"deterministic","effects":effects}}]}


func _pair_event(event_id: String) -> Dictionary:
	var event := _event(event_id)
	event.participants["target"] = {"type":"character","source":"trigger"}
	return event


func _configure(events: Array, seed: int = 17) -> void:
	var registry := EventDataRegistry.new()
	var loaded := registry.load_from_json_sources({"general.json":JSON.stringify({"schema_version":1,"category":"general","pools":[],"events":events})})
	_assert(loaded, "Phase 4B fixture registry validates", registry.get_diagnostic_text())
	EventManager.configure_runtime(registry, null, seed)


func _json_snapshot() -> Dictionary:
	return JSON.parse_string(JSON.stringify(SaveManager.create_save_snapshot()))


func _write_snapshot(save_id: int, snapshot: Dictionary) -> bool:
	var absolute_directory := ProjectSettings.globalize_path(TEST_SAVE_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		return false
	var file := FileAccess.open(SaveManager.get_save_path(save_id), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()
	return true


func _event_state_is_empty() -> bool:
	return EventManager.active_event == null and EventManager.queued_events.is_empty() and EventManager.scheduled_events.is_empty() and EventManager.story_history.records.is_empty() and EventManager.state_provider.completed_repeat_records.is_empty() and EventManager.state_provider.cooldown_records.is_empty() and EventManager.runtime_service.get_next_instance_number() == 1


func _cooldown_record(event_id: String) -> Dictionary:
	for record in EventManager.state_provider.cooldown_records:
		if String(record.get("event_id", "")) == event_id: return record
	return {}


func _scheduled_record(records: Array, scheduled_id: String) -> Dictionary:
	for record in records:
		if typeof(record) == TYPE_DICTIONARY and String(record.get("scheduled_event_id", "")) == scheduled_id: return record
	return {}


func _set_date(date_text: String) -> void:
	var parsed := GameCalendar.parse_iso_date(date_text)
	TimeManager.current_year = int(parsed.year); TimeManager.current_month = int(parsed.month); TimeManager.current_day = int(parsed.day)


func _cleanup_test_saves() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_SAVE_DIRECTORY)
	if not DirAccess.dir_exists_absolute(absolute): return
	var directory := DirAccess.open(TEST_SAVE_DIRECTORY)
	if directory != null:
		directory.list_dir_begin()
		var file_name := directory.get_next()
		while not file_name.is_empty():
			if not directory.current_is_dir(): DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_DIRECTORY.path_join(file_name)))
			file_name = directory.get_next()
		directory.list_dir_end()
	DirAccess.remove_absolute(absolute)


func _assert(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty(): print(detail)
