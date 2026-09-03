extends Node


signal semantic_trigger_dispatched(occurrence: Dictionary)
signal event_queued(instance: Dictionary)
signal active_event_changed(instance: Dictionary)
signal event_completed(instance: Dictionary)
signal event_cancelled(instance: Dictionary)
signal event_expired(instance: Dictionary, reasons: Array)
signal queue_changed(active: Dictionary, queued: Array)
signal scheduled_event_changed(record: Dictionary)


var registry: EventDataRegistry
var runtime_service: EventRuntimeService
var state_provider: EventAvailabilityStateProvider
var pool_selector: EventPoolSelector
var calendar_evaluator: EventCalendarTriggerEvaluator
var story_history: EventStoryHistory
var resolution_resolver: EventResolutionResolver
var effect_resolver: EventEffectResolver
var last_import_error: String = ""

var active_event: EventInstance = null
var queued_events: Array[EventInstance] = []
var scheduled_events: Array[Dictionary] = []

var _next_scheduled_event_number := 1
var _next_queue_order := 1
var _queue_order_by_instance: Dictionary = {}
var _occurrence_by_instance: Dictionary = {}
var _deduplication_keys: Dictionary = {}
var _calendar_occurrence_keys: Dictionary = {}
var _processed_selection_occurrences: Dictionary = {}
var _pause_state_captured := false
var _pre_event_was_paused := true
var _pre_event_speed := 1.0


func _ready() -> void:
	var production_registry := EventDataRegistry.new()
	if not production_registry.load_all():
		push_error("Event definitions could not be loaded:\n" + production_registry.get_diagnostic_text())
	configure_runtime(production_registry)
	_connect_runtime_adapters()


func configure_runtime(
	p_registry: EventDataRegistry,
	query_provider: EventRuntimeQueryProvider = null,
	random_seed: int = 0,
	calendar_anchor_date: String = "1985-01-26"
) -> void:
	_restore_time_state_if_owned()
	registry = p_registry
	story_history = EventStoryHistory.new()
	var resolved_query_provider := query_provider if query_provider != null else EventRuntimeQueryProvider.new()
	resolved_query_provider.history_provider = story_history
	state_provider = EventAvailabilityStateProvider.new(Callable(self, "_current_date"))
	runtime_service = EventRuntimeService.new(registry, resolved_query_provider, state_provider)
	pool_selector = EventPoolSelector.new(random_seed)
	resolution_resolver = EventResolutionResolver.new(resolved_query_provider, random_seed)
	effect_resolver = EventEffectResolver.new(registry)
	calendar_evaluator = EventCalendarTriggerEvaluator.new(calendar_anchor_date)
	reset_runtime_state()


func reset_runtime_state() -> void:
	_restore_time_state_if_owned()
	active_event = null
	queued_events.clear()
	scheduled_events.clear()
	_next_scheduled_event_number = 1
	_next_queue_order = 1
	_queue_order_by_instance.clear()
	_occurrence_by_instance.clear()
	_deduplication_keys.clear()
	_calendar_occurrence_keys.clear()
	_processed_selection_occurrences.clear()
	if state_provider != null:
		state_provider.reset()
	if story_history != null:
		story_history.reset()
	if runtime_service != null:
		runtime_service.reset_instance_counter()
	_emit_queue_state()


func dispatch_system_trigger(
	semantic_event: String,
	runtime_context: Dictionary = {},
	occurrence_key: String = "",
	source: String = "application"
) -> Dictionary:
	var occurrence := _make_occurrence("system", semantic_event, runtime_context, occurrence_key, source)
	semantic_trigger_dispatched.emit(occurrence.duplicate(true))
	var matching: Array = []
	for event_value in registry.events_by_id.values():
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var trigger = event.get("trigger", {})
		if typeof(trigger) != TYPE_DICTIONARY or String(trigger.get("type", "")) != "system" or String(trigger.get("event", "")) != semantic_event:
			continue
		if _parameters_match(trigger.get("parameters", {}), runtime_context):
			matching.append(event)
	return _select_and_queue(matching, runtime_context, occurrence)


func process_calendar_date(date_text: String = "", runtime_context: Dictionary = {}) -> Dictionary:
	var current_date := date_text if not date_text.is_empty() else _current_date()
	var matching: Array = []
	for event_value in registry.events_by_id.values():
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var result := calendar_evaluator.get_occurrence(event, current_date)
		if not bool(result.get("matches", false)):
			continue
		var event_id := String(event.get("event_id", ""))
		var occurrence_key := "%s|%s" % [event_id, String(result.get("occurrence_key", ""))]
		if _calendar_occurrence_keys.has(occurrence_key):
			continue
		_calendar_occurrence_keys[occurrence_key] = true
		matching.append(event)
	var occurrence := _make_occurrence("calendar", "", runtime_context, "calendar:%s" % current_date, "TimeManager")
	var selected := _select_and_queue(matching, runtime_context, occurrence)
	selected["date"] = current_date
	return selected


func discover_manual(source: String, runtime_context: Dictionary = {}, mode: String = "", pool_id: String = "") -> Dictionary:
	return runtime_service.discover_manual(source, runtime_context, mode, pool_id)


func activate_manual_direct(event_id: String, runtime_context: Dictionary = {}, occurrence_key: String = "") -> Dictionary:
	var event := registry.get_event(event_id)
	var trigger = event.get("trigger", {})
	if event.is_empty() or typeof(trigger) != TYPE_DICTIONARY or String(trigger.get("type", "")) != "manual" or String(trigger.get("mode", "")) != "direct":
		return {"queued": false, "reason": "not_manual_direct", "availability": runtime_service.get_availability(event_id, runtime_context)}
	var occurrence := _make_occurrence("manual", String(trigger.get("source", "")), runtime_context, occurrence_key, "manual")
	var availability := runtime_service.get_availability(event_id, runtime_context)
	var instance := _queue_available_event(event, availability, occurrence)
	return {"queued": instance != null, "instance": instance, "availability": availability}


