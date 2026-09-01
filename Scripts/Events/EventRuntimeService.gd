class_name EventRuntimeService
extends RefCounted


const AVAILABLE := "available"
const LOCKED_REQUIREMENTS := "locked_requirements"
const LOCKED_COOLDOWN := "locked_cooldown"
const LOCKED_COST := "locked_cost"
const COMPLETED_NON_REPEATABLE := "completed_non_repeatable"
const REQUIRES_PARTICIPANTS := "requires_participants"
const DISABLED := "disabled"


var registry: EventDataRegistry
var query_provider: EventRuntimeQueryProvider
var state_provider: EventAvailabilityStateProvider
var requirement_evaluator: RequirementEvaluator
var participant_resolver: EventParticipantResolver
var _next_instance_number := 1


func _init(
	p_registry: EventDataRegistry,
	p_query_provider: EventRuntimeQueryProvider = null,
	p_state_provider: EventAvailabilityStateProvider = null
) -> void:
	registry = p_registry
	query_provider = p_query_provider if p_query_provider != null else EventRuntimeQueryProvider.new()
	state_provider = p_state_provider if p_state_provider != null else EventAvailabilityStateProvider.new()
	requirement_evaluator = RequirementEvaluator.new(query_provider)
	participant_resolver = EventParticipantResolver.new(query_provider, requirement_evaluator)


func get_definition(event_id: String, enabled_only: bool = false) -> Dictionary:
	return registry.get_event(event_id, enabled_only)


func get_definitions_by_category(category: String, enabled_only: bool = false) -> Array:
	return registry.get_events_for_category(category, enabled_only)


func get_definitions_by_domain(domain: String, enabled_only: bool = false) -> Array:
	return registry.get_events_for_domain(domain, enabled_only)


func get_definitions_by_manual_source(source: String, enabled_only: bool = false) -> Array:
	return registry.get_events_for_manual_source(source, enabled_only)


func get_definitions_by_pool(pool_id: String, enabled_only: bool = false) -> Array:
	return registry.get_events_for_pool(pool_id, enabled_only)


func get_content(event_id: String) -> Dictionary:
	return registry.get_content(event_id)


func get_presentation(event_id: String) -> Dictionary:
	return registry.get_presentation(event_id)


func get_availability(event_id: String, runtime_context: Dictionary = {}) -> Dictionary:
	var event := registry.get_event(event_id)
	if event.is_empty():
		return _availability(event_id, DISABLED, [_failure("definition_missing", "Event definition is unavailable.")])
	if not bool(event.get("enabled", false)):
		return _availability(event_id, DISABLED, [_failure("definition_disabled", "This Event is currently disabled.")], event)

	var participant_result := participant_resolver.resolve(event, runtime_context)
	if not bool(participant_result.get("valid", false)):
		return _availability(
			event_id, LOCKED_REQUIREMENTS, participant_result.get("failure_reasons", []), event, participant_result
		)
	if not bool(participant_result.get("ready", false)):
		return _availability(
			event_id, REQUIRES_PARTICIPANTS, [], event, participant_result
		)

	var participants: Dictionary = participant_result.get("participants", {})
	var context: Dictionary = participant_result.get("context", {})
	var requirement_result := requirement_evaluator.evaluate(event.get("requirements", {"all": []}), participants, context)
	if not bool(requirement_result.get("eligible", false)):
		return _availability(
			event_id, LOCKED_REQUIREMENTS, requirement_result.get("failure_reasons", []), event, participant_result
		)
	if state_provider.is_completed_non_repeatable(event, participants, context):
		return _availability(
			event_id,
			COMPLETED_NON_REPEATABLE,
			[_failure("completed_non_repeatable", "This Event has already been completed.")],
			event,
			participant_result
		)
	if state_provider.is_on_cooldown(event, participants, context):
		return _availability(
			event_id,
			LOCKED_COOLDOWN,
			[_failure("locked_cooldown", "This Event is still on cooldown.")],
			event,
			participant_result
		)
	if not query_provider.can_afford_cost(event.get("cost", null)):
		return _availability(
			event_id,
			LOCKED_COST,
			[_failure("locked_cost", "The family cannot currently afford this Event.")],
			event,
			participant_result
		)
	return _availability(event_id, AVAILABLE, [], event, participant_result)


func discover_manual(
	source: String,
	runtime_context: Dictionary = {},
	mode: String = "",
	pool_id: String = ""
) -> Dictionary:
	var results: Array = []
	for event_value in registry.get_events_for_manual_source(source):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var trigger_value = event.get("trigger", {})
		if typeof(trigger_value) != TYPE_DICTIONARY:
			continue
		var trigger: Dictionary = trigger_value
		var event_mode := String(trigger.get("mode", ""))
		if not mode.is_empty() and event_mode != mode:
			continue
		if not pool_id.is_empty() and String(trigger.get("pool_id", "")) != pool_id:
			continue
		results.append(get_availability(String(event.get("event_id", "")), runtime_context))
	return {
		"source": source,
		"mode": mode,
		"pool_id": pool_id,
		"events": results,
		"weighted_selection_performed": false
	}


