class_name EventInstance
extends RefCounted


var instance_id: String
var event_id: String
var definition_version: int
var trigger_type: String
var created_date: String
var started_date = null
var completed_date = null
var status: String
var participants: Dictionary
var context: Dictionary
var source_instance_id
var choice_id = null
var outcome_id = null
var effect_results: Array = []


func _init(
	p_instance_id: String,
	p_event_id: String,
	p_definition_version: int,
	p_trigger_type: String,
	p_created_date: String,
	p_status: String,
	p_participants: Dictionary,
	p_context: Dictionary = {},
	p_source_instance_id = null
) -> void:
	instance_id = p_instance_id
	event_id = p_event_id
	definition_version = p_definition_version
	trigger_type = p_trigger_type
	created_date = p_created_date
	status = p_status
	participants = p_participants.duplicate(true)
	context = p_context.duplicate(true)
	source_instance_id = p_source_instance_id


func to_dictionary() -> Dictionary:
	return {
		"instance_id": instance_id,
		"event_id": event_id,
		"definition_version": definition_version,
		"trigger_type": trigger_type,
		"created_date": created_date,
		"started_date": started_date,
		"completed_date": completed_date,
		"status": status,
		"participants": participants.duplicate(true),
		"context": context.duplicate(true),
		"choice_id": choice_id,
		"outcome_id": outcome_id,
		"effect_results": effect_results.duplicate(true),
		"source_instance_id": source_instance_id
	}


static func from_dictionary(value: Dictionary) -> EventInstance:
	var instance := EventInstance.new(
		String(value.get("instance_id", "")),
		String(value.get("event_id", "")),
		int(value.get("definition_version", 1)),
		String(value.get("trigger_type", "")),
		String(value.get("created_date", "")),
		String(value.get("status", "queued")),
		value.get("participants", {}) if typeof(value.get("participants", null)) == TYPE_DICTIONARY else {},
		value.get("context", {}) if typeof(value.get("context", null)) == TYPE_DICTIONARY else {},
		value.get("source_instance_id", null)
	)
	instance.started_date = value.get("started_date", null)
	instance.completed_date = value.get("completed_date", null)
	instance.choice_id = value.get("choice_id", null)
	instance.outcome_id = value.get("outcome_id", null)
	instance.effect_results = value.get("effect_results", []).duplicate(true) if typeof(value.get("effect_results", null)) == TYPE_ARRAY else []
	return instance


func get_resolved_content() -> Dictionary:
	return EventPresentationResolver.resolve_instance_content(self)


func mark_active(date_text: String) -> void:
	status = "active"
	started_date = date_text


func mark_completed(date_text: String) -> void:
	status = "completed"
	completed_date = date_text


func mark_cancelled() -> void:
	status = "cancelled"


func mark_expired() -> void:
	status = "expired"