func invoke_manual_pool(source: String, pool_id: String, runtime_context: Dictionary = {}, occurrence_key: String = "") -> Dictionary:
	var events: Array = []
	for event_value in registry.get_events_for_pool(pool_id):
		var event: Dictionary = event_value
		var trigger = event.get("trigger", {})
		if typeof(trigger) == TYPE_DICTIONARY and String(trigger.get("type", "")) == "manual" and String(trigger.get("mode", "")) == "pool" and String(trigger.get("source", "")) == source:
			events.append(event)
	var occurrence := _make_occurrence("manual", source, runtime_context, occurrence_key, "manual_pool")
	return _select_and_queue(events, runtime_context, occurrence, pool_id)


func activate_chain(
	event_id: String,
	participants: Dictionary = {},
	context: Dictionary = {},
	source_instance_id = null,
	occurrence_key: String = ""
) -> Dictionary:
	var event := registry.get_event(event_id)
	if event.is_empty() or String(event.get("trigger", {}).get("type", "")) != "chain":
		return {"queued": false, "reason": "not_chain_event"}
	var availability := runtime_service.get_resolved_availability(event_id, participants, context)
	var runtime_context := {"context": context}
	var occurrence := _make_occurrence("chain", event_id, runtime_context, occurrence_key, "event_flow")
	var instance := _queue_available_event(event, availability, occurrence, source_instance_id)
	return {"queued": instance != null, "instance": instance, "availability": availability}


func can_activate_chain(
	event_id: String,
	participants: Dictionary = {},
	context: Dictionary = {},
	occurrence_key: String = ""
) -> Dictionary:
	var event := registry.get_event(event_id)
	if event.is_empty() or String(event.get("trigger", {}).get("type", "")) != "chain":
		return {"available": false, "reason": "not_chain_event"}
	var availability := runtime_service.get_resolved_availability(event_id, participants, context)
	if String(availability.get("status", "")) != EventRuntimeService.AVAILABLE:
		return {"available": false, "reason": "unavailable", "availability": availability}
	var occurrence := _make_occurrence("chain", event_id, {"context": context}, occurrence_key, "event_flow")
	var duplicate_key := _duplicate_key(
		event_id,
		availability.get("participants", {}),
		availability.get("context", {}),
		String(occurrence.get("occurrence_id", ""))
	)
	return {
		"available": not _deduplication_keys.has(duplicate_key),
		"reason": "duplicate" if _deduplication_keys.has(duplicate_key) else "available",
		"availability": availability
	}


func schedule_event(
	event_id: String,
	due_date: String,
	participants: Dictionary = {},
	context: Dictionary = {},
	source_instance_id = null
) -> Dictionary:
	var event := registry.get_event(event_id)
	if event.is_empty() or String(event.get("trigger", {}).get("type", "")) != "scheduled" or not bool(GameCalendar.parse_iso_date(due_date).get("valid", false)):
		return {}
	var scheduled_id := "sched_%08d" % _next_scheduled_event_number
	_next_scheduled_event_number += 1
	var record := {
		"scheduled_event_id": scheduled_id,
		"event_id": event_id,
		"due_date": due_date,
		"participants": participants.duplicate(true),
		"context": context.duplicate(true),
		"source_instance_id": source_instance_id,
		"status": "scheduled",
		"queued_instance_id": null,
		"failure_reasons": []
	}
	scheduled_events.append(record)
	scheduled_event_changed.emit(record.duplicate(true))
	return record.duplicate(true)


func schedule_event_after(
	event_id: String,
	unit: String,
	amount: int,
	participants: Dictionary = {},
	context: Dictionary = {},
	source_instance_id = null
) -> Dictionary:
	var due_date := GameCalendar.add_interval(_current_date(), unit, amount)
	return {} if due_date.is_empty() else schedule_event(event_id, due_date, participants, context, source_instance_id)


func cancel_scheduled_event(scheduled_event_id: String) -> bool:
	for index in scheduled_events.size():
		var record: Dictionary = scheduled_events[index]
		if String(record.get("scheduled_event_id", "")) == scheduled_event_id and String(record.get("status", "")) == "scheduled":
			record["status"] = "cancelled"
			scheduled_events[index] = record
			scheduled_event_changed.emit(record.duplicate(true))
			return true
	return false


func get_scheduled_events(include_terminal: bool = true) -> Array:
	var result: Array = []
	for record_value in scheduled_events:
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = record_value
		if include_terminal or String(record.get("status", "")) == "scheduled":
			result.append(record.duplicate(true))
	return result