func create_activatable_instance(
	event_id: String,
	runtime_context: Dictionary = {},
	source_instance_id = null
) -> Dictionary:
	# Discovery results are deliberately ignored; every value is read again here.
	var availability := get_availability(event_id, runtime_context)
	if String(availability.get("status", "")) != AVAILABLE:
		return {"created": false, "availability": availability, "instance": null}
	var event := registry.get_event(event_id, true)
	if event.is_empty():
		return {"created": false, "availability": get_availability(event_id, runtime_context), "instance": null}
	var participants: Dictionary = availability.get("participants", {})
	var context: Dictionary = availability.get("context", {})
	var validation := participant_resolver.validate_existing(event, participants, context)
	if not bool(validation.get("ready", false)):
		return {
			"created": false,
			"availability": _availability(event_id, LOCKED_REQUIREMENTS, validation.get("failure_reasons", []), event, validation),
			"instance": null
		}
	var requirement_result := requirement_evaluator.evaluate(event.get("requirements", {"all": []}), participants, context)
	if not bool(requirement_result.get("eligible", false)):
		return {
			"created": false,
			"availability": _availability(event_id, LOCKED_REQUIREMENTS, requirement_result.get("failure_reasons", []), event, validation),
			"instance": null
		}
	var instance := create_instance_primitive(
		event_id,
		String(event.get("trigger", {}).get("type", "manual")),
		participants,
		context,
		"active",
		source_instance_id
	)
	return {"created": instance != null, "availability": availability, "instance": instance}


func create_instance_primitive(
	event_id: String,
	trigger_type: String,
	participants: Dictionary,
	context: Dictionary = {},
	status: String = "active",
	source_instance_id = null
) -> EventInstance:
	if registry.get_event(event_id).is_empty():
		return null
	var instance_id := "evt_%08d" % _next_instance_number
	_next_instance_number += 1
	return EventInstance.new(
		instance_id,
		event_id,
		EventDataRegistry.SUPPORTED_SCHEMA_VERSION,
		trigger_type,
		query_provider.get_current_date(),
		status,
		participants,
		context,
		source_instance_id
	)


func get_next_instance_number() -> int:
	return _next_instance_number


func reset_instance_counter(next_number: int = 1) -> void:
	_next_instance_number = maxi(1, next_number)


func get_resolved_availability(
	event_id: String,
	participants: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var event := registry.get_event(event_id)
	if event.is_empty():
		return _availability(event_id, DISABLED, [_failure("definition_missing", "Event definition is unavailable.")])
	if not bool(event.get("enabled", false)):
		return _availability(event_id, DISABLED, [_failure("definition_disabled", "This Event is currently disabled.")], event)
	var validation := participant_resolver.validate_existing(event, participants, context)
	if not bool(validation.get("ready", false)):
		return _availability(event_id, LOCKED_REQUIREMENTS, validation.get("failure_reasons", []), event, validation)
	var requirement_result := requirement_evaluator.evaluate(event.get("requirements", {"all": []}), participants, context)
	if not bool(requirement_result.get("eligible", false)):
		return _availability(event_id, LOCKED_REQUIREMENTS, requirement_result.get("failure_reasons", []), event, validation)
	if state_provider.is_completed_non_repeatable(event, participants, context):
		return _availability(event_id, COMPLETED_NON_REPEATABLE, [_failure("completed_non_repeatable", "This Event has already been completed.")], event, validation)
	if state_provider.is_on_cooldown(event, participants, context):
		return _availability(event_id, LOCKED_COOLDOWN, [_failure("locked_cooldown", "This Event is still on cooldown.")], event, validation)
	if not query_provider.can_afford_cost(event.get("cost", null)):
		return _availability(event_id, LOCKED_COST, [_failure("locked_cost", "The family cannot currently afford this Event.")], event, validation)
	return _availability(event_id, AVAILABLE, [], event, validation)


func _availability(
	event_id: String,
	status: String,
	failure_reasons: Array,
	event: Dictionary = {},
	participant_result: Dictionary = {}
) -> Dictionary:
	return {
		"event_id": event_id,
		"status": status,
		"available": status == AVAILABLE,
		"failure_reasons": failure_reasons.duplicate(true),
		"participants": _dictionary_copy(participant_result.get("participants", {})),
		"context": _dictionary_copy(participant_result.get("context", {})),
		"pending_selections": _array_copy(participant_result.get("pending_selections", [])),
		"candidate_groups": _dictionary_copy(participant_result.get("candidate_groups", {})),
		"content": _dictionary_copy(event.get("content", {})),
		"presentation": _dictionary_copy(event.get("presentation", {})),
		"definition": event.duplicate(true)
	}


func _failure(code: String, message: String) -> Dictionary:
	return {"code": code, "message": message}


func _dictionary_copy(value) -> Dictionary:
	return value.duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _array_copy(value) -> Array:
	return value.duplicate(true) if typeof(value) == TYPE_ARRAY else []
