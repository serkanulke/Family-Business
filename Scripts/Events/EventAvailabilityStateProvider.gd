class_name EventAvailabilityStateProvider
extends RefCounted


var completed_repeat_records: Array[Dictionary] = []
var cooldown_records: Array[Dictionary] = []
var current_date_provider: Callable


func _init(p_current_date_provider: Callable = Callable()) -> void:
	current_date_provider = p_current_date_provider


func is_on_cooldown(event: Dictionary, participants: Dictionary, context: Dictionary) -> bool:
	var cooldown_value = event.get("cooldown", null)
	if typeof(cooldown_value) != TYPE_DICTIONARY:
		return false
	var cooldown: Dictionary = cooldown_value
	var event_id := String(event.get("event_id", ""))
	var scope := String(cooldown.get("scope", ""))
	var scope_key := get_cooldown_scope_key(event, participants, context)
	if event_id.is_empty() or scope_key.is_empty():
		return false
	var current_date := _get_current_date()
	for record_value in cooldown_records:
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = record_value
		if String(record.get("event_id", "")) == event_id and String(record.get("scope", "")) == scope and String(record.get("scope_key", "")) == scope_key:
			return GameCalendar.compare(current_date, String(record.get("available_date", ""))) < 0
	return false


func is_completed_non_repeatable(event: Dictionary, participants: Dictionary, context: Dictionary) -> bool:
	var mode := String(event.get("repeat", {}).get("mode", "repeatable"))
	if mode == "repeatable":
		return false
	var repeat_key := get_repeat_key(event, participants, context)
	return not repeat_key.is_empty() and _has_repeat_key(repeat_key)


func commit_completion(event: Dictionary, participants: Dictionary, context: Dictionary, completion_date: String = "") -> Dictionary:
	var date_text := completion_date if not completion_date.is_empty() else _get_current_date()
	var result := {"repeat_record": {}, "cooldown_record": {}}
	var repeat_mode := String(event.get("repeat", {}).get("mode", "repeatable"))
	if repeat_mode != "repeatable":
		var repeat_key := get_repeat_key(event, participants, context)
		if not repeat_key.is_empty() and not _has_repeat_key(repeat_key):
			var repeat_record := {"event_id": String(event.get("event_id", "")), "mode": repeat_mode, "repeat_key": repeat_key, "completed_date": date_text}
			completed_repeat_records.append(repeat_record)
			result["repeat_record"] = repeat_record.duplicate(true)
	var cooldown_value = event.get("cooldown", null)
	if typeof(cooldown_value) == TYPE_DICTIONARY:
		var cooldown: Dictionary = cooldown_value
		var scope_key := get_cooldown_scope_key(event, participants, context)
		var available_date := GameCalendar.add_interval(date_text, String(cooldown.get("unit", "")), int(cooldown.get("value", 0)))
		if not scope_key.is_empty() and not available_date.is_empty():
			var record := {"event_id": String(event.get("event_id", "")), "scope": String(cooldown.get("scope", "")), "scope_key": scope_key, "started_date": date_text, "available_date": available_date}
			_replace_cooldown_record(record)
			result["cooldown_record"] = record.duplicate(true)
	return result


func get_repeat_key(event: Dictionary, participants: Dictionary, context: Dictionary) -> String:
	var event_id := String(event.get("event_id", ""))
	var mode := String(event.get("repeat", {}).get("mode", "repeatable"))
	match mode:
		"once": return "%s|once" % event_id
		"once_per_character":
			var character_id := _primary_character_id(event, participants)
			return "%s|character:%d" % [event_id, character_id] if character_id > 0 else ""
		"once_per_character_pair":
			var ids := _character_ids(event, participants)
			return "%s|pair:%d:%d" % [event_id, ids[0], ids[1]] if ids.size() >= 2 else ""
		"once_per_family": return "%s|family" % event_id
		"once_per_house":
			var house_id := _house_id(event, participants, context)
			return "%s|house:%s" % [event_id, house_id] if not house_id.is_empty() else ""
		"once_per_business":
			var business_id := _business_id(event, participants, context)
			return "%s|business:%s" % [event_id, business_id] if not business_id.is_empty() else ""
		"repeatable": return ""
	return ""


