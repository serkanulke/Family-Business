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
		"source_instance_id": source_instance_id
	}


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