func process_scheduled_due(date_text: String = "") -> Array:
	var current_date := date_text if not date_text.is_empty() else _current_date()
	var processed: Array = []
	for index in scheduled_events.size():
		var record: Dictionary = scheduled_events[index]
		if String(record.get("status", "")) != "scheduled" or GameCalendar.compare(current_date, String(record.get("due_date", ""))) < 0:
			continue
		var event_id := String(record.get("event_id", ""))
		var event := registry.get_event(event_id)
		var failure_reasons: Array = []
		var availability: Dictionary = {}
		if event.is_empty() or not bool(event.get("enabled", false)) or String(event.get("trigger", {}).get("type", "")) != "scheduled":
			failure_reasons = [{"code": "scheduled_definition_unavailable", "message": "Scheduled Event definition is unavailable."}]
		else:
			availability = runtime_service.get_resolved_availability(event_id, record.get("participants", {}), record.get("context", {}))
			if String(availability.get("status", "")) != EventRuntimeService.AVAILABLE:
				failure_reasons = availability.get("failure_reasons", []).duplicate(true)
		if not failure_reasons.is_empty():
			record["status"] = "expired"
			record["failure_reasons"] = failure_reasons
			scheduled_events[index] = record
			scheduled_event_changed.emit(record.duplicate(true))
			processed.append(record.duplicate(true))
			continue
		var occurrence := _make_occurrence("scheduled", event_id, {"context": record.get("context", {})}, "scheduled:%s" % String(record.get("scheduled_event_id", "")), "EventManager")
		var instance := _queue_available_event(event, availability, occurrence, record.get("source_instance_id", null))
		if instance == null:
			record["status"] = "expired"
			record["failure_reasons"] = [{"code": "scheduled_duplicate", "message": "Scheduled Event occurrence was already queued."}]
		else:
			record["status"] = "queued"
			record["queued_instance_id"] = instance.instance_id
		scheduled_events[index] = record
		scheduled_event_changed.emit(record.duplicate(true))
		processed.append(record.duplicate(true))
	return processed


func complete_active_event() -> bool:
	return _finish_active_event("completed")


func resolve_active_event(choice_id: String = "") -> Dictionary:
	if active_event == null:
		return _resolution_failure("no_active_event", "There is no active Event to resolve.")
	var event := registry.get_event(active_event.event_id)
	if event.is_empty():
		return _resolution_failure("definition_missing", "The active Event definition is unavailable.")
	var availability := runtime_service.get_resolved_availability(active_event.event_id, active_event.participants, active_event.context)
	if String(availability.get("status", "")) != EventRuntimeService.AVAILABLE:
		return {"resolved": false, "failure_reasons": availability.get("failure_reasons", []).duplicate(true), "effect_results": []}
	var choice: Dictionary = {}
	var choices_value = event.get("choices", [])
	if typeof(choices_value) == TYPE_ARRAY and not choices_value.is_empty():
		for value in choices_value:
			if typeof(value) == TYPE_DICTIONARY and String(value.get("choice_id", "")) == choice_id:
				choice = value
				break
		if choice.is_empty():
			return _resolution_failure("choice_unavailable", "The selected Event choice is unavailable.")
		var choice_requirements := runtime_service.requirement_evaluator.evaluate(choice.get("requirements", {"all": []}), active_event.participants, active_event.context)
		if not bool(choice_requirements.get("eligible", false)):
			return {"resolved": false, "failure_reasons": choice_requirements.get("failure_reasons", []).duplicate(true), "effect_results": []}
	elif not choice_id.is_empty():
		return _resolution_failure("choice_unavailable", "This Event does not accept a choice.")
	var resolution_value = choice.get("resolution", null) if not choice.is_empty() else event.get("default_resolution", null)
	if typeof(resolution_value) != TYPE_DICTIONARY:
		return _resolution_failure("resolution_unavailable", "The Event resolution is unavailable.")
	var money_cost := _cost_amount(event.get("cost", null), "money") + _cost_amount(choice.get("cost", null), "money")
	var diamond_cost := _cost_amount(event.get("cost", null), "diamonds") + _cost_amount(choice.get("cost", null), "diamonds")
	if GameManager.family_money < money_cost or GameManager.diamonds < diamond_cost:
		return _resolution_failure("locked_cost", "The family cannot currently afford this Event choice.")
	var outcome := resolution_resolver.resolve(resolution_value, active_event.participants, active_event.context)
	if not bool(outcome.get("valid", false)):
		return {"resolved": false, "failure_reasons": outcome.get("failure_reasons", []).duplicate(true), "effect_results": []}
	var effects: Array = outcome.get("effects", [])
	var preflight := effect_resolver.preflight(effects, active_event.participants, active_event.context, GameManager.family_money - money_cost, GameManager.diamonds - diamond_cost)
	if not bool(preflight.get("valid", false)):
		return {"resolved": false, "failure_reasons": preflight.get("failure_reasons", []).duplicate(true), "effect_results": preflight.get("failure_reasons", []).duplicate(true)}
	GameManager.set_family_money(GameManager.family_money - money_cost)
	GameManager.set_diamonds(GameManager.diamonds - diamond_cost)
	var applied := effect_resolver.apply(preflight.get("plans", []), active_event.instance_id)
	if not bool(applied.get("success", false)):
		return {"resolved": false, "failure_reasons": applied.get("failure_reasons", []).duplicate(true), "effect_results": applied.get("effect_results", []).duplicate(true)}
	var finished_instance := active_event
	finished_instance.choice_id = choice_id if not choice.is_empty() else null
	finished_instance.outcome_id = outcome.get("outcome_id", null)
	finished_instance.effect_results = applied.get("effect_results", []).duplicate(true)
	if not _finish_active_event("completed"):
		return _resolution_failure("completion_failed", "The Event could not be completed.")
	return {"resolved": true, "instance": finished_instance.to_dictionary(), "choice_id": finished_instance.choice_id, "outcome_id": finished_instance.outcome_id, "effect_results": finished_instance.effect_results.duplicate(true), "resolution_details": outcome.get("details", {}).duplicate(true)}


func cancel_active_event() -> bool:
	return _finish_active_event("cancelled")


func expire_active_event() -> bool:
	return _finish_active_event("expired")


func get_queue_state() -> Dictionary:
	var queued: Array = []
	for instance in queued_events:
		queued.append(instance.to_dictionary())
	return {"active_event": active_event.to_dictionary() if active_event != null else {}, "queued_events": queued}