func get_cooldown_scope_key(event: Dictionary, participants: Dictionary, context: Dictionary) -> String:
	var cooldown_value = event.get("cooldown", {})
	if typeof(cooldown_value) != TYPE_DICTIONARY:
		return ""
	match String(cooldown_value.get("scope", "")):
		"event": return "event:%s" % String(event.get("event_id", ""))
		"character":
			var character_id := _primary_character_id(event, participants)
			return "character:%d" % character_id if character_id > 0 else ""
		"character_pair":
			var ids := _character_ids(event, participants)
			return "pair:%d:%d" % [ids[0], ids[1]] if ids.size() >= 2 else ""
		"family": return "family"
		"house":
			var house_id := _house_id(event, participants, context)
			return "house:%s" % house_id if not house_id.is_empty() else ""
		"business":
			var business_id := _business_id(event, participants, context)
			return "business:%s" % business_id if not business_id.is_empty() else ""
	return ""


func reset() -> void:
	completed_repeat_records.clear()
	cooldown_records.clear()


func export_state() -> Dictionary:
	return {"completed_repeat_records": completed_repeat_records.duplicate(true), "cooldowns": cooldown_records.duplicate(true)}


func _character_ids(event: Dictionary, participants: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	var definitions = event.get("participants", {})
	if typeof(definitions) == TYPE_DICTIONARY:
		for name_value in definitions:
			var name := String(name_value)
			var definition = definitions[name]
			if typeof(definition) == TYPE_DICTIONARY and String(definition.get("type", "")) in ["character", "character_group", "relationship_npc"]:
				_append_character_values(ids, participants.get(name, null))
	if ids.is_empty():
		for value in participants.values():
			_append_character_values(ids, value)
	ids.sort()
	return ids


func _primary_character_id(event: Dictionary, participants: Dictionary) -> int:
	var explicit_primary := int(participants.get("primary", 0))
	if explicit_primary > 0:
		return explicit_primary
	var definitions = event.get("participants", {})
	if typeof(definitions) == TYPE_DICTIONARY:
		for name_value in definitions:
			var name := String(name_value)
			var definition = definitions[name]
			if typeof(definition) != TYPE_DICTIONARY or String(definition.get("type", "")) not in ["character", "relationship_npc"]:
				continue
			var participant_id := int(participants.get(name, 0))
			if participant_id > 0:
				return participant_id
	var ids := _character_ids(event, participants)
	return ids[0] if not ids.is_empty() else 0


func _append_character_values(ids: Array[int], value) -> void:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		var id := int(value)
		if id > 0 and id not in ids:
			ids.append(id)
	elif typeof(value) == TYPE_ARRAY:
		for member in value:
			_append_character_values(ids, member)


func _house_id(event: Dictionary, participants: Dictionary, context: Dictionary) -> String:
	var value := _participant_id_for_type(event, participants, "house")
	return value if not value.is_empty() else String(context.get("house_instance_id", ""))


func _business_id(event: Dictionary, participants: Dictionary, context: Dictionary) -> String:
	var value := _participant_id_for_type(event, participants, "business")
	return value if not value.is_empty() else String(context.get("business_instance_id", ""))


func _participant_id_for_type(event: Dictionary, participants: Dictionary, participant_type: String) -> String:
	var definitions = event.get("participants", {})
	if typeof(definitions) != TYPE_DICTIONARY:
		return ""
	for name_value in definitions:
		var name := String(name_value)
		var definition = definitions[name]
		if typeof(definition) == TYPE_DICTIONARY and String(definition.get("type", "")) == participant_type:
			return String(participants.get(name, ""))
	return ""


func _replace_cooldown_record(record: Dictionary) -> void:
	for index in cooldown_records.size():
		var current: Dictionary = cooldown_records[index]
		if String(current.get("event_id", "")) == String(record.get("event_id", "")) and String(current.get("scope", "")) == String(record.get("scope", "")) and String(current.get("scope_key", "")) == String(record.get("scope_key", "")):
			cooldown_records[index] = record.duplicate(true)
			return
	cooldown_records.append(record.duplicate(true))


func _has_repeat_key(repeat_key: String) -> bool:
	for record_value in completed_repeat_records:
		if typeof(record_value) == TYPE_DICTIONARY and String(record_value.get("repeat_key", "")) == repeat_key:
			return true
	return false


func _get_current_date() -> String:
	if current_date_provider.is_valid():
		return String(current_date_provider.call())
	return TimeManager.get_iso_date_string()
