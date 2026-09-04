class_name EventPoolSelector
extends RefCounted


var random := RandomNumberGenerator.new()


func _init(seed: int = 0) -> void:
	set_seed(seed)


func set_seed(seed: int) -> void:
	random.seed = seed


func export_state() -> Dictionary:
	# RandomNumberGenerator uses 64-bit values. Decimal Strings survive JSON
	# round trips without the precision loss possible for JSON numbers.
	return {"seed": str(random.seed), "state": str(random.state)}


func import_state(value) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	if not _is_integer_value(value.get("seed", null)) or not _is_integer_value(value.get("state", null)):
		return false
	random.seed = int(value["seed"])
	random.state = int(value["state"])
	return true


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


func passes_activation(pool: Dictionary) -> bool:
	var chance := float(pool.get("activation_chance", 1.0))
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return random.randf() < chance


func select(pool: Dictionary, eligible_events: Array) -> Array:
	var mode := String(pool.get("selection_mode", ""))
	var candidates := _dictionary_events(eligible_events)
	if candidates.is_empty():
		return []
	match mode:
		"weighted_one":
			var chosen := _weighted_take(candidates)
			return [] if chosen.is_empty() else [chosen]
		"weighted_multiple":
			return _weighted_multiple(candidates, int(pool.get("max_events", 0)))
		"all_eligible":
			var selected := _resolve_exclusive_groups(candidates)
			var maximum := int(pool.get("max_events", 0))
			return selected.slice(0, maximum) if maximum > 0 and selected.size() > maximum else selected
	return []


func resolve_exclusive_for_deterministic(eligible_events: Array) -> Array:
	return _resolve_exclusive_groups(_dictionary_events(eligible_events))


func _weighted_multiple(candidates: Array, maximum: int) -> Array:
	var selected: Array = []
	var remaining := candidates.duplicate(true)
	while not remaining.is_empty() and selected.size() < maximum:
		var chosen := _weighted_take(remaining)
		if chosen.is_empty():
			break
		selected.append(chosen)
		var chosen_id := String(chosen.get("event_id", ""))
		var group := _optional_string(chosen.get("exclusive_group", null))
		for index in range(remaining.size() - 1, -1, -1):
			var candidate: Dictionary = remaining[index]
			if String(candidate.get("event_id", "")) == chosen_id or (not group.is_empty() and _optional_string(candidate.get("exclusive_group", null)) == group):
				remaining.remove_at(index)
	return selected


func _resolve_exclusive_groups(candidates: Array) -> Array:
	var selected: Array = []
	var groups: Dictionary = {}
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value
		var group := _optional_string(candidate.get("exclusive_group", null))
		if group.is_empty():
			selected.append(candidate)
		else:
			if not groups.has(group):
				groups[group] = []
			groups[group].append(candidate)
	for group_value in groups.values():
		var chosen := _weighted_take(group_value)
		if not chosen.is_empty():
			selected.append(chosen)
	return selected


func _weighted_take(candidates: Array) -> Dictionary:
	var total := 0.0
	for candidate_value in candidates:
		if typeof(candidate_value) == TYPE_DICTIONARY:
			total += maxf(0.0, float(candidate_value.get("weight", 0.0)))
	if total <= 0.0:
		return {}
	var roll := random.randf() * total
	var cumulative := 0.0
	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_value
		cumulative += maxf(0.0, float(candidate.get("weight", 0.0)))
		if roll < cumulative:
			return candidate.duplicate(true)
	return (candidates.back() as Dictionary).duplicate(true)


func _dictionary_events(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			result.append((value as Dictionary).duplicate(true))
	return result


func _optional_string(value) -> String:
	return "" if value == null else String(value)
