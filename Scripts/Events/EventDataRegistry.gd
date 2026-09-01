class_name EventDataRegistry
extends RefCounted


const EVENT_DATA_DIRECTORY := "res://Resources/Json/Events"
const SUPPORTED_SCHEMA_VERSION := 1
const CATEGORY_FILES: Dictionary = {
	"relationship": "relationship.json",
	"education": "education.json",
	"job_offer": "job_offer.json",
	"career": "career.json",
	"household": "household.json",
	"lifestyle": "lifestyle.json",
	"family_agency": "family_agency.json",
	"age_lifecycle": "age_lifecycle.json",
	"business": "business.json",
	"health": "health.json",
	"finance": "finance.json",
	"general": "general.json"
}


var diagnostics: Array[Dictionary] = []
var files_by_category: Dictionary = {}
var pools_by_id: Dictionary = {}
var events_by_id: Dictionary = {}
var events_by_category: Dictionary = {}
var events_by_pool: Dictionary = {}
var events_by_domain: Dictionary = {}
var events_by_manual_source: Dictionary = {}
var is_valid := false


func load_all(
	event_data_directory: String = EVENT_DATA_DIRECTORY
) -> bool:
	var sources: Dictionary = {}
	var read_diagnostics: Array[Dictionary] = []

	for category_value in CATEGORY_FILES:
		var category := String(category_value)
		var file_name := String(CATEGORY_FILES[category])
		var source_path := event_data_directory.path_join(file_name)

		if not FileAccess.file_exists(source_path):
			read_diagnostics.append(_make_diagnostic(
				source_path,
				"",
				"$",
				"Required Event category file is missing."
			))
			continue

		var file := FileAccess.open(source_path, FileAccess.READ)

		if file == null:
			read_diagnostics.append(_make_diagnostic(
				source_path,
				"",
				"$",
				"Event category file could not be opened."
			))
			continue

		sources[source_path] = file.get_as_text()

	var loaded := load_from_json_sources(sources, true)

	if not read_diagnostics.is_empty():
		diagnostics.append_array(read_diagnostics)
		_clear_indexes()
		is_valid = false
		return false

	return loaded


func load_from_json_sources(
	sources: Dictionary,
	require_all_categories: bool = false
) -> bool:
	_clear_indexes()
	diagnostics.clear()
	is_valid = false

	var parsed_documents: Dictionary = {}
	var seen_categories: Dictionary = {}

	for source_value in sources:
		var source := String(source_value)
		var file_name := source.get_file()
		var category := file_name.get_basename()

		if not CATEGORY_FILES.has(category):
			diagnostics.append(_make_diagnostic(
				source,
				"",
				"$",
				"Unknown Event category filename '%s'." % file_name
			))
			continue

		if String(CATEGORY_FILES[category]) != file_name:
			diagnostics.append(_make_diagnostic(
				source,
				"",
				"$",
				"Event category filename must be '%s'."
				% String(CATEGORY_FILES[category])
			))
			continue

		if seen_categories.has(category):
			diagnostics.append(_make_diagnostic(
				source,
				"",
				"$",
				"Category '%s' was supplied more than once." % category
			))
			continue

		seen_categories[category] = true
		var json := JSON.new()
		var parse_result := json.parse(String(sources[source]))

		if parse_result != OK:
			diagnostics.append(_make_diagnostic(
				source,
				"",
				"$",
				"Malformed JSON at line %d: %s"
				% [json.get_error_line(), json.get_error_message()]
			))
			continue

		if typeof(json.data) != TYPE_DICTIONARY:
			diagnostics.append(_make_diagnostic(
				source,
				"",
				"$",
				"Event category root must be a Dictionary."
			))
			continue

		parsed_documents[category] = {
			"source": source,
			"data": json.data
		}

	if require_all_categories:
		for category_value in CATEGORY_FILES:
			var category := String(category_value)

			if seen_categories.has(category):
				continue

			var expected_path := EVENT_DATA_DIRECTORY.path_join(
				String(CATEGORY_FILES[category])
			)
			diagnostics.append(_make_diagnostic(
				expected_path,
				"",
				"$",
				"Required Event category source was not supplied."
			))

	var validator := EventDataValidator.new()
	validator.validate_documents(parsed_documents)
	diagnostics.append_array(validator.diagnostics)

	if not diagnostics.is_empty():
		return false

	files_by_category = parsed_documents.duplicate(true)
	pools_by_id = validator.validated_pools_by_id.duplicate(true)
	events_by_id = validator.validated_events_by_id.duplicate(true)
	events_by_category = validator.validated_events_by_category.duplicate(true)
	events_by_pool = validator.validated_events_by_pool.duplicate(true)
	_build_runtime_indexes()
	is_valid = true
	return true