func export_runtime_state() -> Dictionary:
	var state := get_queue_state()
	state["scheduled_events"] = scheduled_events.duplicate(true)
	state["repeat_runtime_state"] = state_provider.completed_repeat_records.duplicate(true)
	state["cooldowns"] = state_provider.cooldown_records.duplicate(true)
	state["next_event_instance_number"] = runtime_service.get_next_instance_number()
	state["next_scheduled_event_number"] = _next_scheduled_event_number
	state["occurrence_by_instance"] = _occurrence_by_instance.duplicate(true)
	state["processed_selection_occurrences"] = _processed_selection_occurrences.keys()
	state["history"] = story_history.export_state()
	state["pool_random_state"] = pool_selector.export_state()
	state["resolution_random_state"] = resolution_resolver.export_state()
	state["queue_order_by_instance"] = _queue_order_by_instance.duplicate(true)
	state["next_queue_order"] = _next_queue_order
	state["calendar_occurrence_keys"] = _calendar_occurrence_keys.keys()
	state["pause_runtime_state"] = {"captured": _pause_state_captured, "pre_event_was_paused": _pre_event_was_paused, "pre_event_speed": _pre_event_speed}
	return state


func import_runtime_state(value) -> bool:
	last_import_error = ""
	if typeof(value) != TYPE_DICTIONARY:
		last_import_error = "Event runtime root must be a Dictionary."
		return false
	var state: Dictionary = value
	last_import_error = _runtime_state_validation_error(state)
	if not last_import_error.is_empty():
		return false
	_restore_time_state_if_owned()
	active_event = null
	queued_events.clear()
	var active_value = state.get("active_event", {})
	if typeof(active_value) == TYPE_DICTIONARY and not active_value.is_empty():
		active_event = EventInstance.from_dictionary(active_value)
	for member in state["queued_events"]:
		var instance := EventInstance.from_dictionary(member)
		queued_events.append(instance)
	scheduled_events.clear()
	for record_value in state["scheduled_events"]:
		scheduled_events.append((record_value as Dictionary).duplicate(true))
	if not story_history.import_state(state["history"]): return _import_dependency_failed("Story history rejected its validated state.")
	if not state_provider.import_state({"completed_repeat_records": state["repeat_runtime_state"], "cooldowns": state["cooldowns"]}): return _import_dependency_failed("Repeat/cooldown state was rejected.")
	if not pool_selector.import_state(state["pool_random_state"]): return _import_dependency_failed("Pool RNG state was rejected.")
	if not resolution_resolver.import_state(state["resolution_random_state"]): return _import_dependency_failed("Resolution RNG state was rejected.")
	runtime_service.reset_instance_counter(int(state.get("next_event_instance_number", 1)))
	_next_scheduled_event_number = maxi(1, int(state.get("next_scheduled_event_number", 1)))
	_next_queue_order = maxi(1, int(state.get("next_queue_order", 1)))
	_queue_order_by_instance = state.get("queue_order_by_instance", {}).duplicate(true) if typeof(state.get("queue_order_by_instance", null)) == TYPE_DICTIONARY else {}
	_occurrence_by_instance = state.get("occurrence_by_instance", {}).duplicate(true) if typeof(state.get("occurrence_by_instance", null)) == TYPE_DICTIONARY else {}
	_processed_selection_occurrences.clear()
	for key in state.get("processed_selection_occurrences", []): _processed_selection_occurrences[String(key)] = true
	_calendar_occurrence_keys.clear()
	for key in state.get("calendar_occurrence_keys", []): _calendar_occurrence_keys[String(key)] = true
	_rebuild_runtime_indexes()
	var pause_value = state.get("pause_runtime_state", {})
	if typeof(pause_value) == TYPE_DICTIONARY and bool(pause_value.get("captured", false)):
		_pause_state_captured = true
		_pre_event_was_paused = bool(pause_value.get("pre_event_was_paused", true))
		_pre_event_speed = float(pause_value.get("pre_event_speed", 1.0))
		TimeManager.pause()
	elif active_event != null and bool(registry.get_event(active_event.event_id).get("behavior", {}).get("blocking", false)):
		_capture_and_pause_time()
	_emit_queue_state()
	return true


