class_name EventResolutionResolver
extends RefCounted


var query_provider: EventRuntimeQueryProvider
var requirement_evaluator: RequirementEvaluator
var random := RandomNumberGenerator.new()


func _init(p_query_provider: EventRuntimeQueryProvider, seed: int = 0) -> void:
	query_provider = p_query_provider
	requirement_evaluator = RequirementEvaluator.new(query_provider)
	random.seed = seed


func resolve(resolution: Dictionary, participants: Dictionary, context: Dictionary) -> Dictionary:
	match String(resolution.get("mode", "")):
		"deterministic":
			return {"valid": true, "mode": "deterministic", "outcome_id": null, "effects": _effects(resolution)}
		"weighted":
			return _resolve_weighted(resolution, participants, context)
		"score_check":
			return _resolve_score_check(resolution, participants, context)
	return {"valid": false, "failure_reasons": [_failure("invalid_resolution", "Event resolution is unavailable.")]}


func export_state() -> Dictionary:
	# Preserve the complete 64-bit RNG stream through JSON save files.
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


func _resolve_weighted(resolution: Dictionary, participants: Dictionary, context: Dictionary) -> Dictionary:
	var weighted: Array[Dictionary] = []
	var total := 0.0
	for value in resolution.get("outcomes", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var outcome: Dictionary = value
		var weight := float(outcome.get("weight", 0.0))
		for modifier_value in outcome.get("weight_modifiers", []):
			if typeof(modifier_value) != TYPE_DICTIONARY:
				continue
			var modifier: Dictionary = modifier_value
			if bool(requirement_evaluator.evaluate(modifier.get("requirements", {}), participants, context).get("eligible", false)):
				weight += float(modifier.get("add_weight", 0.0))
		weight = maxf(weight, 0.0)
		if weight > 0.0:
			weighted.append({"outcome": outcome, "weight": weight})
			total += weight
	if total <= 0.0:
		return {"valid": false, "failure_reasons": [_failure("no_weighted_outcome", "No weighted outcome is currently available.")]}
	var roll := random.randf() * total
	var cumulative := 0.0
	for entry in weighted:
		cumulative += float(entry["weight"])
		if roll < cumulative:
			return _outcome_result("weighted", entry["outcome"], {"roll": roll, "total_weight": total})
	return _outcome_result("weighted", weighted.back()["outcome"], {"roll": roll, "total_weight": total})


func _resolve_score_check(resolution: Dictionary, participants: Dictionary, context: Dictionary) -> Dictionary:
	var score := 0.0
	var source_results: Array = []
	for value in resolution.get("sources", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = value
		var requirement := {
			"type": String(source.get("source", "")),
			"target": String(source.get("target", "")),
			"operator": ">=",
			"value": -999999999.0,
		}
		if source.has("stat"):
			requirement["stat"] = source["stat"]
		var query := query_provider.get_requirement_value(requirement, participants, context)
		if not bool(query.get("valid", false)) or typeof(query.get("actual", null)) not in [TYPE_INT, TYPE_FLOAT]:
			return {"valid": false, "failure_reasons": [_failure("score_source_unavailable", "A score source is no longer available.")]}
		var contribution := float(query["actual"]) * float(source.get("weight", 0.0))
		score += contribution
		source_results.append({"source": source.duplicate(true), "actual": query["actual"], "contribution": contribution})
	var threshold := float(resolution.get("threshold", 0.0))
	var result_key := "success" if score >= threshold else "failure"
	var outcome = resolution.get(result_key, {})
	if typeof(outcome) != TYPE_DICTIONARY:
		return {"valid": false, "failure_reasons": [_failure("score_outcome_unavailable", "The score outcome is unavailable.")]}
	return _outcome_result("score_check", outcome, {"score": score, "threshold": threshold, "sources": source_results})


func _outcome_result(mode: String, outcome: Dictionary, details: Dictionary) -> Dictionary:
	return {"valid": true, "mode": mode, "outcome_id": String(outcome.get("outcome_id", "")), "effects": _effects(outcome), "details": details}


func _effects(value: Dictionary) -> Array:
	var effects = value.get("effects", [])
	return effects.duplicate(true) if typeof(effects) == TYPE_ARRAY else []


func _failure(code: String, message: String) -> Dictionary:
	return {"code": code, "message": message}
