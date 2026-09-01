extends Node


var passed := 0
var failed := 0
var original_state: Dictionary = {}


func _ready() -> void:
	_store_state()
	_setup_characters()
	_run_tests()
	EventManager.configure_runtime(_registry([]))
	_restore_state()
	print("========================================")
	print("Event Phase 3 tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	if failed == 0:
		print("ALL EVENT PHASE 3 TESTS PASSED.")
	else:
		push_error("Event Phase 3 has %d failing test(s)." % failed)
	get_tree().quit(0 if failed == 0 else 1)


func _run_tests() -> void:
	_test_calendar_math()
	_test_calendar_trigger_evaluator()
	_test_system_triggers_and_duplicates()
	_test_calendar_dispatch_and_five_trigger_families()
	_test_pool_selection()
	_test_exclusive_priority_and_queue()
	_test_time_pause_restore()
	_test_repeat_modes_and_commit_point()
	_test_cooldown_scopes_and_calendar_expiry()
	_test_manual_real_availability_and_agency_isolation()
	_test_scheduling_lifecycle_and_revalidation()
	_test_serializable_runtime_state_and_no_effects()


func _test_calendar_math() -> void:
	_assert(GameCalendar.is_leap_year(2000) and not GameCalendar.is_leap_year(1900) and GameCalendar.is_leap_year(2024), "Gregorian leap-year rules")
	_assert(GameCalendar.days_in_month(2024, 2) == 29 and GameCalendar.days_in_month(2023, 2) == 28, "Month lengths include leap February")
	_assert(GameCalendar.add_days("2023-12-31", 1) == "2024-01-01", "Day addition crosses year boundary")
	_assert(GameCalendar.add_days("2024-02-28", 1) == "2024-02-29" and GameCalendar.add_days("2024-02-29", 1) == "2024-03-01", "Day addition reaches leap date")
	_assert(GameCalendar.add_interval("1987-05-12", "week", 1) == "1987-05-19", "Week addition uses seven real days")
	_assert(GameCalendar.add_months("2023-01-31", 1) == "2023-02-28" and GameCalendar.add_months("2024-01-31", 1) == "2024-02-29", "Month addition clamps to real month end")
	_assert(GameCalendar.add_months("1987-05-12", 60) == "1992-05-12", "Sixty calendar months remain exact")
	_assert(GameCalendar.add_years("2024-02-29", 1) == "2025-02-28" and GameCalendar.add_years("1987-05-12", 5) == "1992-05-12", "Year addition clamps leap dates")
	var old_date := _set_date(2024, 2, 28)
	TimeManager.advance_day()
	_assert(TimeManager.get_iso_date_string() == "2024-02-29", "TimeManager uses shared leap calendar")
	_restore_date(old_date)


func _test_calendar_trigger_evaluator() -> void:
	var evaluator := EventCalendarTriggerEvaluator.new("2024-01-31")
	_assert(evaluator.get_occurrence(_calendar_event("daily", {"cadence":{"unit":"day","interval":1}}), "2024-02-01").matches, "Daily cadence")
	_assert(evaluator.get_occurrence(_calendar_event("weekly", {"cadence":{"unit":"week","interval":1}}), "2024-02-07").matches, "Weekly cadence")
	_assert(evaluator.get_occurrence(_calendar_event("monthly", {"cadence":{"unit":"month","interval":1}}), "2024-02-29").matches, "Monthly cadence clamps anchor day")
	_assert(evaluator.get_occurrence(_calendar_event("yearly", {"cadence":{"unit":"year","interval":1}}), "2025-01-31").matches, "Yearly cadence")
	_assert(not evaluator.get_occurrence(_calendar_event("two_month", {"cadence":{"unit":"month","interval":2}}), "2024-02-29").matches and evaluator.get_occurrence(_calendar_event("two_month", {"cadence":{"unit":"month","interval":2}}), "2024-03-31").matches, "Cadence interval greater than one")
	_assert(evaluator.get_occurrence(_calendar_event("annual_leap", {"exact_date":{"month":2,"day":29}}), "2024-02-29").matches and not evaluator.get_occurrence(_calendar_event("annual_leap", {"exact_date":{"month":2,"day":29}}), "2025-02-28").matches, "Annual leap date fires only when date exists")
	_assert(evaluator.get_occurrence(_calendar_event("window", {"date_window":{"start":{"month":12,"day":29},"end":{"month":1,"day":2}}}), "2025-01-01").matches, "Annual date window crosses year boundary")


func _test_system_triggers_and_duplicates() -> void:
	var event := _event("system_birth", {"type":"system","event":"character_born"})
	event.participants = {"primary":{"type":"character","source":"trigger"}}
	var unrelated := _event("system_death", {"type":"system","event":"character_died"})
	_configure([event, unrelated])
	var context := {"trigger_character_id":1,"trigger_participants":{"primary":1},"context":{"character_id":1,"source_value":"kept"}}
	var first := EventManager.dispatch_system_trigger("character_born", context, "birth_occurrence_1", "test")
	_assert(first.selected_event_ids == ["system_birth"], "Semantic trigger matches only the correct Event")
	_assert(EventManager.active_event != null and EventManager.active_event.participants.primary == 1 and EventManager._occurrence_by_instance[EventManager.active_event.instance_id].context.source_value == "kept", "System trigger passes primary and context")
	EventManager.dispatch_system_trigger("character_born", context, "birth_occurrence_1", "test")
	_assert(EventManager.queued_events.is_empty(), "Duplicate raw signal occurrence does not duplicate queue entry")
	EventManager.complete_active_event()
	var later := EventManager.dispatch_system_trigger("character_born", context, "birth_occurrence_2", "test")
	_assert(later.queued_instances.size() == 1, "Genuinely later repeatable occurrence may queue")
	EventManager.cancel_active_event()


func _test_calendar_dispatch_and_five_trigger_families() -> void:
	var daily := _calendar_event("calendar_daily", {"cadence":{"unit":"day","interval":1}})
	_configure([daily])
	EventManager.calendar_evaluator.anchor_date = "2024-01-31"
	_set_date(2024, 2, 1)
	var first := EventManager.process_calendar_date("2024-02-01")
	_assert(first.queued_instances.size() == 1 and EventManager.active_event.trigger_type == "calendar", "Calendar trigger queues a calendar Event")
	EventManager.complete_active_event()
	var duplicate := EventManager.process_calendar_date("2024-02-01")
	_assert(duplicate.queued_instances.is_empty() and EventManager.active_event == null, "Calendar occurrence is evaluated once")

	var direct := _event("manual_direct", {"type":"manual","source":"lifestyle","mode":"direct"})
	var chain := _event("chain_only", {"type":"chain"})
	var scheduled := _event("scheduled_only", {"type":"scheduled"})
	_configure([direct, chain, scheduled])
	_assert(EventManager.discover_manual("lifestyle").events.size() == 1, "Manual discovery remains available")
	_assert(EventManager.activate_manual_direct("manual_direct", {}, "manual_1").queued, "Manual direct activation queues")
	EventManager.complete_active_event()
	_assert(EventManager.discover_manual("lifestyle").events.all(func(value): return value.event_id != "chain_only"), "Chain Event cannot enter ordinary manual discovery")
	_assert(EventManager.activate_chain("chain_only", {}, {}, "evt_source", "chain_1").queued and EventManager.active_event.source_instance_id == "evt_source", "Explicit chain activation works")
	EventManager.complete_active_event()
	var scheduled_record := EventManager.schedule_event("scheduled_only", "2024-02-02", {}, {"token":"persisted"}, "evt_source")
	_assert(not scheduled_record.is_empty() and scheduled_record.scheduled_event_id == "sched_00000001", "Scheduled trigger family creates a deterministic record")


func _test_pool_selection() -> void:
	var candidates := [_weighted("low", 1.0), _weighted("high", 100.0), _weighted("mid", 5.0)]
	var one_a := EventPoolSelector.new(42).select({"selection_mode":"weighted_one","max_events":1}, candidates)
	var one_b := EventPoolSelector.new(42).select({"selection_mode":"weighted_one","max_events":1}, candidates)
	_assert(one_a.size() == 1 and one_a == one_b, "weighted_one is seedable and deterministic")
	var multiple := EventPoolSelector.new(7).select({"selection_mode":"weighted_multiple","max_events":2}, candidates)
	_assert(multiple.size() == 2 and multiple[0].event_id != multiple[1].event_id, "weighted_multiple respects max and prevents duplicates")
	var all := EventPoolSelector.new(1).select({"selection_mode":"all_eligible","max_events":2}, candidates)
	_assert(all.size() == 2, "all_eligible respects max_events")
	_assert(EventPoolSelector.new(1).select({"selection_mode":"weighted_one"}, []).is_empty(), "Empty eligible pool returns empty")
	var eligible_only := EventPoolSelector.new(3).select({"selection_mode":"weighted_one"}, [_weighted("eligible", 1.0)])
	_assert(eligible_only.size() == 1 and eligible_only[0].event_id == "eligible", "One eligible Event consumes all probability after filtering")

	var pool_events := [_event("pool_ok", {"type":"manual","source":"relationship","mode":"pool","pool_id":"manual_pool"}), _event("pool_locked", {"type":"manual","source":"relationship","mode":"pool","pool_id":"manual_pool"})]
	pool_events[0].pool_id = "manual_pool"; pool_events[1].pool_id = "manual_pool"
	pool_events[1].requirements = {"all":[{"type":"money","operator":">=","value":999999}]}
	_configure(pool_events, [{"pool_id":"manual_pool","selection_mode":"weighted_one","max_events":1}])
	GameManager.family_money = 100
	var invoked := EventManager.invoke_manual_pool("relationship", "manual_pool", {}, "pool_occurrence")
	_assert(invoked.selected_event_ids == ["pool_ok"] and invoked.queued_instances.size() == 1, "Manual pool filters ineligible weight before selection")
	EventManager.cancel_active_event()


func _test_exclusive_priority_and_queue() -> void:
	var variant_a := _event("variant_a", {"type":"system","event":"priority_test"}); variant_a.exclusive_group = "variant"; variant_a.weight = 1
	var variant_b := _event("variant_b", {"type":"system","event":"priority_test"}); variant_b.exclusive_group = "variant"; variant_b.weight = 1
	var high := _event("high", {"type":"system","event":"priority_test"}); high.priority = 20
	var equal_a := _event("equal_a", {"type":"system","event":"priority_test"}); equal_a.priority = 10
	var equal_b := _event("equal_b", {"type":"system","event":"priority_test"}); equal_b.priority = 10
	_configure([variant_a, variant_b, equal_a, equal_b, high], [], 11)
	var result := EventManager.dispatch_system_trigger("priority_test", {}, "priority_occurrence", "test")
	var variant_count := int("variant_a" in result.selected_event_ids) + int("variant_b" in result.selected_event_ids)
	_assert(variant_count == 1 and "high" in result.selected_event_ids, "Exclusive group keeps one weighted variant and leaves unrelated Events")
	_assert(EventManager.active_event.event_id == "high", "Higher priority activates first and priority is not pool probability")
	_assert(EventManager.queued_events[0].event_id == "equal_a" and EventManager.queued_events[1].event_id == "equal_b", "Equal-priority queue order is stable")
	var queue_size := EventManager.queued_events.size()
	EventManager.dispatch_system_trigger("priority_test", {}, "priority_occurrence", "test")
	_assert(EventManager.queued_events.size() == queue_size, "Queue duplicate suppression covers active and queued Events")
	EventManager.cancel_active_event()
	_assert(EventManager.active_event != null and EventManager.active_event.event_id == "equal_a", "Cancelling active Event activates next valid queue entry")
	while EventManager.active_event != null:
		EventManager.cancel_active_event()


func _test_time_pause_restore() -> void:
	for speed in [1.0, 2.0, 3.0]:
		var first := _event("blocking_a", {"type":"system","event":"block"}); first.priority = 2
		var second := _event("blocking_b", {"type":"system","event":"block"}); second.priority = 1
		_configure([first, second])
		TimeManager.is_paused = false; TimeManager.speed_multiplier = speed
		EventManager.dispatch_system_trigger("block", {}, "block_%s" % speed, "test")
		_assert(TimeManager.is_paused, "Blocking queue pauses from x%s" % speed)
		EventManager.complete_active_event()
		_assert(TimeManager.is_paused and EventManager.active_event != null, "Multiple blocking Events do not resume between Events")
		EventManager.complete_active_event()
		_assert(not TimeManager.is_paused and is_equal_approx(TimeManager.speed_multiplier, speed), "Queue restores exact x%s running state" % speed)
	var paused_event := _event("paused_block", {"type":"system","event":"paused_block"})
	_configure([paused_event])
	TimeManager.is_paused = true; TimeManager.speed_multiplier = 3.0
	EventManager.dispatch_system_trigger("paused_block", {}, "paused_occurrence", "test")
	EventManager.complete_active_event()
	_assert(TimeManager.is_paused and is_equal_approx(TimeManager.speed_multiplier, 3.0), "Manually paused state remains paused after queue")
	var blocking_contract := _event("blocking_contract", {"type":"system","event":"blocking_contract"}); blocking_contract.behavior.pause_game = false
	_configure([blocking_contract])
	TimeManager.is_paused = false; TimeManager.speed_multiplier = 2.0
	EventManager.dispatch_system_trigger("blocking_contract", {}, "blocking_contract_occurrence", "test")
	_assert(TimeManager.is_paused, "Blocking behavior pauses even when legacy pause_game metadata is false")
	EventManager.complete_active_event()
	_assert(not TimeManager.is_paused and is_equal_approx(TimeManager.speed_multiplier, 2.0), "Blocking contract restores the exact prior running state")


func _test_repeat_modes_and_commit_point() -> void:
	var provider := EventAvailabilityStateProvider.new(Callable(self, "_test_date"))
	var p1 := {"primary":1}; var p2 := {"primary":2}; var pair := {"primary":1,"target":2}; var reversed := {"primary":2,"target":1}
	for mode in ["once", "once_per_family", "repeatable"]:
		var event := _repeat_event("repeat_%s" % mode, mode)
		provider.commit_completion(event, p1, {})
		_assert(provider.is_completed_non_repeatable(event, p2, {}) == (mode != "repeatable"), "Repeat mode %s" % mode)
	var per_character := _repeat_event("per_character", "once_per_character")
	provider.commit_completion(per_character, p1, {})
	_assert(provider.is_completed_non_repeatable(per_character, p1, {}) and not provider.is_completed_non_repeatable(per_character, p2, {}), "once_per_character isolates Character")
	var per_primary := _pair_event("per_primary"); per_primary.repeat.mode = "once_per_character"
	provider.commit_completion(per_primary, {"primary":2,"target":1}, {})
	_assert(provider.is_completed_non_repeatable(per_primary, {"primary":2,"target":3}, {}) and not provider.is_completed_non_repeatable(per_primary, {"primary":1,"target":2}, {}), "once_per_character keys the declared primary rather than the lowest pair ID")
	var per_pair := _pair_event("per_pair"); per_pair.repeat.mode = "once_per_character_pair"
	provider.commit_completion(per_pair, pair, {})
	_assert(provider.is_completed_non_repeatable(per_pair, reversed, {}), "once_per_character_pair normalizes pair order")
	var house := _context_event("repeat_house", "house"); house.repeat.mode = "once_per_house"
	provider.commit_completion(house, {"context":"house_0001"}, {"house_instance_id":"house_0001"})
	_assert(provider.is_completed_non_repeatable(house, {"context":"house_0001"}, {"house_instance_id":"house_0001"}), "once_per_house")
	var business := _context_event("repeat_business", "business"); business.repeat.mode = "once_per_business"
	provider.commit_completion(business, {"context":"business_0001"}, {"business_instance_id":"business_0001"})
	_assert(provider.is_completed_non_repeatable(business, {"context":"business_0001"}, {"business_instance_id":"business_0001"}), "once_per_business")

	var lifecycle := _event("repeat_lifecycle", {"type":"manual","source":"lifestyle","mode":"direct"}); lifecycle.repeat.mode = "once"
	_configure([lifecycle])
	EventManager.activate_manual_direct("repeat_lifecycle", {}, "cancel_occurrence")
	EventManager.cancel_active_event()
	_assert(EventManager.runtime_service.get_availability("repeat_lifecycle").available, "Cancelled Event does not consume completed-only repeat policy")
	EventManager.activate_manual_direct("repeat_lifecycle", {}, "complete_occurrence")
	EventManager.complete_active_event()
	_assert(EventManager.runtime_service.get_availability("repeat_lifecycle").status == EventRuntimeService.COMPLETED_NON_REPEATABLE, "Completed Event consumes repeat policy")


func _test_cooldown_scopes_and_calendar_expiry() -> void:
	var provider := EventAvailabilityStateProvider.new(Callable(self, "_test_date"))
	_set_date(1987, 5, 12)
	var scopes := ["event", "character", "character_pair", "family", "house", "business"]
	for scope in scopes:
		var event := _cooldown_event("cooldown_%s" % scope, scope, "day", 1)
		var participants := {"primary":1,"target":2,"house":"house_0001","business":"business_0001"}
		var context := {"house_instance_id":"house_0001","business_instance_id":"business_0001"}
		provider.commit_completion(event, participants, context)
		_assert(provider.is_on_cooldown(event, participants, context), "Cooldown scope %s" % scope)
	var pair_event := _cooldown_event("pair_normal", "character_pair", "month", 1)
	provider.commit_completion(pair_event, {"primary":1,"target":2}, {})
	_assert(provider.is_on_cooldown(pair_event, {"primary":2,"target":1}, {}), "Cooldown Character pair is normalized")
	var primary_event := _cooldown_event("character_primary", "character", "month", 1)
	provider.commit_completion(primary_event, {"primary":2,"target":1}, {})
	_assert(provider.is_on_cooldown(primary_event, {"primary":2,"target":3}, {}) and not provider.is_on_cooldown(primary_event, {"primary":1,"target":2}, {}), "Character cooldown keys the declared primary rather than the lowest pair ID")

	var units := {"day":"1987-05-13","week":"1987-05-19","month":"1987-06-12","year":"1988-05-12"}
	for unit in units:
		var event := _cooldown_event("unit_%s" % unit, "event", unit, 1)
		provider.commit_completion(event, {}, {}, "1987-05-12")
		_assert(provider.cooldown_records.back().available_date == units[unit], "Cooldown unit %s uses real calendar" % unit)
	var month_end := _cooldown_event("month_end", "event", "month", 1)
	provider.commit_completion(month_end, {}, {}, "2024-01-31")
	_assert(provider.cooldown_records.back().available_date == "2024-02-29", "Cooldown month-end clamps on leap year")
	var leap_year := _cooldown_event("leap_year", "event", "year", 1)
	provider.commit_completion(leap_year, {}, {}, "2024-02-29")
	_assert(provider.cooldown_records.back().available_date == "2025-02-28", "Cooldown leap-date year clamps")
	_set_date(2025, 2, 27)
	_assert(provider.is_on_cooldown(leap_year, {}, {}), "Cooldown remains locked before expiry")
	_set_date(2025, 2, 28)
	_assert(not provider.is_on_cooldown(leap_year, {}, {}), "Cooldown is available exactly at expiry")


func _test_manual_real_availability_and_agency_isolation() -> void:
	var repeat_event := _event("manual_once", {"type":"manual","source":"lifestyle","mode":"direct"}); repeat_event.repeat.mode = "once"
	var cooldown_event := _event("manual_cooldown", {"type":"manual","source":"lifestyle","mode":"direct"}); cooldown_event.cooldown = {"scope":"family","unit":"month","value":1}
	_configure([repeat_event, cooldown_event])
	_set_date(1987, 5, 12)
	EventManager.activate_manual_direct("manual_cooldown", {}, "cooldown_use"); EventManager.complete_active_event()
	_assert(_manual_status("lifestyle", "manual_cooldown") == EventRuntimeService.LOCKED_COOLDOWN, "Manual discovery uses real Phase 3 cooldown state")
	EventManager.activate_manual_direct("manual_once", {}, "once_use"); EventManager.complete_active_event()
	_assert(_manual_status("lifestyle", "manual_once") == EventRuntimeService.COMPLETED_NON_REPEATABLE, "Manual discovery uses real Phase 3 repeat state")

	var agency_a := _agency_event("agency_a", "month", 60)
	var agency_b := _agency_event("agency_b", "year", 5)
	var agency_long := _agency_event("agency_long", "month", 360)
	_configure([agency_a, agency_b, agency_long], [], 0, "family_agency")
	_set_date(1987, 5, 12)
	EventManager.activate_manual_direct("agency_a", {}, "agency_a_use"); EventManager.complete_active_event()
	_assert(_manual_status("family_agency", "agency_a") == EventRuntimeService.LOCKED_COOLDOWN and _manual_status("family_agency", "agency_b") == EventRuntimeService.AVAILABLE, "Agency Event A cooldown does not lock Event B")
	_assert(EventManager.state_provider.cooldown_records[0].available_date == "1992-05-12", "Agency 60-month cooldown")
	EventManager.activate_manual_direct("agency_b", {}, "agency_b_use"); EventManager.complete_active_event()
	_assert(EventManager.state_provider.cooldown_records.back().available_date == "1992-05-12", "Agency five-year cooldown")
	EventManager.activate_manual_direct("agency_long", {}, "agency_long_use"); EventManager.complete_active_event()
	_assert(EventManager.state_provider.cooldown_records.back().available_date == "2017-05-12", "Agency 360-month cooldown")


func _test_scheduling_lifecycle_and_revalidation() -> void:
	var scheduled := _event("scheduled_valid", {"type":"scheduled"}); scheduled.participants = {"primary":{"type":"character","source":"trigger"}}; scheduled.requirements = {"all":[{"type":"is_alive","target":"primary","operator":"==","value":true}]}
	_configure([scheduled])
	_set_date(2024, 1, 30)
	var record := EventManager.schedule_event_after("scheduled_valid", "month", 1, {"primary":1}, {"marker":"persisted"}, "evt_source")
	_assert(record.due_date == "2024-02-29" and record.participants.primary == 1 and record.context.marker == "persisted", "Scheduling stores due date and participant/context bindings")
	_assert(EventManager.process_scheduled_due("2024-02-28").is_empty(), "Scheduled Event does not trigger early")
	var due := EventManager.process_scheduled_due("2024-02-29")
	_assert(due.size() == 1 and due[0].status == "queued" and EventManager.active_event.trigger_type == "scheduled", "Scheduled Event queues when due and valid")
	EventManager.complete_active_event()

	_configure([scheduled])
	var cancelled := EventManager.schedule_event("scheduled_valid", "2024-03-01", {"primary":1})
	_assert(EventManager.cancel_scheduled_event(cancelled.scheduled_event_id) and EventManager.get_scheduled_events()[0].status == "cancelled", "Scheduled cancellation")

	_configure([scheduled]); var dead := EventManager.schedule_event("scheduled_valid", "2024-03-01", {"primary":1}); CharacterManager.characters[0].is_alive = false
	_assert(EventManager.process_scheduled_due("2024-03-01")[0].status == "expired", "Dead scheduled participant expires")
	CharacterManager.characters[0].is_alive = true

	var health_event := scheduled.duplicate(true); health_event.event_id = "scheduled_health"; health_event.requirements = {"all":[{"type":"stat","target":"primary","stat":"health","operator":">=","value":50}]}
	_configure([health_event]); EventManager.schedule_event("scheduled_health", "2024-03-01", {"primary":1}); CharacterManager.characters[0].health = 10
	_assert(EventManager.process_scheduled_due("2024-03-01")[0].status == "expired", "Changed requirement before due expires")
	CharacterManager.characters[0].health = 80

	_configure([scheduled]); EventManager.schedule_event("scheduled_valid", "2024-03-01", {"primary":1}); EventManager.registry.events_by_id.scheduled_valid.enabled = false
	_assert(EventManager.process_scheduled_due("2024-03-01")[0].status == "expired", "Disabled scheduled definition expires")

	var repeat_scheduled := scheduled.duplicate(true); repeat_scheduled.event_id = "scheduled_repeat"; repeat_scheduled.repeat.mode = "once"
	_configure([repeat_scheduled]); EventManager.schedule_event("scheduled_repeat", "2024-03-01", {"primary":1}); EventManager.state_provider.commit_completion(repeat_scheduled, {"primary":1}, {}, "2024-02-01")
	_assert(EventManager.process_scheduled_due("2024-03-01")[0].status == "expired", "Repeat-invalid scheduled Event expires")

	var cooldown_scheduled := scheduled.duplicate(true); cooldown_scheduled.event_id = "scheduled_cooldown"; cooldown_scheduled.cooldown = {"scope":"event","unit":"month","value":1}
	_configure([cooldown_scheduled]); EventManager.schedule_event("scheduled_cooldown", "2024-03-01", {"primary":1}); EventManager.state_provider.commit_completion(cooldown_scheduled, {"primary":1}, {}, "2024-02-15")
	_assert(EventManager.process_scheduled_due("2024-03-01")[0].status == "expired", "Cooldown-invalid scheduled Event expires")


func _test_serializable_runtime_state_and_no_effects() -> void:
	var event := _event("serializable", {"type":"system","event":"serialize"})
	_configure([event])
	var money := GameManager.family_money; var diamonds := GameManager.diamonds; var characters := CharacterManager.characters.duplicate(true)
	EventManager.dispatch_system_trigger("serialize", {}, "serialize_occurrence", "test")
	var state := EventManager.export_runtime_state()
	_assert(not JSON.stringify(state).is_empty() and state.has("active_event") and state.has("queued_events") and state.has("scheduled_events") and state.has("repeat_runtime_state") and state.has("cooldowns") and state.has("next_event_instance_number") and state.has("next_scheduled_event_number"), "Phase 3 runtime state is cleanly JSON-serializable for Phase 4")
	EventManager.complete_active_event()
	_assert(GameManager.family_money == money and GameManager.diamonds == diamonds and CharacterManager.characters == characters, "Trigger/queue/completion performs no gameplay effects")


func _configure(events: Array, pools: Array = [], seed: int = 0, category: String = "general") -> void:
	EventManager.configure_runtime(_registry(events, pools, category), null, seed)


func _registry(events: Array, pools: Array = [], category: String = "general") -> EventDataRegistry:
	var result := EventDataRegistry.new()
	var document := {"schema_version":1,"category":category,"pools":pools,"events":[]}
	for event_value in events:
		var event: Dictionary = event_value.duplicate(true)
		event.category = category
		document.events.append(event)
	var loaded := result.load_from_json_sources({"%s.json" % category:JSON.stringify(document)})
	_assert(loaded, "Phase 3 fixture registry validates", result.get_diagnostic_text())
	return result


func _event(event_id: String, trigger: Dictionary) -> Dictionary:
	return {"event_id":event_id,"category":"general","domain":"general","subtype":"phase3_fixture","enabled":true,"rarity":"common","weight":1.0,"priority":0,"exclusive_group":null,"trigger":trigger,"participants":{},"requirements":{"all":[]},"repeat":{"mode":"repeatable"},"cooldown":null,"behavior":{"blocking":true,"pause_game":true},"content":{"title":event_id,"description":"Phase 3 fixture"},"presentation":{"template":"standard_event"},"choices":[{"choice_id":"continue","title":"Continue","resolution":{"mode":"deterministic","effects":[]}}]}


func _calendar_event(event_id: String, rule: Dictionary) -> Dictionary:
	var event := _event(event_id, {"type":"calendar"})
	for key in rule:
		event.trigger[key] = rule[key]
	return event


func _weighted(event_id: String, weight: float, group: String = "") -> Dictionary:
	return {"event_id":event_id,"weight":weight,"exclusive_group":group}


func _repeat_event(event_id: String, mode: String) -> Dictionary:
	var event := _event(event_id, {"type":"chain"}); event.repeat.mode = mode; event.participants = {"primary":{"type":"character","source":"trigger"}}
	return event


func _pair_event(event_id: String) -> Dictionary:
	var event := _repeat_event(event_id, "once_per_character_pair"); event.participants.target = {"type":"character","source":"trigger"}
	return event


func _context_event(event_id: String, participant_type: String) -> Dictionary:
	var event := _event(event_id, {"type":"chain"}); event.participants = {"context":{"type":participant_type,"source":"context"}}
	return event


func _cooldown_event(event_id: String, scope: String, unit: String, value: int) -> Dictionary:
	var event := _pair_event(event_id); event.repeat.mode = "repeatable"; event.cooldown = {"scope":scope,"unit":unit,"value":value}; event.participants.house = {"type":"house","source":"context"}; event.participants.business = {"type":"business","source":"context"}
	return event


func _agency_event(event_id: String, unit: String, value: int) -> Dictionary:
	var event := _event(event_id, {"type":"manual","source":"family_agency","mode":"direct"}); event.cooldown = {"scope":"event","unit":unit,"value":value}
	return event


func _manual_status(source: String, event_id: String) -> String:
	for value in EventManager.discover_manual(source).events:
		if value.event_id == event_id:
			return String(value.status)
	return ""


func _setup_characters() -> void:
	CharacterManager.characters = [_character(1, true), _character(2, true), _character(3, false)]
	GameManager.family_money = 10000
	GameManager.diamonds = 100


func _character(id: int, family: bool) -> Dictionary:
	return {"character_id":id,"first_name":"Character %d" % id,"gender":"female","birth_date":"1980-01-01","life_stage":"young_adult","is_alive":true,"is_player_family":family,"parent_ids":[],"children_ids":[],"partner_id":null,"flag_ids":[],"health":80,"happiness":80,"logic":80,"attractiveness":80,"social":80,"confidence":80,"discipline":80,"creativity":80,"job_id":null,"school_id":null,"major_id":null,"event_log":[]}


func _test_date() -> String:
	return TimeManager.get_iso_date_string()


func _set_date(year: int, month: int, day: int) -> Dictionary:
	var previous := {"year":TimeManager.current_year,"month":TimeManager.current_month,"day":TimeManager.current_day}
	TimeManager.current_year = year; TimeManager.current_month = month; TimeManager.current_day = day
	return previous


func _restore_date(value: Dictionary) -> void:
	TimeManager.current_year = value.year; TimeManager.current_month = value.month; TimeManager.current_day = value.day


func _store_state() -> void:
	original_state = {"characters":CharacterManager.characters.duplicate(true),"money":GameManager.family_money,"diamonds":GameManager.diamonds,"day":TimeManager.current_day,"month":TimeManager.current_month,"year":TimeManager.current_year,"paused":TimeManager.is_paused,"speed":TimeManager.speed_multiplier}


func _restore_state() -> void:
	CharacterManager.characters = original_state.characters; GameManager.family_money = original_state.money; GameManager.diamonds = original_state.diamonds
	TimeManager.current_day = original_state.day; TimeManager.current_month = original_state.month; TimeManager.current_year = original_state.year; TimeManager.is_paused = original_state.paused; TimeManager.speed_multiplier = original_state.speed


func _assert(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty(): print(detail)