func _runtime_state_validation_error(state: Dictionary) -> String:
	if not _is_json_compatible(state):
		return "Event runtime contains a non-JSON-compatible value or Dictionary key."
	var required_types := {
		"active_event": TYPE_DICTIONARY,
		"queued_events": TYPE_ARRAY,
		"scheduled_events": TYPE_ARRAY,
		"history": TYPE_ARRAY,
		"repeat_runtime_state": TYPE_ARRAY,
		"cooldowns": TYPE_ARRAY,
		"pool_random_state": TYPE_DICTIONARY,
		"resolution_random_state": TYPE_DICTIONARY,
		"occurrence_by_instance": TYPE_DICTIONARY,
		"processed_selection_occurrences": TYPE_ARRAY,
		"queue_order_by_instance": TYPE_DICTIONARY,
		"calendar_occurrence_keys": TYPE_ARRAY,
		"pause_runtime_state": TYPE_DICTIONARY,
	}
	for key in required_types:
		if typeof(state.get(key, null)) != int(required_types[key]):
			return "Event runtime field '%s' has the wrong type." % key
	for key in ["next_event_instance_number", "next_scheduled_event_number", "next_queue_order"]:
		if not _is_positive_integer(state.get(key, null)):
			return "Event runtime counter '%s' must be a positive integer." % key
	for key in ["processed_selection_occurrences", "calendar_occurrence_keys"]:
		for member in state[key]:
			if typeof(member) != TYPE_STRING:
				return "Event runtime ledger '%s' must contain only String keys." % key
	var active_value: Dictionary = state["active_event"]
	if not active_value.is_empty():
		var error := _instance_validation_error(active_value, "active")
		if not error.is_empty(): return error
	for member in state["queued_events"]:
		if typeof(member) != TYPE_DICTIONARY: return "Queued Event entries must be Dictionaries."
		var error := _instance_validation_error(member, "queued")
		if not error.is_empty(): return error
	for record in state["scheduled_events"]:
		if typeof(record) != TYPE_DICTIONARY: return "Scheduled Event entries must be Dictionaries."
		if String(record.get("scheduled_event_id", "")).is_empty() or String(record.get("event_id", "")).is_empty() or not bool(GameCalendar.parse_iso_date(String(record.get("due_date", ""))).get("valid", false)):
			return "A scheduled Event record has invalid identity or due_date."
		if String(record.get("status", "")) not in ["scheduled", "queued", "cancelled", "expired"] or typeof(record.get("participants", null)) != TYPE_DICTIONARY or typeof(record.get("context", null)) != TYPE_DICTIONARY or typeof(record.get("failure_reasons", null)) != TYPE_ARRAY:
			return "A scheduled Event record has an invalid lifecycle structure."
	for key in ["history", "repeat_runtime_state", "cooldowns"]:
		for member in state[key]:
			if typeof(member) != TYPE_DICTIONARY:
				return "Event runtime array '%s' must contain only Dictionaries." % key
	for key in ["pool_random_state", "resolution_random_state"]:
		var random_state: Dictionary = state[key]
		if not _is_integer_value(random_state.get("seed", null)) or not _is_integer_value(random_state.get("state", null)):
			return "Event RNG field '%s' has invalid seed/state values." % key
	var pause_state: Dictionary = state["pause_runtime_state"]
	if typeof(pause_state.get("captured", null)) != TYPE_BOOL or typeof(pause_state.get("pre_event_was_paused", null)) != TYPE_BOOL or typeof(pause_state.get("pre_event_speed", null)) not in [TYPE_INT, TYPE_FLOAT]:
		return "Event pause ownership state is malformed."
	return ""


func _instance_validation_error(value: Dictionary, expected_status: String) -> String:
	var event_id := String(value.get("event_id", ""))
	if String(value.get("instance_id", "")).is_empty() or event_id.is_empty():
		return "A restored %s Event has no stable identity." % expected_status
	if registry.get_event(event_id).is_empty():
		return "A restored %s Event references missing definition '%s'." % [expected_status, event_id]
	if String(value.get("status", "")) != expected_status:
		return "A restored Event has status '%s' where '%s' was required." % [String(value.get("status", "")), expected_status]
	if not _is_positive_integer(value.get("definition_version", null)) or typeof(value.get("trigger_type", null)) != TYPE_STRING or not bool(GameCalendar.parse_iso_date(String(value.get("created_date", ""))).get("valid", false)):
		return "A restored %s Event has invalid definition/lifecycle metadata." % expected_status
	if typeof(value.get("participants", null)) != TYPE_DICTIONARY or typeof(value.get("context", null)) != TYPE_DICTIONARY or typeof(value.get("effect_results", null)) != TYPE_ARRAY:
		return "A restored %s Event has invalid participant/context/result data." % expected_status
	return ""


func _is_positive_integer(value) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= 1
	if typeof(value) == TYPE_FLOAT:
		return is_finite(float(value)) and is_equal_approx(float(value), floor(float(value))) and int(value) >= 1
	return false


