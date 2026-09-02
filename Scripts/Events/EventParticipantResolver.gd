class_name EventParticipantResolver
extends RefCounted


var query_provider: EventRuntimeQueryProvider
var requirement_evaluator: RequirementEvaluator


func _init(
	p_query_provider: EventRuntimeQueryProvider,
	p_requirement_evaluator: RequirementEvaluator
) -> void:
	query_provider = p_query_provider
	requirement_evaluator = p_requirement_evaluator


func resolve(event: Dictionary, runtime_context: Dictionary = {}) -> Dictionary:
	var definitions_value = event.get("participants", {})
	if typeof(definitions_value) != TYPE_DICTIONARY:
		return _resolution(false, {}, {}, [], [_failure("invalid_participants", "Event participants are unavailable.")], {})
	var definitions: Dictionary = definitions_value
	var participants: Dictionary = {}
	var context := _context_dictionary(runtime_context)
	var pending: Array = []
	var failures: Array = []
	var candidate_groups: Dictionary = {}
	var unresolved: Array = definitions.keys()
	var made_progress := true

	while not unresolved.is_empty() and made_progress:
		made_progress = false
		for name_value in unresolved.duplicate():
			var name := String(name_value)
			var definition_value = definitions[name]
			if typeof(definition_value) != TYPE_DICTIONARY:
				failures.append(_failure("invalid_participant", "Participant '%s' is invalid." % name, name))
				unresolved.erase(name_value)
				made_progress = true
				continue
			var definition: Dictionary = definition_value
			var resolved := _resolve_participant(event, name, definition, participants, runtime_context, context)
			if bool(resolved.get("deferred", false)):
				continue
			unresolved.erase(name_value)
			made_progress = true
			if bool(resolved.get("pending", false)):
				pending.append(name)
				if String(definition.get("type", "")) == "character_group":
					candidate_groups[name] = prepare_character_group(name, definition, participants, context)
				continue
			if not bool(resolved.get("valid", false)):
				failures.append(_failure(
					"participant_unavailable",
					String(resolved.get("message", "Required participant is unavailable.")),
					name
				))
				continue
			participants[name] = resolved.get("value", null)
			if String(definition.get("type", "")) == "character_group":
				candidate_groups[name] = prepare_character_group(name, definition, participants, context)

	for name_value in unresolved:
		failures.append(_failure(
			"participant_dependency_unresolved",
			"Participant '%s' could not be resolved from its required context." % String(name_value),
			String(name_value)
		))

	_validate_resolved_participants(event, definitions, participants, context, failures)
	return _resolution(failures.is_empty(), participants, context, pending, failures, candidate_groups)


func prepare_character_group(
	name: String,
	definition: Dictionary,
	participants: Dictionary,
	context: Dictionary
) -> Dictionary:
	var candidates: Array = []
	var requirements = definition.get("requirements", {"all": []})
	for character_id in query_provider.get_family_character_ids():
		var candidate_participants := participants.duplicate(true)
		candidate_participants[name] = character_id
		var result := requirement_evaluator.evaluate(requirements, candidate_participants, context)
		candidates.append({
			"character_id": character_id,
			"eligible": bool(result.get("eligible", false)),
			"failure_reasons": result.get("failure_reasons", []).duplicate(true)
		})
	return {
		"participant": name,
		"minimum": int(definition.get("min", 1)),
		"maximum": int(definition.get("max", 1)),
		"selection_ui": _dictionary_copy(definition.get("selection_ui", {})),
		"candidates": candidates
	}


