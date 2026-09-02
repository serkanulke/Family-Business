class_name EventStoryHistory
extends EventHistoryQueryProvider


var records: Array[Dictionary] = []


func append_instance(instance: EventInstance) -> Dictionary:
	var record := instance.to_dictionary()
	records.append(record.duplicate(true))
	return record


func has_seen(event_id: String, participants: Dictionary, context: Dictionary) -> bool:
	return _find(event_id, "", "", false, participants, context)


func has_completed(event_id: String, participants: Dictionary, context: Dictionary) -> bool:
	return _find(event_id, "", "", true, participants, context)


func has_choice(event_id: String, choice_id: String, participants: Dictionary, context: Dictionary) -> bool:
	return _find(event_id, choice_id, "", true, participants, context)


func has_outcome(event_id: String, outcome_id: String, participants: Dictionary, context: Dictionary) -> bool:
	return _find(event_id, "", outcome_id, true, participants, context)


func reset() -> void:
	records.clear()


func export_state() -> Array:
	return records.duplicate(true)


func import_state(value) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var imported: Array[Dictionary] = []
	for member in value:
		if typeof(member) != TYPE_DICTIONARY or String(member.get("instance_id", "")).is_empty() or String(member.get("event_id", "")).is_empty():
			return false
		imported.append((member as Dictionary).duplicate(true))
	records = imported
	return true


func _find(
	event_id: String,
	choice_id: String,
	outcome_id: String,
	require_completed: bool,
	participants: Dictionary,
	context: Dictionary
) -> bool:
	for record in records:
		if String(record.get("event_id", "")) != event_id:
			continue
		if require_completed and String(record.get("status", "")) != "completed":
			continue
		if not choice_id.is_empty() and String(record.get("choice_id", "")) != choice_id:
			continue
		if not outcome_id.is_empty() and String(record.get("outcome_id", "")) != outcome_id:
			continue
		if not _bindings_match(record.get("participants", {}), participants):
			continue
		if not _bindings_match(record.get("context", {}), context):
			continue
		return true
	return false


func _bindings_match(recorded_value, requested: Dictionary) -> bool:
	if requested.is_empty():
		return true
	if typeof(recorded_value) != TYPE_DICTIONARY:
		return false
	var recorded: Dictionary = recorded_value
	for key in requested:
		if not recorded.has(key) or recorded[key] != requested[key]:
			return false
	return true
