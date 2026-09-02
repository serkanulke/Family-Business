class_name EventHistoryQueryProvider
extends RefCounted


# Neutral query contract. EventStoryHistory supplies the Phase 4A runtime state.
func has_seen(_event_id: String, _participants: Dictionary, _context: Dictionary) -> bool:
	return false


func has_completed(_event_id: String, _participants: Dictionary, _context: Dictionary) -> bool:
	return false


func has_choice(
	_event_id: String,
	_choice_id: String,
	_participants: Dictionary,
	_context: Dictionary
) -> bool:
	return false


func has_outcome(
	_event_id: String,
	_outcome_id: String,
	_participants: Dictionary,
	_context: Dictionary
) -> bool:
	return false