func validate_existing(
	event: Dictionary,
	participants: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var definitions_value = event.get("participants", {})
	if typeof(definitions_value) != TYPE_DICTIONARY:
		return _resolution(false, participants, context, [], [_failure("invalid_participants", "Event participants are unavailable.")], {})
	var failures: Array = []
	_validate_resolved_participants(event, definitions_value, participants, context, failures)
	return _resolution(failures.is_empty(), participants, context, [], failures, {})


func _resolve_participant(
	event: Dictionary,
	name: String,
	definition: Dictionary,
	participants: Dictionary,
	runtime_context: Dictionary,
	context: Dictionary
) -> Dictionary:
	var participant_type := String(definition.get("type", ""))
	var source := String(definition.get("source", ""))
	var selected := _dictionary(runtime_context.get("selected_participants", {}))
	match source:
		"trigger":
			var trigger := _dictionary(runtime_context.get("trigger_participants", {}))
			var value = trigger.get(name, runtime_context.get("trigger_character_id", null) if name == "primary" else null)
			return _validate_resolved_value(
				participant_type,
				value,
				name,
				_allows_dead_trigger_character(event, name, definition)
			)
		"player_selected":
			if not selected.has(name):
				return {"valid": true, "pending": true}
			var value = selected[name]
			if participant_type == "character_group":
				return _validate_group_selection(name, definition, value, participants, context)
			return _validate_resolved_value(participant_type, value, name)
		"relation":
			var from_name := String(definition.get("from", ""))
			if not participants.has(from_name):
				return {"deferred": true}
			var from_id := int(participants[from_name])
			var candidates := query_provider.get_relation_ids(from_id, String(definition.get("relation", "")))
			var relation_selections := _dictionary(runtime_context.get("relation_selections", {}))
			if relation_selections.has(name):
				var chosen := int(relation_selections[name])
				if not candidates.has(chosen):
					return {"valid": false, "message": "Selected %s is no longer a valid relation." % name}
				return {"valid": true, "value": chosen}
			if candidates.size() == 1:
				return {"valid": true, "value": candidates[0]}
			if candidates.size() > 1:
				return {"valid": true, "pending": true}
			return {"valid": false, "message": "Required %s relation is unavailable." % String(definition.get("relation", ""))}
		"relationship_npc":
			if selected.has(name):
				var chosen := int(selected[name])
				if not query_provider.get_relationship_npc_ids(_primary_id(participants)).has(chosen):
					return {"valid": false, "message": "Selected Relationship character is unavailable."}
				return {"valid": true, "value": chosen}
			var context_id := int(context.get("relationship_npc_id", 0))
			if context_id > 0:
				return _validate_resolved_value("relationship_npc", context_id, name)
			var candidates := query_provider.get_relationship_npc_ids(_primary_id(participants))
			if candidates.size() == 1: return {"valid": true, "value": candidates[0]}
			if candidates.size() > 1: return {"valid": true, "pending": true}
			return {"valid": false, "message": "No eligible Relationship character is available."}
		"primary_house":
			if not participants.has("primary"): return {"deferred": true}
			var house_id := query_provider.get_character_house_id(int(participants["primary"]))
			return _validate_resolved_value("house", house_id, name)
		"owned_business":
			var business_ids := query_provider.get_owned_business_ids()
			var chosen := String(selected.get(name, context.get("business_instance_id", "")))
			if not chosen.is_empty():
				if not business_ids.has(chosen): return {"valid": false, "message": "Selected family Business is unavailable."}
				return {"valid": true, "value": chosen}
			if business_ids.size() == 1: return {"valid": true, "value": business_ids[0]}
			if business_ids.size() > 1: return {"valid": true, "pending": true}
			return {"valid": false, "message": "No owned family Business is available."}
		"context":
			var value = context.get(name, null)
			if value == null:
				match participant_type:
					"house": value = context.get("house_instance_id", null)
					"business": value = context.get("business_instance_id", null)
					"relationship_npc", "character": value = context.get("character_id", null)
			return _validate_resolved_value(participant_type, value, name)
	return {"valid": false, "message": "Unsupported participant source '%s'." % source}


func _validate_group_selection(
	name: String,
	definition: Dictionary,
	value,
	participants: Dictionary,
	context: Dictionary
) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return {"valid": false, "message": "Participant group '%s' selection must be a list." % name}
	var selection: Array = value
	var minimum := int(definition.get("min", 1))
	var maximum := int(definition.get("max", 1))
	if selection.size() < minimum:
		return {"valid": false, "message": "Select at least %d family members." % minimum}
	if selection.size() > maximum:
		return {"valid": false, "message": "Select no more than %d family members." % maximum}
	var normalized: Array[int] = []
	for character_id_value in selection:
		var character_id := int(character_id_value)
		if normalized.has(character_id):
			return {"valid": false, "message": "The same family member cannot be selected twice."}
		normalized.append(character_id)
		if not query_provider.get_family_character_ids().has(character_id):
			return {"valid": false, "message": "Selected family member is unavailable."}
		var candidate_participants := participants.duplicate(true)
		candidate_participants[name] = character_id
		var eligibility := requirement_evaluator.evaluate(definition.get("requirements", {"all": []}), candidate_participants, context)
		if not bool(eligibility.get("eligible", false)):
			var reasons: Array = eligibility.get("failure_reasons", [])
			var message := String(reasons[0].get("message", "Selected family member is ineligible.")) if not reasons.is_empty() else "Selected family member is ineligible."
			return {"valid": false, "message": message}
	return {"valid": true, "value": normalized}


func _validate_resolved_participants(
	event: Dictionary,
	definitions: Dictionary,
	participants: Dictionary,
	context: Dictionary,
	failures: Array
) -> void:
	for name_value in definitions:
		var name := String(name_value)
		if not participants.has(name):
			continue
		var definition_value = definitions[name]
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_value
		var participant_type := String(definition.get("type", ""))
		var value = participants[name]
		if not query_provider.entity_exists(
			participant_type,
			value,
			_allows_dead_trigger_character(event, name, definition)
		):
			failures.append(_failure("participant_invalid", "Participant '%s' is no longer available." % name, name))
			continue
		if definition.has("requirements"):
			if participant_type == "character_group":
				for character_id in value:
					var candidate_participants := participants.duplicate(true)
					candidate_participants[name] = character_id
					var result := requirement_evaluator.evaluate(definition["requirements"], candidate_participants, context)
					if not bool(result.get("eligible", false)):
						failures.append_array(result.get("failure_reasons", []))
			else:
				var result := requirement_evaluator.evaluate(definition["requirements"], participants, context)
				if not bool(result.get("eligible", false)):
					failures.append_array(result.get("failure_reasons", []))


func _validate_resolved_value(
	participant_type: String,
	value,
	name: String,
	include_dead_character: bool = false
) -> Dictionary:
	if value == null or (typeof(value) == TYPE_STRING and String(value).is_empty()):
		return {"valid": false, "message": "Required participant '%s' was not supplied." % name}
	if not query_provider.entity_exists(
		participant_type,
		value,
		include_dead_character
	):
		return {"valid": false, "message": "Participant '%s' is unavailable." % name}
	return {"valid": true, "value": value}


func _allows_dead_trigger_character(
	event: Dictionary,
	name: String,
	definition: Dictionary
) -> bool:
	var trigger = event.get("trigger", {})
	return (
		typeof(trigger) == TYPE_DICTIONARY
		and String(trigger.get("type", "")) == "system"
		and String(trigger.get("event", "")) == "character_died"
		and name == "primary"
		and String(definition.get("type", "")) == "character"
		and String(definition.get("source", "")) == "trigger"
	)


func _context_dictionary(runtime_context: Dictionary) -> Dictionary:
	var value = runtime_context.get("context", {})
	return value.duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _dictionary(value) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _dictionary_copy(value) -> Dictionary:
	return value.duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _primary_id(participants: Dictionary) -> int:
	return int(participants.get("primary", 0))


func _failure(code: String, message: String, participant: String = "") -> Dictionary:
	var result := {"code": code, "message": message}
	if not participant.is_empty(): result["participant"] = participant
	return result


func _resolution(
	valid: bool,
	participants: Dictionary,
	context: Dictionary,
	pending: Array,
	failures: Array,
	candidate_groups: Dictionary
) -> Dictionary:
	return {
		"valid": valid,
		"ready": valid and pending.is_empty(),
		"participants": participants.duplicate(true),
		"context": context.duplicate(true),
		"pending_selections": pending.duplicate(),
		"failure_reasons": failures.duplicate(true),
		"candidate_groups": candidate_groups.duplicate(true)
	}
