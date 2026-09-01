class_name RequirementEvaluator
extends RefCounted


var query_provider: EventRuntimeQueryProvider


func _init(p_query_provider: EventRuntimeQueryProvider) -> void:
	query_provider = p_query_provider


func evaluate(
	requirements,
	participants: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	if typeof(requirements) != TYPE_DICTIONARY:
		return _result(false, [_reason(
			"invalid_requirement", "Event requirements are unavailable."
		)])
	return _evaluate_group(requirements, participants, context)


func _evaluate_group(group: Dictionary, participants: Dictionary, context: Dictionary) -> Dictionary:
	var has_group := false
	var failures: Array = []
	for key in ["all", "any", "none"]:
		if not group.has(key):
			continue
		has_group = true
		var children_value = group[key]
		if typeof(children_value) != TYPE_ARRAY:
			failures.append(_reason("invalid_requirement", "Event requirements are unavailable."))
			continue
		var children: Array = children_value
		match key:
			"all":
				for child in children:
					var child_result := _evaluate_node(child, participants, context)
					if not bool(child_result.get("eligible", false)):
						failures.append_array(child_result.get("failure_reasons", []))
			"any":
				var any_passed := false
				var any_failures: Array = []
				for child in children:
					var child_result := _evaluate_node(child, participants, context)
					if bool(child_result.get("eligible", false)):
						any_passed = true
					else:
						any_failures.append_array(child_result.get("failure_reasons", []))
				if not any_passed:
					if any_failures.is_empty():
						any_failures.append(_reason("any_requirement_failed", "At least one requirement must be met."))
					failures.append_array(any_failures)
			"none":
				for child in children:
					var child_result := _evaluate_node(child, participants, context)
					if bool(child_result.get("eligible", false)):
						failures.append(_negated_reason(child, participants, context))
	if not has_group:
		failures.append(_reason("invalid_requirement", "Event requirements are unavailable."))
	return _result(failures.is_empty(), failures)


func _evaluate_node(node, participants: Dictionary, context: Dictionary) -> Dictionary:
	if typeof(node) != TYPE_DICTIONARY:
		return _result(false, [_reason("invalid_requirement", "Event requirements are unavailable.")])
	var definition: Dictionary = node
	if definition.has("type"):
		return _evaluate_requirement(definition, participants, context)
	return _evaluate_group(definition, participants, context)


func _evaluate_requirement(
	requirement: Dictionary,
	participants: Dictionary,
	context: Dictionary
) -> Dictionary:
	var query := query_provider.get_requirement_value(requirement, participants, context)
	if not bool(query.get("valid", false)):
		return _result(false, [_reason(
			"runtime_value_unavailable",
			String(query.get("message", "Authoritative runtime value is unavailable.")),
			requirement
		)])
	var comparison := _compare(
		query.get("actual", null),
		query.get("expected", null),
		String(requirement.get("operator", "")),
		String(query.get("match_mode", "normal")),
		String(requirement.get("type", ""))
	)
	if not bool(comparison.get("valid", false)):
		return _result(false, [_reason(
			"invalid_runtime_value",
			"Current data cannot be compared safely for this requirement.",
			requirement
		)])
	if bool(comparison.get("matched", false)):
		return _result(true, [])
	return _result(false, [_failure_reason(requirement, query)])


func _compare(actual, expected, operator: String, match_mode: String, requirement_type: String) -> Dictionary:
	if match_mode == "membership":
		return _compare_membership(actual, expected, operator)
	if requirement_type == "date":
		if typeof(actual) != TYPE_STRING or typeof(expected) != TYPE_STRING or not _is_iso_date(actual) or not _is_iso_date(expected):
			return {"valid": false, "matched": false}
		return _ordered_compare(actual, expected, operator)
	match operator:
		"==", "!=":
			if not _compatible_equality_types(actual, expected):
				return {"valid": false, "matched": false}
			var equal: bool = actual == expected
			return {"valid": true, "matched": equal if operator == "==" else not equal}
		">", ">=", "<", "<=":
			if not _is_number(actual) or not _is_number(expected):
				return {"valid": false, "matched": false}
			return _ordered_compare(float(actual), float(expected), operator)
		"in", "not_in":
			if typeof(expected) != TYPE_ARRAY:
				return {"valid": false, "matched": false}
			var present := _strict_array_has(expected, actual)
			return {"valid": true, "matched": present if operator == "in" else not present}
		"contains", "not_contains":
			var contains_result := _contains(actual, expected)
			if not bool(contains_result.get("valid", false)):
				return contains_result
			var contains_value := bool(contains_result.get("matched", false))
			return {"valid": true, "matched": contains_value if operator == "contains" else not contains_value}
	return {"valid": false, "matched": false}


func _compare_membership(actual, expected, operator: String) -> Dictionary:
	if typeof(actual) != TYPE_ARRAY:
		return {"valid": false, "matched": false}
	var present := false
	if typeof(expected) == TYPE_ARRAY:
		for value in expected:
			if _strict_array_has(actual, value):
				present = true
				break
	else:
		present = _strict_array_has(actual, expected)
	match operator:
		"==", "contains": return {"valid": true, "matched": present}
		"!=", "not_contains": return {"valid": true, "matched": not present}
		"in":
			if typeof(expected) != TYPE_ARRAY: return {"valid": false, "matched": false}
			return {"valid": true, "matched": present}
		"not_in":
			if typeof(expected) != TYPE_ARRAY: return {"valid": false, "matched": false}
			return {"valid": true, "matched": not present}
	return {"valid": false, "matched": false}


func _ordered_compare(actual, expected, operator: String) -> Dictionary:
	match operator:
		"==": return {"valid": true, "matched": actual == expected}
		"!=": return {"valid": true, "matched": actual != expected}
		">": return {"valid": true, "matched": actual > expected}
		">=": return {"valid": true, "matched": actual >= expected}
		"<": return {"valid": true, "matched": actual < expected}
		"<=": return {"valid": true, "matched": actual <= expected}
	return {"valid": false, "matched": false}


func _contains(actual, expected) -> Dictionary:
	if typeof(actual) == TYPE_ARRAY:
		return {"valid": true, "matched": _strict_array_has(actual, expected)}
	if typeof(actual) == TYPE_STRING and typeof(expected) == TYPE_STRING:
		return {"valid": true, "matched": String(actual).contains(String(expected))}
	return {"valid": false, "matched": false}


func _failure_reason(requirement: Dictionary, query: Dictionary) -> Dictionary:
	var requirement_type := String(requirement.get("type", ""))
	var expected_display := String(query.get("expected_label", requirement.get("value", "")))
	var label := String(query.get("label", query_provider.get_requirement_label(requirement)))
	var operator := String(requirement.get("operator", ""))
	var message := "Requires %s %s %s." % [label, _operator_words(operator), expected_display]
	match requirement_type:
		"lifestyle_score": message = "Requires Lifestyle %s %s." % [_operator_words(operator), expected_display]
		"job": message = "Requires %s career." % expected_display
		"job_tag": message = "Requires %s career." % expected_display.replace("_", " ").capitalize()
		"house_level": message = "Requires House Level %s." % expected_display
		"business_level": message = "Requires Business Level %s." % expected_display
		"entitlement": message = "Requires %s access." % String(requirement.get("value", "")).replace("_", " ").capitalize()
		"has_spouse":
			if requirement.get("value", true) == false: message = "Character must be single."
			else: message = "Character must have a spouse."
		"is_alive": message = "Character must be alive." if requirement.get("value", true) else "Character must not be alive."
		"is_family_member": message = "Character must be a family member." if requirement.get("value", true) else "Character must not be a family member."
	return _reason("requirement_failed", message, requirement, expected_display)


func _negated_reason(node, participants: Dictionary, context: Dictionary) -> Dictionary:
	if typeof(node) == TYPE_DICTIONARY and node.has("type"):
		var requirement: Dictionary = node
		var query := query_provider.get_requirement_value(requirement, participants, context)
		var label := query_provider.get_requirement_label(requirement)
		var expected_display := String(query.get("expected_label", requirement.get("value", "")))
		return _reason("none_requirement_failed", "Must not meet %s: %s." % [label, expected_display], requirement, expected_display)
	return _reason("none_requirement_failed", "This excluded requirement combination must not be met.")


func _reason(
	code: String,
	message: String,
	requirement: Dictionary = {},
	expected_display: String = ""
) -> Dictionary:
	var result := {"code": code, "message": message}
	if not requirement.is_empty():
		result["requirement_type"] = String(requirement.get("type", ""))
		result["target"] = String(requirement.get("target", ""))
		result["operator"] = String(requirement.get("operator", ""))
	if not expected_display.is_empty():
		result["expected_display"] = expected_display
	return result


func _result(eligible: bool, reasons: Array) -> Dictionary:
	return {"eligible": eligible, "failure_reasons": reasons.duplicate(true)}


func _operator_words(operator: String) -> String:
	return {
		"==": "of", "!=": "other than", ">": "above", ">=": "at least",
		"<": "below", "<=": "at most", "in": "in", "not_in": "not in",
		"contains": "containing", "not_contains": "not containing"
	}.get(operator, operator)


func _compatible_equality_types(left, right) -> bool:
	if _is_number(left) and _is_number(right): return true
	return typeof(left) == typeof(right)


func _strict_array_has(values: Array, expected) -> bool:
	for value in values:
		if _compatible_equality_types(value, expected) and value == expected:
			return true
	return false


func _is_number(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


func _is_iso_date(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^\\d{4}-\\d{2}-\\d{2}$")
	return regex.search(value) != null