func get_event(event_id: String, enabled_only: bool = false) -> Dictionary:
	if not is_valid:
		return {}
	var event_value = events_by_id.get(event_id, {})
	if typeof(event_value) != TYPE_DICTIONARY:
		return {}
	var event: Dictionary = event_value
	if enabled_only and not bool(event.get("enabled", false)):
		return {}
	return event.duplicate(true)


func get_pool(pool_id: String) -> Dictionary:
	if not is_valid:
		return {}
	return pools_by_id.get(pool_id, {})


func get_events_for_category(category: String, enabled_only: bool = false) -> Array:
	if not is_valid:
		return []
	return _filter_enabled(events_by_category.get(category, []), enabled_only)


func get_events_for_pool(pool_id: String, enabled_only: bool = false) -> Array:
	if not is_valid:
		return []
	return _filter_enabled(events_by_pool.get(pool_id, []), enabled_only)


func get_events_for_domain(domain: String, enabled_only: bool = false) -> Array:
	if not is_valid:
		return []
	return _filter_enabled(events_by_domain.get(domain, []), enabled_only)


func get_events_for_manual_source(source: String, enabled_only: bool = false) -> Array:
	if not is_valid:
		return []
	return _filter_enabled(events_by_manual_source.get(source, []), enabled_only)


func get_content(event_id: String) -> Dictionary:
	var event := get_event(event_id)
	var value = event.get("content", {})
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func get_presentation(event_id: String) -> Dictionary:
	var event := get_event(event_id)
	var value = event.get("presentation", {})
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func get_diagnostics() -> Array[Dictionary]:
	return diagnostics.duplicate(true)


func get_diagnostic_text() -> String:
	var lines: PackedStringArray = []

	for diagnostic in diagnostics:
		var event_context := ""
		var event_id := String(diagnostic.get("event_id", ""))

		if not event_id.is_empty():
			event_context = " event_id=%s" % event_id

		lines.append(
			"%s%s %s: %s"
			% [
				String(diagnostic.get("source", "<unknown>")),
				event_context,
				String(diagnostic.get("path", "$")),
				String(diagnostic.get("message", "Validation error"))
			]
		)

	return "\n".join(lines)


func _clear_indexes() -> void:
	files_by_category.clear()
	pools_by_id.clear()
	events_by_id.clear()
	events_by_category.clear()
	events_by_pool.clear()
	events_by_domain.clear()
	events_by_manual_source.clear()


func _build_runtime_indexes() -> void:
	events_by_domain.clear()
	events_by_manual_source.clear()
	for event_value in events_by_id.values():
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var domain := String(event.get("domain", ""))
		if not domain.is_empty():
			if not events_by_domain.has(domain):
				events_by_domain[domain] = []
			events_by_domain[domain].append(event)
		var trigger_value = event.get("trigger", {})
		if typeof(trigger_value) != TYPE_DICTIONARY:
			continue
		var trigger: Dictionary = trigger_value
		if String(trigger.get("type", "")) != "manual":
			continue
		var source := String(trigger.get("source", ""))
		if source.is_empty():
			continue
		if not events_by_manual_source.has(source):
			events_by_manual_source[source] = []
		events_by_manual_source[source].append(event)


func _filter_enabled(values, enabled_only: bool) -> Array:
	var result: Array = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = value
		if enabled_only and not bool(event.get("enabled", false)):
			continue
		result.append(event.duplicate(true))
	return result


func _make_diagnostic(
	source: String,
	event_id: String,
	path: String,
	message: String
) -> Dictionary:
	return {
		"source": source,
		"event_id": event_id,
		"path": path,
		"message": message
	}
