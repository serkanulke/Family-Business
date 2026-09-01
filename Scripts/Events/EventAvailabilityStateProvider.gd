class_name EventAvailabilityStateProvider
extends RefCounted


# Neutral Phase 2 boundary. Phase 3/4 providers will own cooldown/repeat state.
func is_on_cooldown(
	_event: Dictionary,
	_participants: Dictionary,
	_context: Dictionary
) -> bool:
	return false


func is_completed_non_repeatable(
	_event: Dictionary,
	_participants: Dictionary,
	_context: Dictionary
) -> bool:
	return false