func _is_integer_value(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_finite(float(value)) and is_equal_approx(float(value), floor(float(value)))
	if typeof(value) == TYPE_STRING:
		var text := String(value)
		if text.begins_with("-"): text = text.substr(1)
		return not text.is_empty() and text.is_valid_int()
	return false


func _is_json_compatible(value) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_ARRAY:
			for member in value:
				if not _is_json_compatible(member): return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING or not _is_json_compatible(value[key]): return false
			return true
	return false


func _import_dependency_failed(message: String) -> bool:
	last_import_error = message
	return false


func _select_and_queue(events: Array, runtime_context: Dictionary, occurrence: Dictionary, forced_pool_id: String = "") -> Dictionary:
	var selection_occurrence_key := _selection_occurrence_key(occurrence, forced_pool_id)
	if _processed_selection_occurrences.has(selection_occurrence_key):
		return {"occurrence": occurrence.duplicate(true), "results": [], "selected_event_ids": [], "queued_instances": [], "duplicate_occurrence": true}
	_processed_selection_occurrences[selection_occurrence_key] = true
	var availability_by_id: Dictionary = {}
	var eligible_by_pool: Dictionary = {}
	var unpooled: Array = []
	var results: Array = []
	for event_value in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var event_id := String(event.get("event_id", ""))
		var availability := runtime_service.get_availability(event_id, runtime_context)
		results.append(availability)
		availability_by_id[event_id] = availability
		if String(availability.get("status", "")) != EventRuntimeService.AVAILABLE:
			continue
		var pool_id := forced_pool_id
		if pool_id.is_empty():
			pool_id = String(event.get("pool_id", event.get("trigger", {}).get("pool_id", "")))
		if pool_id.is_empty():
			unpooled.append(event)
		else:
			if not eligible_by_pool.has(pool_id):
				eligible_by_pool[pool_id] = []
			eligible_by_pool[pool_id].append(event)
	var selected: Array = pool_selector.resolve_exclusive_for_deterministic(unpooled)
	for pool_id_value in eligible_by_pool:
		var pool_record := registry.get_pool(String(pool_id_value))
		var pool_definition = pool_record.get("definition", {})
		if typeof(pool_definition) == TYPE_DICTIONARY:
			selected.append_array(pool_selector.select(pool_definition, eligible_by_pool[pool_id_value]))
	var queued: Array = []
	for event_value in selected:
		var event: Dictionary = event_value
		var instance := _queue_available_event(event, availability_by_id.get(String(event.get("event_id", "")), {}), occurrence, null, false)
		if instance != null:
			queued.append(instance.to_dictionary())
	if active_event == null:
		_activate_next_event()
	_emit_queue_state()
	return {"occurrence": occurrence.duplicate(true), "results": results, "selected_event_ids": selected.map(func(event): return String(event.get("event_id", ""))), "queued_instances": queued}


func _selection_occurrence_key(occurrence: Dictionary, pool_id: String) -> String:
	return "%s|%s|%s|%s|%s" % [
		String(occurrence.get("trigger_type", "")),
		String(occurrence.get("semantic_event", "")),
		String(occurrence.get("source", "")),
		String(occurrence.get("occurrence_id", "")),
		pool_id
	]


func _queue_available_event(event: Dictionary, availability: Dictionary, occurrence: Dictionary, source_instance_id = null, activate_immediately: bool = true) -> EventInstance:
	if String(availability.get("status", "")) != EventRuntimeService.AVAILABLE:
		return null
	var participants: Dictionary = availability.get("participants", {})
	var context: Dictionary = availability.get("context", {})
	var duplicate_key := _duplicate_key(String(event.get("event_id", "")), participants, context, String(occurrence.get("occurrence_id", "")))
	if _deduplication_keys.has(duplicate_key):
		return null
	var instance := runtime_service.create_instance_primitive(String(event.get("event_id", "")), String(occurrence.get("trigger_type", "")), participants, context, "queued", source_instance_id)
	if instance == null:
		return null
	_deduplication_keys[duplicate_key] = true
	_occurrence_by_instance[instance.instance_id] = occurrence.duplicate(true)
	_queue_order_by_instance[instance.instance_id] = _next_queue_order
	_next_queue_order += 1
	queued_events.append(instance)
	queued_events.sort_custom(Callable(self, "_queue_before"))
	event_queued.emit(instance.to_dictionary())
	if activate_immediately and active_event == null:
		_activate_next_event()
	if activate_immediately:
		_emit_queue_state()
	return instance


func _activate_next_event() -> void:
	while active_event == null and not queued_events.is_empty():
		var candidate: EventInstance = queued_events.pop_front()
		var availability: Dictionary = runtime_service.get_resolved_availability(candidate.event_id, candidate.participants, candidate.context)
		if String(availability.get("status", "")) != EventRuntimeService.AVAILABLE:
			candidate.mark_expired()
			event_expired.emit(candidate.to_dictionary(), availability.get("failure_reasons", []).duplicate(true))
			continue
		active_event = candidate
		active_event.mark_active(_current_date())
		var event: Dictionary = registry.get_event(active_event.event_id)
		if bool(event.get("behavior", {}).get("blocking", false)):
			_capture_and_pause_time()
		active_event_changed.emit(active_event.to_dictionary())
	_emit_queue_state()
	_maybe_restore_time_state()


func _finish_active_event(status: String) -> bool:
	if active_event == null:
		return false
	var finished := active_event
	var date_text := _current_date()
	match status:
		"completed":
			finished.mark_completed(date_text)
			var event := registry.get_event(finished.event_id)
			if not event.is_empty():
				state_provider.commit_completion(event, finished.participants, finished.context, date_text)
			event_completed.emit(finished.to_dictionary())
		"cancelled":
			finished.mark_cancelled()
			event_cancelled.emit(finished.to_dictionary())
		"expired":
			finished.mark_expired()
			event_expired.emit(finished.to_dictionary(), [])
		_:
			return false
	if story_history != null:
		story_history.append_instance(finished)
	active_event = null
	_activate_next_event()
	_maybe_restore_time_state()
	return true


func _queue_before(left: EventInstance, right: EventInstance) -> bool:
	var left_priority := int(registry.get_event(left.event_id).get("priority", 0))
	var right_priority := int(registry.get_event(right.event_id).get("priority", 0))
	if left_priority != right_priority:
		return left_priority > right_priority
	return int(_queue_order_by_instance.get(left.instance_id, 0)) < int(_queue_order_by_instance.get(right.instance_id, 0))


func _capture_and_pause_time() -> void:
	if not _pause_state_captured:
		_pause_state_captured = true
		_pre_event_was_paused = TimeManager.is_paused
		_pre_event_speed = TimeManager.get_speed_multiplier()
	TimeManager.pause()


func _has_blocking_work() -> bool:
	if active_event != null and bool(registry.get_event(active_event.event_id).get("behavior", {}).get("blocking", false)):
		return true
	for instance in queued_events:
		if bool(registry.get_event(instance.event_id).get("behavior", {}).get("blocking", false)):
			return true
	return false


func _maybe_restore_time_state() -> void:
	if _pause_state_captured and not _has_blocking_work():
		_restore_time_state_if_owned()


func _restore_time_state_if_owned() -> void:
	if not _pause_state_captured:
		return
	TimeManager.set_speed_multiplier(_pre_event_speed)
	if _pre_event_was_paused:
		TimeManager.pause()
	else:
		TimeManager.play()
	_pause_state_captured = false


func _make_occurrence(trigger_type: String, semantic_name: String, runtime_context: Dictionary, occurrence_key: String, source: String) -> Dictionary:
	var date_text := _current_date()
	var identity := occurrence_key
	if identity.is_empty():
		identity = "%s:%s:%s:%s:%s" % [trigger_type, semantic_name, date_text, source, JSON.stringify(_normalized_identity(runtime_context))]
	return {
		"occurrence_id": identity,
		"trigger_type": trigger_type,
		"semantic_event": semantic_name,
		"game_date": date_text,
		"source": source,
		"primary_character_id": int(runtime_context.get("trigger_character_id", runtime_context.get("context", {}).get("character_id", 0))),
		"context": (runtime_context.get("context", {}) as Dictionary).duplicate(true) if typeof(runtime_context.get("context", {})) == TYPE_DICTIONARY else {}
	}


func _duplicate_key(event_id: String, participants: Dictionary, context: Dictionary, occurrence_id: String) -> String:
	return "%s|%s|%s|%s" % [event_id, JSON.stringify(_normalized_identity(participants)), JSON.stringify(_normalized_identity(context)), occurrence_id]


func _normalized_identity(value):
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort_custom(func(left, right): return String(left) < String(right))
		for key in keys:
			result[String(key)] = _normalized_identity(value[key])
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for member in value:
			result.append(_normalized_identity(member))
		result.sort_custom(func(left, right): return JSON.stringify(left) < JSON.stringify(right))
		return result
	return value


func _parameters_match(parameters_value, runtime_context: Dictionary) -> bool:
	if typeof(parameters_value) != TYPE_DICTIONARY:
		return false
	var parameters: Dictionary = parameters_value
	var context = runtime_context.get("context", {})
	for key_value in parameters:
		var key := String(key_value)
		var actual = runtime_context.get(key, context.get(key, null) if typeof(context) == TYPE_DICTIONARY else null)
		if actual != parameters[key_value]:
			return false
	return true


func _emit_queue_state() -> void:
	var state := get_queue_state()
	queue_changed.emit(state["active_event"], state["queued_events"])


func _current_date() -> String:
	return TimeManager.get_iso_date_string()


func _cost_amount(value, currency: String) -> int:
	if typeof(value) != TYPE_DICTIONARY or String(value.get("currency", "")) != currency:
		return 0
	return maxi(0, int(value.get("amount", 0)))


func _resolution_failure(code: String, message: String) -> Dictionary:
	return {"resolved": false, "failure_reasons": [{"code": code, "message": message}], "effect_results": []}


func _rebuild_runtime_indexes() -> void:
	_deduplication_keys.clear()
	var instances: Array[EventInstance] = queued_events.duplicate()
	if active_event != null:
		instances.append(active_event)
	for instance in instances:
		var occurrence: Dictionary = _occurrence_by_instance.get(instance.instance_id, {})
		var occurrence_id := String(occurrence.get("occurrence_id", "imported:%s" % instance.instance_id))
		_deduplication_keys[_duplicate_key(instance.event_id, instance.participants, instance.context, occurrence_id)] = true
	queued_events.sort_custom(Callable(self, "_queue_before"))


func _connect_runtime_adapters() -> void:
	_connect_if_needed(TimeManager.date_changed, _on_date_changed)
	_connect_if_needed(GameManager.new_game_starting, _on_new_game_starting)
	_connect_if_needed(CharacterManager.character_born, _on_character_born)
	_connect_if_needed(CharacterManager.character_died, _on_character_died)
	_connect_if_needed(CharacterManager.age_reached, _on_character_age_reached)
	_connect_if_needed(CharacterManager.life_stage_changed, _on_character_life_stage_changed)
	_connect_if_needed(CharacterManager.character_retired, _on_character_retired)
	_connect_if_needed(EducationManager.education_event_requested, _on_education_event_requested)
	_connect_if_needed(EducationManager.major_selection_requested, _on_major_selection_requested)
	_connect_if_needed(EducationManager.school_enrolled, _on_school_enrolled)
	_connect_if_needed(EducationManager.school_graduated, _on_school_graduated)
	_connect_if_needed(CareerManager.job_offer_requested, _on_job_offer_requested)
	_connect_if_needed(CareerManager.job_offer_accepted, _on_job_offer_accepted)
	_connect_if_needed(CareerManager.external_job_removed, _on_external_job_removed)
	_connect_if_needed(HouseManager.house_upgraded, _on_house_upgraded)
	_connect_if_needed(BusinessManager.family_business_created, _on_business_created)
	_connect_if_needed(BusinessManager.family_business_upgraded, _on_business_upgraded)


func _connect_if_needed(source_signal: Signal, callable: Callable) -> void:
	if not source_signal.is_connected(callable):
		source_signal.connect(callable)


func _on_new_game_starting() -> void:
	reset_runtime_state()


func _on_date_changed(_date_text: String) -> void:
	process_calendar_date(_current_date())
	process_scheduled_due(_current_date())


func _on_character_born(character_id: int, parent_one_id: int, parent_two_id: int) -> void:
	dispatch_system_trigger("character_born", {"trigger_character_id": character_id, "trigger_participants": {"primary": character_id}, "context": {"character_id": character_id, "parent_ids": [parent_one_id, parent_two_id]}}, "character_born:%d:%s" % [character_id, _current_date()], "CharacterManager")


func _on_character_died(character_id: int, death_date: String) -> void:
	dispatch_system_trigger("character_died", {"trigger_character_id": character_id, "trigger_participants": {"primary": character_id}, "context": {"character_id": character_id, "death_date": death_date}}, "character_died:%d:%s" % [character_id, death_date], "CharacterManager")


func _on_character_age_reached(character_id: int, age: int) -> void:
	dispatch_system_trigger("age_reached", {"trigger_character_id": character_id, "trigger_participants": {"primary": character_id}, "context": {"character_id": character_id, "age": age}}, "age_reached:%d:%d:%s" % [character_id, age, _current_date()], "CharacterManager")


func _on_character_life_stage_changed(character_id: int, previous_stage: String, new_stage: String) -> void:
	dispatch_system_trigger("life_stage_changed", {"trigger_character_id": character_id, "trigger_participants": {"primary": character_id}, "context": {"character_id": character_id, "previous_stage": previous_stage, "life_stage": new_stage}}, "life_stage_changed:%d:%s:%s:%s" % [character_id, previous_stage, new_stage, _current_date()], "CharacterManager")


func _on_character_retired(character_id: int) -> void:
	dispatch_system_trigger("retired", {"trigger_character_id": character_id, "trigger_participants": {"primary": character_id}, "context": {"character_id": character_id}}, "retired:%d:%s" % [character_id, _current_date()], "CharacterManager")


func _on_education_event_requested(character_id: int, event_type: String, education_stage: String) -> void:
	dispatch_system_trigger("education_stage_due", {"trigger_character_id": character_id, "trigger_participants": {"primary": character_id}, "context": {"character_id": character_id, "event_type": event_type, "education_stage": education_stage}}, "education_stage_due:%d:%s:%s" % [character_id, event_type, _current_date()], "EducationManager")


func _on_major_selection_requested(character_id: int) -> void:
	dispatch_system_trigger("education_stage_due", {"trigger_character_id": character_id, "trigger_participants": {"primary": character_id}, "context": {"character_id": character_id, "event_type": "major_selection", "education_stage": "university"}}, "education_stage_due:%d:major_selection:%s" % [character_id, _current_date()], "EducationManager")


func _on_school_enrolled(character_id: int, school_id: int) -> void:
	var school := EducationManager.get_school_by_id(school_id)
	if school.is_empty():
		return
	var education_stage := String(school.get("education_stage", ""))
	var school_type := String(school.get("school_type", ""))
	dispatch_system_trigger("school_enrolled", {"trigger_character_id": character_id, "trigger_participants": {"primary": character_id}, "context": {"character_id": character_id, "school_id": school_id, "education_stage": education_stage, "school_type": school_type}}, "school_enrolled:%d:%d:%s" % [character_id, school_id, _current_date()], "EducationManager")


func _on_school_graduated(character_id: int, school_id: int, graduation_date: String) -> void:
	var school := EducationManager.get_school_by_id(school_id)
	if school.is_empty():
		return
	var context := {"character_id": character_id, "school_id": school_id, "education_stage": String(school.get("education_stage", "")), "graduation_date": graduation_date}
	var character := CharacterManager.get_character_by_id(character_id)
	if not character.is_empty() and character.get("major_id", null) != null:
		context["major_id"] = int(character.get("major_id", 0))
	dispatch_system_trigger("school_graduated", {"trigger_character_id": character_id, "trigger_participants": {"primary": character_id}, "context": context}, "school_graduated:%d:%d:%s" % [character_id, school_id, graduation_date], "EducationManager")


func _on_job_offer_requested(character_id: int, job_id: int, company_id: String, salary: int) -> void:
	var context := {"character_id": character_id, "job_id": job_id, "company_id": company_id, "salary": salary}
	dispatch_system_trigger("job_offer_requested", {"trigger_character_id": character_id, "trigger_participants": {"primary": character_id}, "context": context}, "job_offer_requested:%d:%d:%s:%s" % [character_id, job_id, company_id, _current_date()], "CareerManager")


func _on_job_offer_accepted(
	character_id: int,
	previous_job_id,
	previous_company_id,
	previous_salary: int,
	job_id: int,
	company_id: String,
	salary: int
) -> void:
	var context := {
		"character_id": character_id,
		"previous_job_id": previous_job_id,
		"previous_company_id": previous_company_id,
		"previous_salary": previous_salary,
		"job_id": job_id,
		"company_id": company_id,
		"salary": salary
	}

	dispatch_system_trigger(
		"job_offer_accepted",
		{
			"trigger_character_id": character_id,
			"trigger_participants": {
				"primary": character_id
			},
			"context": context
		},
		"job_offer_accepted:%d:%d:%s:%s"
		% [
			character_id,
			job_id,
			company_id,
			_current_date()
		],
		"CareerManager"
	)

func _on_external_job_removed(
	character_id: int,
	previous_job_id: int,
	previous_company_id: String,
	previous_salary: int
) -> void:
	var context := {
		"character_id": character_id,
		"previous_job_id": previous_job_id,
		"previous_company_id": previous_company_id,
		"previous_salary": previous_salary
	}

	dispatch_system_trigger(
		"external_job_removed",
		{
			"trigger_character_id": character_id,
			"trigger_participants": {
				"primary": character_id
			},
			"context": context
		},
		"external_job_removed:%d:%d:%s:%s"
		% [
			character_id,
			previous_job_id,
			previous_company_id,
			_current_date()
		],
		"CareerManager"
	)

func _on_house_upgraded(house_instance_id: String, new_level: int, _upgrade_cost: int) -> void:
	dispatch_system_trigger("house_upgraded", {"context": {"house_instance_id": house_instance_id, "new_level": new_level}}, "house_upgraded:%s:%d" % [house_instance_id, new_level], "HouseManager")


func _on_business_created(
	business_instance_id: String,
	business_type_id: String,
	plot_id: String,
	purchase_cost: int
) -> void:
	dispatch_system_trigger(
		"business_purchased",
		{
			"context": {
				"business_instance_id": business_instance_id,
				"business_type_id": business_type_id,
				"plot_id": plot_id,
				"purchase_cost": purchase_cost,
				"new_level": 1
			}
		},
		"business_purchased:%s" % business_instance_id,
		"BusinessManager"
	)


func _on_business_upgraded(
	business_instance_id: String,
	new_level: int,
	upgrade_cost: int
) -> void:
	var business := BusinessManager.get_business_by_instance_id(
		business_instance_id
	)
	dispatch_system_trigger(
		"business_upgraded",
		{
			"context": {
				"business_instance_id": business_instance_id,
				"business_type_id": String(
					business.get(
						"business_type_id",
						""
					)
				),
				"new_level": new_level,
				"upgrade_cost": upgrade_cost
			}
		},
		"business_upgraded:%s:%d"
		% [
			business_instance_id,
			new_level
		],
		"BusinessManager"
	)
