class_name EventDataValidator
extends RefCounted


const SUPPORTED_SCHEMA_VERSION := 1
const KNOWN_CATEGORIES: Array[String] = [
	"relationship", "education", "job_offer", "career",
	"household", "lifestyle", "family_agency", "age_lifecycle",
	"business", "health", "finance", "general"
]
const ROOT_KEYS: Array[String] = [
	"schema_version", "category", "pools", "events"
]
const SELECTION_MODES: Array[String] = [
	"weighted_one", "weighted_multiple", "all_eligible"
]
const TRIGGER_TYPES: Array[String] = [
	"system", "calendar", "manual", "chain", "scheduled"
]
const CALENDAR_UNITS: Array[String] = [
	"day", "week", "month", "year"
]
const MANUAL_MODES: Array[String] = ["direct", "pool"]
const MANUAL_SOURCES: Array[String] = [
	"lifestyle", "family_agency"
]
const RARITIES: Array[String] = [
	"common", "uncommon", "rare", "epic", "legendary"
]
const REPEAT_MODES: Array[String] = [
	"once", "once_per_character", "once_per_character_pair",
	"once_per_family", "once_per_house", "once_per_business",
	"repeatable"
]
const COOLDOWN_SCOPES: Array[String] = [
	"event", "character", "character_pair", "family", "house", "business"
]
const STATS: Array[String] = [
	"happiness", "health", "logic", "attractiveness",
	"social", "confidence", "discipline", "creativity"
]
const PARTICIPANT_TYPES: Array[String] = [
	"character", "character_group", "relationship_npc", "house",
	"business", "context"
]
const PARTICIPANT_SOURCES: Array[String] = [
	"trigger", "player_selected", "relation", "relationship_npc",
	"new_relationship_npc", "primary_house", "owned_business", "context"
]
const RELATIONS: Array[String] = [
	"spouse", "child", "parent", "family_member"
]
const REQUIREMENT_TYPES: Array[String] = [
	"stat", "flag", "age", "life_stage", "gender", "is_alive",
	"is_family_member", "has_child", "has_parent", "has_spouse",
	"family_member_count", "relationship_status", "employment_status", "job", "job_tag",
	"education_stage", "school", "school_type", "major", "lifestyle_score",
	"equipped_item", "item_type",
	"item_rarity", "money", "diamonds", "house_assignment",
	"house_level", "household_status", "household_perk", "business_owned",
	"business_type", "business_level", "business_role", "event_seen",
	"event_completed", "event_not_completed", "choice_made",
	"outcome_reached", "entitlement", "date", "year", "month"
]
const OPERATORS: Array[String] = [
	"==", "!=", ">", ">=", "<", "<=", "in", "not_in",
	"contains", "not_contains"
]
const NUMERIC_REQUIREMENTS: Array[String] = [
	"stat", "age", "family_member_count", "lifestyle_score", "money",
	"diamonds", "house_level", "business_level", "year", "month"
]
const BOOLEAN_REQUIREMENTS: Array[String] = [
	"is_alive", "is_family_member", "has_child", "has_parent", "has_spouse",
	"business_owned"
]
const TARGETED_REQUIREMENTS: Array[String] = [
	"stat", "flag", "age", "life_stage", "gender", "is_alive",
	"is_family_member", "has_child", "has_parent", "has_spouse",
	"relationship_status", "employment_status", "job", "job_tag", "education_stage", "school",
	"school_type", "major",
	"lifestyle_score", "equipped_item", "item_type", "item_rarity",
	"house_assignment", "house_level", "business_type",
	"business_level", "business_role"
]
const RESOLUTION_MODES: Array[String] = [
	"deterministic", "weighted", "score_check"
]
const SCORE_SOURCES: Array[String] = [
	"stat", "age", "lifestyle_score", "money", "diamonds",
	"house_level", "business_level"
]
const EFFECT_TYPES: Array[String] = [
	"stat_change", "stat_set", "add_flag", "remove_flag",
	"relationship_status_set", "relationship_marry", "relationship_divorce", "money_change",
	"diamond_change", "accept_job_offer", "reject_job_offer", "job_remove",
	"salary_increase", "education_enroll", "add_item", "remove_item",
	"equip_item", "unequip_item", "remove_from_house", "business_upgrade",
	"queue_event", "schedule_event", "cancel_scheduled_event"
]
const FORBIDDEN_EXECUTABLE_KEYS: Array[String] = [
	"code", "script", "method", "method_name", "callable", "signal_path"
]
const PRESENTATION_GEOMETRY_KEYS: Array[String] = [
	"font_size", "font_weight", "line_height", "padding", "margin",
	"margins", "gap", "spacing", "corner_radius", "corner_radii",
	"width", "height", "size", "position", "anchors", "offsets"
]
const LIFE_STAGES: Array[String] = [
	"baby", "child", "teen", "young_adult", "adult", "elder"
]
const EDUCATION_STAGES: Array[String] = [
	"primary_school", "middle_school", "high_school", "university"
]

const REFERENCE_CATALOGS: Array[Dictionary] = [
	{"path": "res://Resources/Json/Job.json", "root": "jobs", "kind": "job"},
	{"path": "res://Resources/Json/School.json", "root": "schools", "kind": "school"},
	{"path": "res://Resources/Json/Major.json", "root": "majors", "kind": "major"},
	{"path": "res://Resources/Json/Flag.json", "root": "flags", "kind": "flag"},
	{"path": "res://Resources/Json/ItemCatalog.json", "root": "items", "kind": "item"},
	{"path": "res://Resources/Json/BusinessTypes.json", "root": "business_types", "kind": "business"},
	{"path": "res://Resources/Json/House.json", "root": "house_definitions", "kind": "house"},
	{"path": "res://Resources/Json/HouseholdPerks.json", "root": "household_perks", "kind": "household_perk"}
]


var diagnostics: Array[Dictionary] = []
var validated_pools_by_id: Dictionary = {}
var validated_events_by_id: Dictionary = {}
var validated_events_by_category: Dictionary = {}
var validated_events_by_pool: Dictionary = {}

var _job_ids: Dictionary = {}
var _job_tags: Dictionary = {}
var _school_ids: Dictionary = {}
var _school_types: Dictionary = {}
var _major_ids: Dictionary = {}
var _flag_ids: Dictionary = {}
var _flag_names: Dictionary = {}
var _item_ids: Dictionary = {}
var _item_types: Dictionary = {}
var _item_rarities: Dictionary = {}
var _business_type_ids: Dictionary = {}
var _house_definition_ids: Dictionary = {}
var _household_status_ids: Dictionary = {}
var _household_perk_ids: Dictionary = {}
var _event_sources: Dictionary = {}


func validate_documents(documents: Dictionary) -> bool:
	_reset()
	_load_authoritative_references()

	for category_value in documents:
		var category := String(category_value)
		var wrapper_value = documents[category]

		if typeof(wrapper_value) != TYPE_DICTIONARY:
			_add("<memory>", "", "$", "Internal document wrapper must be a Dictionary.")
			continue

		var wrapper: Dictionary = wrapper_value
		var source := String(wrapper.get("source", "<memory>"))
		var data_value = wrapper.get("data", null)

		if typeof(data_value) != TYPE_DICTIONARY:
			_add(source, "", "$", "Event category root must be a Dictionary.")
			continue

		_validate_document(source, category, data_value)

	_validate_cross_document_references()

	if diagnostics.is_empty():
		_build_pool_event_lookup()

	return diagnostics.is_empty()


func validate_job_records(
	jobs: Array,
	source: String = "res://Resources/Json/Job.json"
) -> bool:
	var start_count := diagnostics.size()
	_validate_job_event_tags(jobs, source)
	return diagnostics.size() == start_count


func _reset() -> void:
	diagnostics.clear()
	validated_pools_by_id.clear()
	validated_events_by_id.clear()
	validated_events_by_category.clear()
	validated_events_by_pool.clear()
	_event_sources.clear()
	_job_ids.clear()
	_job_tags.clear()
	_school_ids.clear()
	_school_types.clear()
	_major_ids.clear()
	_flag_ids.clear()
	_flag_names.clear()
	_item_ids.clear()
	_item_types.clear()
	_item_rarities.clear()
	_business_type_ids.clear()
	_house_definition_ids.clear()
	_household_status_ids.clear()
	_household_perk_ids.clear()


func _load_authoritative_references() -> void:
	for catalog in REFERENCE_CATALOGS:
		var path := String(catalog["path"])
		var root_key := String(catalog["root"])
		var kind := String(catalog["kind"])
		var records := _load_json_array(path, root_key)

		match kind:
			"job":
				_index_records(records, "job_id", _job_ids)
				_validate_job_event_tags(records, path)
			"school":
				_index_records(records, "school_id", _school_ids)
				for value in records:
					if typeof(value) == TYPE_DICTIONARY:
						_school_types[String(value.get("school_type", ""))] = true
			"major":
				_index_records(records, "major_id", _major_ids)
			"flag":
				_index_records(records, "flag_id", _flag_ids)
				for value in records:
					if typeof(value) == TYPE_DICTIONARY:
						_flag_names[String(value.get("flag_name", "")).to_lower()] = true
			"item":
				_index_records(records, "id", _item_ids)
				for value in records:
					if typeof(value) == TYPE_DICTIONARY:
						_item_types[String(value.get("slot", "")).to_lower()] = true
						_item_rarities[String(value.get("rarity", "")).to_lower()] = true
			"business":
				_index_records(records, "business_type_id", _business_type_ids)
			"house":
				_index_records(records, "house_definition_id", _house_definition_ids)
				for value in records:
					if typeof(value) != TYPE_DICTIONARY:
						continue
					for status_value in value.get("status_thresholds", []):
						if typeof(status_value) == TYPE_DICTIONARY:
							_household_status_ids[String(status_value.get("status_id", ""))] = true
			"household_perk":
				_index_records(records, "perk_id", _household_perk_ids)


func _load_json_array(path: String, root_key: String) -> Array:
	if not FileAccess.file_exists(path):
		_add(path, "", "$", "Authoritative reference file is missing.")
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_add(path, "", "$", "Authoritative reference file could not be opened.")
		return []

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	if parse_result != OK:
		_add(path, "", "$", "Malformed reference JSON at line %d: %s" % [
			json.get_error_line(), json.get_error_message()
		])
		return []

	if typeof(json.data) != TYPE_DICTIONARY:
		_add(path, "", "$", "Reference JSON root must be a Dictionary.")
		return []

	var values = json.data.get(root_key, null)
	if typeof(values) != TYPE_ARRAY:
		_add(path, "", root_key, "Reference root member must be an Array.")
		return []

	return values


func _index_records(records: Array, id_key: String, target: Dictionary) -> void:
	for value in records:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var raw_key = value.get(id_key, null)
		if raw_key == null:
			continue
		var key := str(raw_key)
		if not key.is_empty():
			target[key] = true


func _validate_job_event_tags(jobs: Array, source: String) -> void:
	for index in jobs.size():
		var value = jobs[index]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var job: Dictionary = value
		if not job.has("event_tags"):
			continue
		var tags_value = job["event_tags"]
		if typeof(tags_value) != TYPE_ARRAY:
			_add(source, "", "jobs[%d].event_tags" % index,
				"Optional Job event_tags must be an Array of non-empty Strings.")
			continue
		var seen: Dictionary = {}
		for tag_index in tags_value.size():
			var tag_value = tags_value[tag_index]
			if typeof(tag_value) != TYPE_STRING or String(tag_value).strip_edges().is_empty():
				_add(source, "", "jobs[%d].event_tags[%d]" % [index, tag_index],
					"Job event tag must be a non-empty String.")
				continue
			var tag := String(tag_value).strip_edges()
			if seen.has(tag):
				_add(source, "", "jobs[%d].event_tags[%d]" % [index, tag_index],
					"Job event_tags must not contain duplicates.")
				continue
			seen[tag] = true
			_job_tags[tag] = true


func _validate_document(source: String, expected_category: String, data: Dictionary) -> void:
	for root_key in ROOT_KEYS:
		if not data.has(root_key):
			_add(source, "", root_key, "Required root member is missing.")

	for key_value in data:
		var key := String(key_value)
		if key not in ROOT_KEYS:
			_add(source, "", key, "Unsupported Event category root member.")

	if not _is_integer_number(data.get("schema_version", null)):
		_add(source, "", "schema_version", "schema_version must be an integer.")
	elif int(data["schema_version"]) != SUPPORTED_SCHEMA_VERSION:
		_add(source, "", "schema_version", "Unsupported schema_version %s; expected %d."
			% [data["schema_version"], SUPPORTED_SCHEMA_VERSION])

	if typeof(data.get("category", null)) != TYPE_STRING:
		_add(source, "", "category", "Root category must be a String.")
	elif String(data["category"]) != expected_category:
		_add(source, "", "category", "Root category '%s' does not match filename category '%s'."
			% [data["category"], expected_category])

	if expected_category not in KNOWN_CATEGORIES:
		_add(source, "", "category", "Unknown Event category '%s'." % expected_category)

	var pools_value = data.get("pools", null)
	if typeof(pools_value) != TYPE_ARRAY:
		_add(source, "", "pools", "Root pools must be an Array.")
	else:
		for pool_index in pools_value.size():
			_validate_pool(source, expected_category, pool_index, pools_value[pool_index])

	var events_value = data.get("events", null)
	if typeof(events_value) != TYPE_ARRAY:
		_add(source, "", "events", "Root events must be an Array.")
		return

	if not validated_events_by_category.has(expected_category):
		validated_events_by_category[expected_category] = []

	for event_index in events_value.size():
		_validate_event(source, expected_category, event_index, events_value[event_index])


func _validate_pool(
	source: String,
	category: String,
	index: int,
	value
) -> void:
	var path := "pools[%d]" % index
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, "", path, "Pool definition must be a Dictionary.")
		return
	var pool: Dictionary = value
	var pool_id := _required_string(source, "", path + ".pool_id", pool.get("pool_id", null))
	var selection_mode := _required_string(source, "", path + ".selection_mode", pool.get("selection_mode", null))

	if not selection_mode.is_empty() and selection_mode not in SELECTION_MODES:
		_add(source, "", path + ".selection_mode", "Unsupported pool selection_mode '%s'." % selection_mode)

	if pool.has("max_events") and pool["max_events"] != null:
		if not _is_integer_number(pool["max_events"]) or int(pool["max_events"]) <= 0:
			_add(source, "", path + ".max_events", "max_events must be a positive integer or null.")
		elif selection_mode == "weighted_one" and int(pool["max_events"]) != 1:
			_add(source, "", path + ".max_events", "weighted_one pools may only use max_events = 1.")
	elif selection_mode == "weighted_multiple":
		_add(source, "", path + ".max_events", "weighted_multiple pools require a positive max_events value.")

	if pool_id.is_empty():
		return
	if validated_pools_by_id.has(pool_id):
		_add(source, "", path + ".pool_id", "Duplicate global pool_id '%s'." % pool_id)
		return
	validated_pools_by_id[pool_id] = {
		"definition": pool,
		"category": category,
		"source": source
	}


func _validate_event(
	source: String,
	category: String,
	index: int,
	value
) -> void:
	var base_path := "events[%d]" % index
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, "", base_path, "Event definition must be a Dictionary.")
		return
	var event: Dictionary = value
	var event_id := _required_string(source, "", base_path + ".event_id", event.get("event_id", null))
	var event_context := event_id

	if not event_id.is_empty():
		if validated_events_by_id.has(event_id):
			_add(source, event_id, base_path + ".event_id", "Duplicate global event_id '%s'." % event_id)
		else:
			validated_events_by_id[event_id] = event
			_event_sources[event_id] = source
			validated_events_by_category[category].append(event)

	var event_category := _required_string(source, event_context, base_path + ".category", event.get("category", null))
	if not event_category.is_empty() and event_category != category:
		_add(source, event_context, base_path + ".category", "Event category '%s' does not match owning category '%s'."
			% [event_category, category])

	_required_string(source, event_context, base_path + ".domain", event.get("domain", null))
	_required_string(source, event_context, base_path + ".subtype", event.get("subtype", null))
	_require_type(source, event_context, base_path + ".enabled", event.get("enabled", null), TYPE_BOOL, "enabled must be a bool.")
	if event.has("metadata") and typeof(event["metadata"]) != TYPE_DICTIONARY:
		_add(source, event_context, base_path + ".metadata", "metadata must be a Dictionary when present.")

	var rarity := _required_string(source, event_context, base_path + ".rarity", event.get("rarity", null))
	if not rarity.is_empty() and rarity not in RARITIES:
		_add(source, event_context, base_path + ".rarity", "Unsupported rarity '%s'." % rarity)

	if not _is_number(event.get("weight", null)) or float(event.get("weight", 0.0)) <= 0.0:
		_add(source, event_context, base_path + ".weight", "weight must be a positive number.")
	if not _is_integer_number(event.get("priority", null)):
		_add(source, event_context, base_path + ".priority", "priority must be an integer.")
	if event.get("exclusive_group", null) != null and typeof(event.get("exclusive_group")) != TYPE_STRING:
		_add(source, event_context, base_path + ".exclusive_group", "exclusive_group must be a String or null.")

	_validate_trigger(source, event_context, base_path + ".trigger", event.get("trigger", null))
	var participant_names := _validate_participants(source, event_context, base_path + ".participants", event.get("participants", null))
	_validate_requirement_group(source, event_context, base_path + ".requirements", event.get("requirements", null), participant_names)
	_validate_repeat(source, event_context, base_path + ".repeat", event.get("repeat", null))
	_validate_cooldown(source, event_context, base_path + ".cooldown", event.get("cooldown", null), category)
	_validate_behavior(source, event_context, base_path + ".behavior", event.get("behavior", null))
	_validate_content(source, event_context, base_path + ".content", event.get("content", null))
	_validate_presentation(source, event_context, base_path + ".presentation", event.get("presentation", null))

	if event.has("cost") and event["cost"] != null:
		_validate_cost(source, event_context, base_path + ".cost", event["cost"])

	_validate_choices(source, event_context, base_path + ".choices", event.get("choices", null), participant_names)
	if event.has("default_resolution") and event["default_resolution"] != null:
		_validate_resolution(source, event_context, base_path + ".default_resolution", event["default_resolution"], participant_names)

	if event.has("pool_id") and event["pool_id"] != null and typeof(event["pool_id"]) != TYPE_STRING:
		_add(source, event_context, base_path + ".pool_id", "pool_id must be a String or null.")

	_validate_no_executable_keys(source, event_context, base_path, event)


func _validate_trigger(source: String, event_id: String, path: String, value) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "trigger must be a Dictionary.")
		return
	var trigger: Dictionary = value
	var trigger_type := _required_string(source, event_id, path + ".type", trigger.get("type", null))
	if trigger_type not in TRIGGER_TYPES:
		if not trigger_type.is_empty():
			_add(source, event_id, path + ".type", "Unsupported trigger type '%s'." % trigger_type)
		return

	match trigger_type:
		"system":
			_required_string(source, event_id, path + ".event", trigger.get("event", null))
			if trigger.has("parameters") and typeof(trigger["parameters"]) != TYPE_DICTIONARY:
				_add(source, event_id, path + ".parameters", "System trigger parameters must be a Dictionary.")
		"calendar":
			_validate_calendar_trigger(source, event_id, path, trigger)
		"manual":
			var manual_source := _required_string(
				source, event_id, path + ".source", trigger.get("source", null)
			)
			if not manual_source.is_empty() and manual_source not in MANUAL_SOURCES:
				_add(source, event_id, path + ".source", "Unsupported manual source '%s'. Only Lifestyle and Family Agency Events may be manual." % manual_source)
			var mode := _required_string(source, event_id, path + ".mode", trigger.get("mode", null))
			if not mode.is_empty() and mode not in MANUAL_MODES:
				_add(source, event_id, path + ".mode", "Unsupported manual mode '%s'." % mode)
			if mode == "pool":
				_required_string(source, event_id, path + ".pool_id", trigger.get("pool_id", null))
			elif mode == "direct" and trigger.get("pool_id", null) != null:
				_add(source, event_id, path + ".pool_id", "Direct manual triggers must not reference a pool.")


func _validate_calendar_trigger(source: String, event_id: String, path: String, trigger: Dictionary) -> void:
	var rule_count := 0
	if trigger.has("cadence"):
		rule_count += 1
		var cadence_value = trigger["cadence"]
		if typeof(cadence_value) != TYPE_DICTIONARY:
			_add(source, event_id, path + ".cadence", "Calendar cadence must be a Dictionary.")
		else:
			var unit := _required_string(source, event_id, path + ".cadence.unit", cadence_value.get("unit", null))
			if not unit.is_empty() and unit not in CALENDAR_UNITS:
				_add(source, event_id, path + ".cadence.unit", "Unsupported calendar cadence unit '%s'." % unit)
			if not _is_integer_number(cadence_value.get("interval", null)) or int(cadence_value.get("interval", 0)) <= 0:
				_add(source, event_id, path + ".cadence.interval", "Calendar cadence interval must be a positive integer.")
	if trigger.has("exact_date"):
		rule_count += 1
		_validate_date_value(source, event_id, path + ".exact_date", trigger["exact_date"], true)
	if trigger.has("date_window"):
		rule_count += 1
		var window_value = trigger["date_window"]
		if typeof(window_value) != TYPE_DICTIONARY:
			_add(source, event_id, path + ".date_window", "date_window must be a Dictionary with start and end dates.")
		else:
			_validate_date_value(source, event_id, path + ".date_window.start", window_value.get("start", null), true)
			_validate_date_value(source, event_id, path + ".date_window.end", window_value.get("end", null), true)
	if rule_count != 1:
		_add(source, event_id, path, "Calendar trigger must define exactly one of cadence, exact_date, or date_window.")
	if trigger.has("pool_id") and trigger["pool_id"] != null and typeof(trigger["pool_id"]) != TYPE_STRING:
		_add(source, event_id, path + ".pool_id", "Calendar pool_id must be a String or null.")


func _validate_date_value(source: String, event_id: String, path: String, value, allow_annual: bool) -> void:
	if typeof(value) == TYPE_STRING:
		var text := String(value)
		var regex := RegEx.new()
		regex.compile("^\\d{4}-\\d{2}-\\d{2}$")
		if regex.search(text) == null:
			_add(source, event_id, path, "Date String must use YYYY-MM-DD.")
			return
		var parts := text.split("-")
		_validate_calendar_date_parts(
			source, event_id, path, int(parts[0]), int(parts[1]), int(parts[2]), true
		)
		return
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "Date must be YYYY-MM-DD or a Dictionary with month/day and optional year.")
		return
	var date: Dictionary = value
	var month_valid := _is_integer_number(date.get("month", null)) and int(date.get("month", 0)) >= 1 and int(date.get("month", 0)) <= 12
	var day_valid := _is_integer_number(date.get("day", null)) and int(date.get("day", 0)) >= 1
	var year_valid := not date.has("year") or (_is_integer_number(date["year"]) and int(date["year"]) > 0)
	if not month_valid:
		_add(source, event_id, path + ".month", "Date month must be an integer from 1 to 12.")
	if not day_valid:
		_add(source, event_id, path + ".day", "Date day must be a positive integer valid for its month.")
	if date.has("year"):
		if not year_valid:
			_add(source, event_id, path + ".year", "Date year must be a positive integer.")
	elif not allow_annual:
		_add(source, event_id, path + ".year", "Date year is required.")
	if month_valid and day_valid and year_valid:
		_validate_calendar_date_parts(
			source,
			event_id,
			path,
			int(date.get("year", 0)),
			int(date["month"]),
			int(date["day"]),
			date.has("year")
		)


func _validate_calendar_date_parts(
	source: String,
	event_id: String,
	path: String,
	year: int,
	month: int,
	day: int,
	has_year: bool
) -> void:
	if month < 1 or month > 12:
		_add(source, event_id, path + ".month", "Date month must be an integer from 1 to 12.")
		return
	var month_lengths := [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var max_day: int = month_lengths[month - 1]
	if month == 2 and has_year and not _is_leap_year(year):
		max_day = 28
	if day < 1 or day > max_day:
		_add(source, event_id, path + ".day", "Date day is not valid for the selected month.")


func _is_leap_year(year: int) -> bool:
	return year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)


func _validate_participants(source: String, event_id: String, path: String, value) -> Dictionary:
	var names: Dictionary = {"family": true}
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "participants must be a Dictionary.")
		return names
	var participants: Dictionary = value
	for name_value in participants:
		var name := String(name_value)
		var participant_path := path + "." + name
		if name.strip_edges().is_empty():
			_add(source, event_id, participant_path, "Participant name must be non-empty.")
			continue
		names[name] = true
		var definition_value = participants[name]
		if typeof(definition_value) != TYPE_DICTIONARY:
			_add(source, event_id, participant_path, "Participant definition must be a Dictionary.")
			continue
		var definition: Dictionary = definition_value
		var participant_type := _required_string(source, event_id, participant_path + ".type", definition.get("type", null))
		var participant_source := _required_string(source, event_id, participant_path + ".source", definition.get("source", null))
		if not participant_type.is_empty() and participant_type not in PARTICIPANT_TYPES:
			_add(source, event_id, participant_path + ".type", "Unsupported participant type '%s'." % participant_type)
		if not participant_source.is_empty() and participant_source not in PARTICIPANT_SOURCES:
			_add(source, event_id, participant_path + ".source", "Unsupported participant source '%s'." % participant_source)

		if participant_source == "relation":
			var relation := _required_string(source, event_id, participant_path + ".relation", definition.get("relation", null))
			var from_name := _required_string(source, event_id, participant_path + ".from", definition.get("from", null))
			if not relation.is_empty() and relation not in RELATIONS:
				_add(source, event_id, participant_path + ".relation", "Unsupported relation '%s'." % relation)
			if not from_name.is_empty() and not participants.has(from_name):
				_add(source, event_id, participant_path + ".from", "Relation source participant '%s' does not exist." % from_name)

		if participant_source == "new_relationship_npc":
			if participant_type != "relationship_npc":
				_add(source, event_id, participant_path + ".type", "new_relationship_npc source requires relationship_npc type.")
			var from_name := _required_string(
				source,
				event_id,
				participant_path + ".from",
				definition.get("from", null)
			)
			if not from_name.is_empty() and not participants.has(from_name):
				_add(source, event_id, participant_path + ".from", "Relationship source participant '%s' does not exist." % from_name)

		if participant_type == "character_group":
			if participant_source != "player_selected":
				_add(source, event_id, participant_path + ".source", "character_group participants must use player_selected source.")
			var minimum = definition.get("min", null)
			var maximum = definition.get("max", null)
			if not _is_integer_number(minimum) or int(minimum) <= 0:
				_add(source, event_id, participant_path + ".min", "Character-group min must be a positive integer.")
			if not _is_integer_number(maximum) or int(maximum) <= 0:
				_add(source, event_id, participant_path + ".max", "Character-group max must be a positive integer.")
			if _is_integer_number(minimum) and _is_integer_number(maximum) and int(minimum) > int(maximum):
				_add(source, event_id, participant_path, "Character-group min must not exceed max.")
			if definition.has("selection_ui"):
				_validate_selection_ui(source, event_id, participant_path + ".selection_ui", definition["selection_ui"])
		elif definition.has("min") or definition.has("max") or definition.has("selection_ui"):
			_add(source, event_id, participant_path, "min, max, and selection_ui are only valid for character_group participants.")

		if definition.has("requirements"):
			_validate_requirement_group(source, event_id, participant_path + ".requirements", definition["requirements"], names)
	return names


func _validate_selection_ui(source: String, event_id: String, path: String, value) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "selection_ui must be a Dictionary.")
		return
	var selection_ui: Dictionary = value
	_required_string(source, event_id, path + ".title", selection_ui.get("title", null))
	_required_string(source, event_id, path + ".description", selection_ui.get("description", null))
	_require_type(source, event_id, path + ".show_ineligible", selection_ui.get("show_ineligible", null), TYPE_BOOL,
		"selection_ui.show_ineligible must be a bool.")
	if selection_ui.has("show_relevant_stats"):
		var stats_value = selection_ui["show_relevant_stats"]
		if typeof(stats_value) != TYPE_ARRAY:
			_add(source, event_id, path + ".show_relevant_stats", "show_relevant_stats must be an Array of canonical stat names.")
		else:
			for index in stats_value.size():
				if typeof(stats_value[index]) != TYPE_STRING or String(stats_value[index]) not in STATS:
					_add(source, event_id, path + ".show_relevant_stats[%d]" % index, "Unknown canonical stat name.")


func _validate_requirement_group(
	source: String,
	event_id: String,
	path: String,
	value,
	participant_names: Dictionary
) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "Requirement group must be a Dictionary.")
		return
	var group: Dictionary = value
	var group_keys := 0
	for key_value in group:
		var key := String(key_value)
		if key not in ["all", "any", "none"]:
			_add(source, event_id, path + "." + key, "Requirement group supports only all, any, and none.")
			continue
		group_keys += 1
		var children = group[key]
		if typeof(children) != TYPE_ARRAY:
			_add(source, event_id, path + "." + key, "Recursive requirement group member must be an Array.")
			continue
		for index in children.size():
			var child = children[index]
			var child_path := path + "." + key + "[%d]" % index
			if typeof(child) != TYPE_DICTIONARY:
				_add(source, event_id, child_path, "Requirement must be a Dictionary.")
				continue
			if child.has("type"):
				_validate_requirement(source, event_id, child_path, child, participant_names)
			else:
				_validate_requirement_group(source, event_id, child_path, child, participant_names)
	if group_keys == 0:
		_add(source, event_id, path, "Requirement group must contain all, any, or none.")


func _validate_requirement(
	source: String,
	event_id: String,
	path: String,
	requirement: Dictionary,
	participant_names: Dictionary
) -> void:
	var requirement_type := _required_string(source, event_id, path + ".type", requirement.get("type", null))
	if requirement_type not in REQUIREMENT_TYPES:
		if not requirement_type.is_empty():
			_add(source, event_id, path + ".type", "Unsupported requirement type '%s'." % requirement_type)
		return

	if requirement_type in TARGETED_REQUIREMENTS:
		var target := _required_string(source, event_id, path + ".target", requirement.get("target", null))
		if not target.is_empty() and not participant_names.has(target):
			_add(source, event_id, path + ".target", "Requirement target '%s' is not a defined participant/context." % target)

	var operator := _required_string(source, event_id, path + ".operator", requirement.get("operator", null))
	if not operator.is_empty() and operator not in OPERATORS:
		_add(source, event_id, path + ".operator", "Unsupported requirement operator '%s'." % operator)
		return

	var value = requirement.get("value", null)
	if requirement_type in NUMERIC_REQUIREMENTS:
		_validate_numeric_requirement(source, event_id, path, requirement_type, operator, value)
	elif requirement_type in BOOLEAN_REQUIREMENTS:
		if operator not in ["==", "!="]:
			_add(source, event_id, path + ".operator", "Boolean requirement only supports == and !=.")
		if typeof(value) != TYPE_BOOL:
			_add(source, event_id, path + ".value", "Boolean requirement value must be a bool.")
	elif requirement_type in ["event_seen", "event_completed", "event_not_completed"]:
		if operator not in ["==", "!="]:
			_add(source, event_id, path + ".operator", "Event-history requirement only supports == and !=.")
		if typeof(value) != TYPE_STRING or String(value).is_empty():
			_add(source, event_id, path + ".value", "Event history requirement value must be an event_id String.")
	elif requirement_type in ["choice_made", "outcome_reached"]:
		if operator not in ["==", "!="]:
			_add(source, event_id, path + ".operator", "Choice/outcome history requirement only supports == and !=.")
	elif requirement_type == "entitlement":
		if operator not in ["==", "!="]:
			_add(source, event_id, path + ".operator", "Entitlement requirement only supports == and !=.")
		if typeof(value) != TYPE_STRING or String(value).strip_edges().is_empty():
			_add(source, event_id, path + ".value", "Entitlement requirement value must be a non-empty entitlement ID String.")
	elif requirement_type == "relationship_status":
		if operator not in ["==", "!=", "in", "not_in"]:
			_add(source, event_id, path + ".operator", "relationship_status supports only ==, !=, in, and not_in.")
		if operator in ["in", "not_in"]:
			if typeof(value) != TYPE_ARRAY or value.is_empty():
				_add(source, event_id, path + ".value", "relationship_status membership requires a non-empty String Array.")
			else:
				for status_value in value:
					if typeof(status_value) != TYPE_STRING or String(status_value).strip_edges().is_empty():
						_add(source, event_id, path + ".value", "relationship_status membership values must be non-empty Strings.")
						break
		elif typeof(value) != TYPE_STRING or String(value).strip_edges().is_empty():
			_add(source, event_id, path + ".value", "relationship_status value must be a non-empty String.")
	elif requirement_type == "date":
		if operator not in ["==", "!=", ">", ">=", "<", "<="]:
			_add(source, event_id, path + ".operator", "Date requirement uses an incompatible operator.")
	else:
		if operator in [">", ">=", "<", "<="]:
			_add(source, event_id, path + ".operator", "This requirement type does not support numeric comparison operators.")
		_validate_scalar_or_collection_value(source, event_id, path + ".value", operator, value)

	match requirement_type:
		"stat":
			var stat := _required_string(source, event_id, path + ".stat", requirement.get("stat", null))
			if not stat.is_empty() and stat not in STATS:
				_add(source, event_id, path + ".stat", "Unknown canonical stat '%s'." % stat)
		"life_stage":
			_validate_known_scalar(source, event_id, path + ".value", value, LIFE_STAGES)
		"gender":
			_validate_known_scalar(source, event_id, path + ".value", value, ["male", "female"])
		"education_stage":
			_validate_known_scalar(source, event_id, path + ".value", value, EDUCATION_STAGES)
		"school_type":
			_validate_reference(source, event_id, path + ".value", value, _school_types, "school type")
		"job":
			_validate_reference(source, event_id, path + ".value", value, _job_ids, "job_id")
		"job_tag":
			_validate_reference(source, event_id, path + ".value", value, _job_tags, "Job event_tag")
		"school":
			_validate_reference(source, event_id, path + ".value", value, _school_ids, "school_id")
		"major":
			_validate_reference(source, event_id, path + ".value", value, _major_ids, "major_id")
		"flag":
			_validate_flag_reference(source, event_id, path + ".value", value)
		"equipped_item":
			_validate_reference(source, event_id, path + ".value", value, _item_ids, "item id")
		"item_type":
			_validate_reference(source, event_id, path + ".value", value, _item_types, "item type")
		"item_rarity":
			_validate_reference(source, event_id, path + ".value", value, _item_rarities, "item rarity")
		"business_type":
			_validate_reference(source, event_id, path + ".value", value, _business_type_ids, "business_type_id")
		"household_status":
			_validate_reference(source, event_id, path + ".value", value, _household_status_ids, "Household Status id")
		"household_perk":
			_validate_reference(source, event_id, path + ".value", value, _household_perk_ids, "Household Perk id")
		"choice_made":
			_validate_history_reference_shape(source, event_id, path + ".value", value, "choice_id")
		"outcome_reached":
			_validate_history_reference_shape(source, event_id, path + ".value", value, "outcome_id")
		"date":
			_validate_date_value(source, event_id, path + ".value", value, false)


func _validate_numeric_requirement(source: String, event_id: String, path: String, requirement_type: String, operator: String, value) -> void:
	if operator not in ["==", "!=", ">", ">=", "<", "<=", "in", "not_in"]:
		_add(source, event_id, path + ".operator", "Numeric requirement uses an incompatible operator.")
	if operator in ["in", "not_in"]:
		if typeof(value) != TYPE_ARRAY or value.is_empty():
			_add(source, event_id, path + ".value", "Numeric membership value must be a non-empty Array.")
		else:
			for item in value:
				if not _is_number(item):
					_add(source, event_id, path + ".value", "Numeric membership Array must contain only numbers.")
					break
	elif not _is_number(value):
		_add(source, event_id, path + ".value", "Numeric requirement value must be a number.")
	if requirement_type == "month" and _is_number(value) and (int(value) < 1 or int(value) > 12):
		_add(source, event_id, path + ".value", "month requirement value must be from 1 to 12.")


func _validate_scalar_or_collection_value(source: String, event_id: String, path: String, operator: String, value) -> void:
	if operator in ["in", "not_in"]:
		if typeof(value) != TYPE_ARRAY or value.is_empty():
			_add(source, event_id, path, "Membership operator requires a non-empty Array value.")
		return
	if operator in ["contains", "not_contains"]:
		if typeof(value) not in [TYPE_STRING, TYPE_INT, TYPE_FLOAT]:
			_add(source, event_id, path, "contains operator requires a scalar lookup value.")
		return
	if typeof(value) not in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
		_add(source, event_id, path, "Requirement value must be a scalar.")


func _validate_known_scalar(source: String, event_id: String, path: String, value, allowed: Array) -> void:
	if typeof(value) == TYPE_ARRAY:
		for index in value.size():
			if String(value[index]) not in allowed:
				_add(source, event_id, path + "[%d]" % index, "Unknown value '%s'." % value[index])
	elif typeof(value) == TYPE_STRING and String(value) not in allowed:
		_add(source, event_id, path, "Unknown value '%s'." % value)


func _validate_reference(source: String, event_id: String, path: String, value, references: Dictionary, label: String) -> void:
	var values: Array = value if typeof(value) == TYPE_ARRAY else [value]
	for index in values.size():
		var reference := str(values[index])
		if reference.is_empty() or not references.has(reference):
			var item_path := path if values.size() == 1 else path + "[%d]" % index
			_add(source, event_id, item_path, "Unknown %s reference '%s'." % [label, reference])


func _validate_flag_reference(source: String, event_id: String, path: String, value) -> void:
	var values: Array = value if typeof(value) == TYPE_ARRAY else [value]
	for index in values.size():
		var key := str(values[index])
		if not _flag_ids.has(key) and not _flag_names.has(key.to_lower()):
			var item_path := path if values.size() == 1 else path + "[%d]" % index
			_add(source, event_id, item_path, "Unknown flag ID/name reference '%s'." % key)


func _validate_history_reference_shape(source: String, event_id: String, path: String, value, member_id_key: String) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "History reference must be a Dictionary with event_id and %s." % member_id_key)
		return
	_required_string(source, event_id, path + ".event_id", value.get("event_id", null))
	_required_string(source, event_id, path + "." + member_id_key, value.get(member_id_key, null))


func _validate_repeat(source: String, event_id: String, path: String, value) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "repeat must be a Dictionary.")
		return
	var mode := _required_string(source, event_id, path + ".mode", value.get("mode", null))
	if not mode.is_empty() and mode not in REPEAT_MODES:
		_add(source, event_id, path + ".mode", "Unsupported repeat mode '%s'." % mode)


func _validate_cooldown(source: String, event_id: String, path: String, value, category: String) -> void:
	if value == null:
		if category == "family_agency":
			_add(source, event_id, path, "Family Agency Event requires its own event-scoped cooldown of at least 60 calendar months.")
		return
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "cooldown must be a Dictionary or null.")
		return
	var cooldown: Dictionary = value
	var scope := _required_string(source, event_id, path + ".scope", cooldown.get("scope", null))
	var unit := _required_string(source, event_id, path + ".unit", cooldown.get("unit", null))
	var amount = cooldown.get("value", null)
	if not scope.is_empty() and scope not in COOLDOWN_SCOPES:
		_add(source, event_id, path + ".scope", "Unsupported cooldown scope '%s'." % scope)
	if not unit.is_empty() and unit not in CALENDAR_UNITS:
		_add(source, event_id, path + ".unit", "Unsupported cooldown unit '%s'." % unit)
	if not _is_integer_number(amount) or int(amount) <= 0:
		_add(source, event_id, path + ".value", "Cooldown value must be a positive integer.")
	if category == "family_agency":
		if scope != "event":
			_add(source, event_id, path + ".scope", "Family Agency cooldown must use event scope, not a global/family scope.")
		if _is_integer_number(amount):
			var qualifies := (unit == "month" and int(amount) >= 60) or (unit == "year" and int(amount) >= 5)
			if not qualifies:
				_add(source, event_id, path, "Family Agency cooldown must be at least 60 calendar months (or 5 calendar years); day/week conversions are not accepted.")


func _validate_behavior(source: String, event_id: String, path: String, value) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "behavior must be a Dictionary.")
		return
	_require_type(source, event_id, path + ".blocking", value.get("blocking", null), TYPE_BOOL, "behavior.blocking must be a bool.")
	_require_type(source, event_id, path + ".pause_game", value.get("pause_game", null), TYPE_BOOL, "behavior.pause_game must be a bool.")


func _validate_content(source: String, event_id: String, path: String, value) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "content must be a Dictionary.")
		return
	_required_string(source, event_id, path + ".title", value.get("title", null))
	_required_string(source, event_id, path + ".description", value.get("description", null))
	if value.has("subtitle") and value["subtitle"] != null and typeof(value["subtitle"]) != TYPE_STRING:
		_add(source, event_id, path + ".subtitle", "subtitle must be a String or null.")


func _validate_presentation(source: String, event_id: String, path: String, value) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "presentation must be a Dictionary.")
		return
	var presentation: Dictionary = value
	_required_string(source, event_id, path + ".template", presentation.get("template", null))
	for resource_key in ["art_path", "header_icon"]:
		if not presentation.has(resource_key) or presentation[resource_key] == null:
			continue
		if typeof(presentation[resource_key]) != TYPE_STRING:
			_add(source, event_id, path + "." + resource_key, "%s must be a resource-path String or null." % resource_key)
			continue
		_validate_resource_path(source, event_id, path + "." + resource_key, String(presentation[resource_key]))
	for key_value in presentation:
		var key := String(key_value)
		if key not in ["template", "art_path", "header_icon"]:
			var reason := "UI geometry/style belongs in scenes, not Event JSON."
			if key not in PRESENTATION_GEOMETRY_KEYS:
				reason = "Unsupported presentation field; Event JSON may contain only template and resource references, while UI geometry/style belongs in scenes."
			_add(source, event_id, path + "." + key, reason)


func _validate_resource_path(source: String, event_id: String, path: String, resource_path: String) -> void:
	if resource_path.is_empty() or not resource_path.begins_with("res://"):
		_add(source, event_id, path, "Resource path must be a non-empty res:// path.")
		return
	if not ResourceLoader.exists(resource_path) and not FileAccess.file_exists(resource_path):
		_add(source, event_id, path, "Referenced resource does not exist: %s" % resource_path)


func _validate_choices(source: String, event_id: String, path: String, value, participant_names: Dictionary) -> void:
	if typeof(value) != TYPE_ARRAY:
		_add(source, event_id, path, "choices must be an Array.")
		return
	var seen_ids: Dictionary = {}
	for index in value.size():
		var choice_path := path + "[%d]" % index
		var choice_value = value[index]
		if typeof(choice_value) != TYPE_DICTIONARY:
			_add(source, event_id, choice_path, "Choice must be a Dictionary.")
			continue
		var choice: Dictionary = choice_value
		var choice_id := _required_string(source, event_id, choice_path + ".choice_id", choice.get("choice_id", null))
		if not choice_id.is_empty():
			if seen_ids.has(choice_id):
				_add(source, event_id, choice_path + ".choice_id", "Duplicate choice_id '%s' inside Event." % choice_id)
			else:
				seen_ids[choice_id] = true
		_required_string(source, event_id, choice_path + ".title", choice.get("title", null))
		if choice.has("description") and typeof(choice["description"]) != TYPE_STRING:
			_add(source, event_id, choice_path + ".description", "Choice description must be a String when provided.")
		if choice.has("icon_path") and choice["icon_path"] != null:
			if typeof(choice["icon_path"]) != TYPE_STRING:
				_add(source, event_id, choice_path + ".icon_path", "Choice icon_path must be a String or null.")
			else:
				_validate_resource_path(source, event_id, choice_path + ".icon_path", String(choice["icon_path"]))
		if choice.has("requirements"):
			_validate_requirement_group(source, event_id, choice_path + ".requirements", choice["requirements"], participant_names)
		if choice.has("cost") and choice["cost"] != null:
			_validate_cost(source, event_id, choice_path + ".cost", choice["cost"])
		_validate_resolution(source, event_id, choice_path + ".resolution", choice.get("resolution", null), participant_names)


func _validate_cost(source: String, event_id: String, path: String, value) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "cost must be a Dictionary or null.")
		return
	var currency := _required_string(source, event_id, path + ".currency", value.get("currency", null))
	if not currency.is_empty() and currency not in ["money", "diamonds"]:
		_add(source, event_id, path + ".currency", "Cost currency must be money or diamonds.")
	if not _is_number(value.get("amount", null)) or float(value.get("amount", -1.0)) < 0.0:
		_add(source, event_id, path + ".amount", "Cost amount must be a non-negative number.")


func _validate_resolution(source: String, event_id: String, path: String, value, participant_names: Dictionary) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "resolution must be a Dictionary.")
		return
	var resolution: Dictionary = value
	var mode := _required_string(source, event_id, path + ".mode", resolution.get("mode", null))
	if mode not in RESOLUTION_MODES:
		if not mode.is_empty():
			_add(source, event_id, path + ".mode", "Unsupported resolution mode '%s'." % mode)
		return
	match mode:
		"deterministic":
			_validate_effects(source, event_id, path + ".effects", resolution.get("effects", null), participant_names)
		"weighted":
			_validate_weighted_outcomes(source, event_id, path + ".outcomes", resolution.get("outcomes", null), participant_names)
		"score_check":
			_validate_score_check(source, event_id, path, resolution, participant_names)


func _validate_weighted_outcomes(source: String, event_id: String, path: String, value, participant_names: Dictionary) -> void:
	if typeof(value) != TYPE_ARRAY or value.is_empty():
		_add(source, event_id, path, "Weighted resolution requires a non-empty outcomes Array.")
		return
	var seen_ids: Dictionary = {}
	for index in value.size():
		var outcome_path := path + "[%d]" % index
		var outcome_value = value[index]
		if typeof(outcome_value) != TYPE_DICTIONARY:
			_add(source, event_id, outcome_path, "Weighted outcome must be a Dictionary.")
			continue
		var outcome: Dictionary = outcome_value
		var outcome_id := _required_string(source, event_id, outcome_path + ".outcome_id", outcome.get("outcome_id", null))
		if not outcome_id.is_empty():
			if seen_ids.has(outcome_id):
				_add(source, event_id, outcome_path + ".outcome_id", "Duplicate outcome_id '%s' inside resolution." % outcome_id)
			else:
				seen_ids[outcome_id] = true
		if not _is_number(outcome.get("weight", null)) or float(outcome.get("weight", 0.0)) <= 0.0:
			_add(source, event_id, outcome_path + ".weight", "Weighted outcome weight must be positive.")
		if outcome.has("weight_modifiers"):
			var modifiers = outcome["weight_modifiers"]
			if typeof(modifiers) != TYPE_ARRAY:
				_add(source, event_id, outcome_path + ".weight_modifiers", "weight_modifiers must be an Array.")
			else:
				for modifier_index in modifiers.size():
					var modifier_path := outcome_path + ".weight_modifiers[%d]" % modifier_index
					var modifier = modifiers[modifier_index]
					if typeof(modifier) != TYPE_DICTIONARY:
						_add(source, event_id, modifier_path, "Weight modifier must be a Dictionary.")
						continue
					_validate_requirement_group(source, event_id, modifier_path + ".requirements", modifier.get("requirements", null), participant_names)
					if not _is_number(modifier.get("add_weight", null)):
						_add(source, event_id, modifier_path + ".add_weight", "add_weight must be numeric.")
		_validate_effects(source, event_id, outcome_path + ".effects", outcome.get("effects", null), participant_names)


func _validate_score_check(source: String, event_id: String, path: String, resolution: Dictionary, participant_names: Dictionary) -> void:
	var sources_value = resolution.get("sources", null)
	if typeof(sources_value) != TYPE_ARRAY or sources_value.is_empty():
		_add(source, event_id, path + ".sources", "score_check requires a non-empty sources Array.")
	else:
		for index in sources_value.size():
			var source_path := path + ".sources[%d]" % index
			var score_source = sources_value[index]
			if typeof(score_source) != TYPE_DICTIONARY:
				_add(source, event_id, source_path, "Score source must be a Dictionary.")
				continue
			var source_type := _required_string(source, event_id, source_path + ".source", score_source.get("source", null))
			if not source_type.is_empty() and source_type not in SCORE_SOURCES:
				_add(source, event_id, source_path + ".source", "Unsupported score source '%s'." % source_type)
			var target := _required_string(source, event_id, source_path + ".target", score_source.get("target", null))
			if not target.is_empty() and not participant_names.has(target):
				_add(source, event_id, source_path + ".target", "Score source target is not a defined participant/context.")
			if source_type == "stat":
				var stat := _required_string(source, event_id, source_path + ".stat", score_source.get("stat", null))
				if not stat.is_empty() and stat not in STATS:
					_add(source, event_id, source_path + ".stat", "Unknown canonical stat '%s'." % stat)
			if not _is_number(score_source.get("weight", null)):
				_add(source, event_id, source_path + ".weight", "Score source weight must be numeric.")
	if not _is_number(resolution.get("threshold", null)):
		_add(source, event_id, path + ".threshold", "score_check threshold must be numeric.")
	var seen_ids: Dictionary = {}
	for result_key_value in ["success", "failure"]:
		var result_key := String(result_key_value)
		var result_path := path + "." + result_key
		var result_value = resolution.get(result_key, null)
		if typeof(result_value) != TYPE_DICTIONARY:
			_add(source, event_id, result_path, "score_check result must be a Dictionary.")
			continue
		var outcome_id := _required_string(source, event_id, result_path + ".outcome_id", result_value.get("outcome_id", null))
		if not outcome_id.is_empty():
			if seen_ids.has(outcome_id):
				_add(source, event_id, result_path + ".outcome_id", "score_check outcome IDs must be unique.")
			seen_ids[outcome_id] = true
		_validate_effects(source, event_id, result_path + ".effects", result_value.get("effects", null), participant_names)


func _validate_effects(source: String, event_id: String, path: String, value, participant_names: Dictionary) -> void:
	if typeof(value) != TYPE_ARRAY:
		_add(source, event_id, path, "effects must be an Array.")
		return
	for index in value.size():
		var effect_path := path + "[%d]" % index
		var effect_value = value[index]
		if typeof(effect_value) != TYPE_DICTIONARY:
			_add(source, event_id, effect_path, "Effect must be a Dictionary.")
			continue
		var effect: Dictionary = effect_value
		var effect_type := _required_string(source, event_id, effect_path + ".type", effect.get("type", null))
		if effect_type not in EFFECT_TYPES:
			if not effect_type.is_empty():
				_add(source, event_id, effect_path + ".type", "Unsupported effect type '%s'." % effect_type)
			continue
		_validate_effect_shape(source, event_id, effect_path, effect_type, effect, participant_names)
		_validate_effect_feedback(source, event_id, effect_path + ".feedback", effect.get("feedback", null))
		if effect_type in ["add_flag", "remove_flag"] and typeof(effect.get("feedback", null)) == TYPE_DICTIONARY:
			var feedback: Dictionary = effect["feedback"]
			var flag_value = effect.get("flag_id", "")
			var flag_id_text := str(int(flag_value)) if typeof(flag_value) in [TYPE_INT, TYPE_FLOAT] else str(flag_value)
			if String(feedback.get("mode", "auto")) == "custom" and String(feedback.get("text", "")).contains(flag_id_text):
				_add(source, event_id, effect_path + ".feedback.text", "Player-facing flag feedback must not expose the internal flag_id.")
		_validate_no_executable_keys(source, event_id, effect_path, effect)


func _validate_effect_feedback(source: String, event_id: String, path: String, value) -> void:
	if value == null:
		return
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "feedback must be a Dictionary or null.")
		return
	var mode := String(value.get("mode", "auto"))
	if mode not in ["auto", "custom"]:
		_add(source, event_id, path + ".mode", "feedback mode must be auto or custom.")
	if mode == "custom" and String(value.get("text", "")).strip_edges().is_empty():
		_add(source, event_id, path + ".text", "custom feedback requires player-facing text.")
	if value.has("icon_path") and value["icon_path"] != null and typeof(value["icon_path"]) != TYPE_STRING:
		_add(source, event_id, path + ".icon_path", "feedback icon_path must be a String or null.")


func _validate_effect_shape(source: String, event_id: String, path: String, effect_type: String, effect: Dictionary, participant_names: Dictionary) -> void:
	match effect_type:
		"stat_change":
			_validate_effect_target(source, event_id, path, effect, "target", participant_names)
			_validate_effect_stat(source, event_id, path, effect)
			_require_number(source, event_id, path + ".amount", effect.get("amount", null))
		"stat_set":
			_validate_effect_target(source, event_id, path, effect, "target", participant_names)
			_validate_effect_stat(source, event_id, path, effect)
			_require_number(source, event_id, path + ".value", effect.get("value", null))
		"add_flag", "remove_flag":
			_validate_effect_target(source, event_id, path, effect, "target", participant_names)
			_validate_flag_reference(source, event_id, path + ".flag_id", effect.get("flag_id", null))
			if effect_type == "add_flag" and effect.has("duration"):
				_add(
					source,
					event_id,
					path + ".duration",
					"add_flag does not support duration. Use schedule_event plus remove_flag for timed story state."
				)
		"relationship_status_set":
			_validate_effect_target(source, event_id, path, effect, "target", participant_names)
			var relationship_status := _required_string(
				source,
				event_id,
				path + ".value",
				effect.get("value", null)
			)
			if relationship_status in ["married", "divorced"]:
				_add(
					source,
					event_id,
					path + ".value",
					"relationship_status_set cannot write manager-owned status '%s'; use relationship_marry or relationship_divorce." % relationship_status
				)
		"relationship_marry", "relationship_divorce":
			_validate_effect_target(source, event_id, path, effect, "primary", participant_names)
			_validate_effect_target(source, event_id, path, effect, "target", participant_names)
		"money_change", "diamond_change":
			_require_number(source, event_id, path + ".amount", effect.get("amount", null))
		"accept_job_offer", "reject_job_offer", "job_remove":
			_validate_effect_target(source, event_id, path, effect, "target", participant_names)
		"salary_increase":
			_validate_effect_target(source, event_id, path, effect, "target", participant_names)
			var salary_amount = effect.get("amount", null)
			if (
				not _is_number(salary_amount)
				or float(salary_amount) <= 0.0
				or not is_equal_approx(float(salary_amount), floor(float(salary_amount)))
			):
				_add(source, event_id, path + ".amount", "salary_increase amount must be a positive integer.")
		"education_enroll":
			_validate_effect_target(source, event_id, path, effect, "target", participant_names)
			_validate_reference(source, event_id, path + ".school_id", effect.get("school_id", null), _school_ids, "school_id")
		"add_item", "remove_item", "equip_item", "unequip_item":
			_validate_effect_target(source, event_id, path, effect, "target", participant_names)
			_validate_reference(source, event_id, path + ".item_id", effect.get("item_id", null), _item_ids, "item id")
		"remove_from_house":
			_validate_effect_target(source, event_id, path, effect, "target", participant_names)
		"business_upgrade":
			_validate_effect_target(source, event_id, path, effect, "business", participant_names)
			if effect.has("business_type_id"):
				_validate_reference(source, event_id, path + ".business_type_id", effect["business_type_id"], _business_type_ids, "business_type_id")
		"queue_event":
			_required_string(source, event_id, path + ".event_id", effect.get("event_id", null))
		"schedule_event":
			_required_string(source, event_id, path + ".event_id", effect.get("event_id", null))
			_validate_duration(source, event_id, path + ".delay", effect.get("delay", null))
			if effect.has("inherit_context") and typeof(effect["inherit_context"]) != TYPE_BOOL:
				_add(source, event_id, path + ".inherit_context", "inherit_context must be a bool.")
		"cancel_scheduled_event":
			if effect.has("event_id"):
				_required_string(source, event_id, path + ".event_id", effect.get("event_id", null))
			elif effect.has("scheduled_event_id"):
				_required_string(source, event_id, path + ".scheduled_event_id", effect.get("scheduled_event_id", null))
			else:
				_add(source, event_id, path, "cancel_scheduled_event requires event_id or scheduled_event_id.")


func _validate_effect_target(source: String, event_id: String, path: String, effect: Dictionary, key: String, participant_names: Dictionary) -> void:
	var target := _required_string(source, event_id, path + "." + key, effect.get(key, null))
	if not target.is_empty() and not participant_names.has(target):
		_add(source, event_id, path + "." + key, "Effect target/reference '%s' is not a defined participant/context." % target)


func _validate_effect_stat(source: String, event_id: String, path: String, effect: Dictionary) -> void:
	var stat := _required_string(source, event_id, path + ".stat", effect.get("stat", null))
	if not stat.is_empty() and stat not in STATS:
		_add(source, event_id, path + ".stat", "Unknown canonical stat '%s'." % stat)


func _validate_duration(source: String, event_id: String, path: String, value) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_add(source, event_id, path, "Calendar duration must be a Dictionary.")
		return
	var unit := _required_string(source, event_id, path + ".unit", value.get("unit", null))
	if not unit.is_empty() and unit not in CALENDAR_UNITS:
		_add(source, event_id, path + ".unit", "Unsupported calendar duration unit '%s'." % unit)
	if not _is_integer_number(value.get("value", null)) or int(value.get("value", 0)) <= 0:
		_add(source, event_id, path + ".value", "Calendar duration value must be a positive integer.")


func _validate_cross_document_references() -> void:
	for event_id_value in validated_events_by_id:
		var event_id := String(event_id_value)
		var event: Dictionary = validated_events_by_id[event_id]
		var source := String(_event_sources.get(event_id, "<memory>"))

		_validate_pool_reference(source, event_id, "pool_id", event.get("pool_id", null))
		var trigger_value = event.get("trigger", {})
		if typeof(trigger_value) == TYPE_DICTIONARY:
			_validate_pool_reference(source, event_id, "trigger.pool_id", trigger_value.get("pool_id", null))

		_validate_event_history_references(source, event_id, event.get("requirements", {}), "requirements")
		_validate_event_flow_references(source, event_id, event)

	_validate_event_flow_cycles()


func _validate_pool_reference(source: String, event_id: String, path: String, value) -> void:
	if value == null:
		return
	if typeof(value) != TYPE_STRING or String(value).is_empty():
		return
	if not validated_pools_by_id.has(String(value)):
		_add(source, event_id, path, "Referenced pool_id '%s' does not exist." % value)


func _validate_event_history_references(source: String, event_id: String, value, path: String) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var dictionary: Dictionary = value
	if dictionary.has("type"):
		var requirement_type := String(dictionary.get("type", ""))
		if requirement_type in ["event_seen", "event_completed", "event_not_completed"]:
			var referenced := String(dictionary.get("value", ""))
			if not referenced.is_empty() and not validated_events_by_id.has(referenced):
				_add(source, event_id, path + ".value", "Referenced event_id '%s' does not exist." % referenced)
		elif requirement_type in ["choice_made", "outcome_reached"] and typeof(dictionary.get("value", null)) == TYPE_DICTIONARY:
			var referenced := String(dictionary["value"].get("event_id", ""))
			if not referenced.is_empty() and not validated_events_by_id.has(referenced):
				_add(source, event_id, path + ".value.event_id", "Referenced event_id '%s' does not exist." % referenced)
			elif not referenced.is_empty():
				var member_key := "choice_id" if requirement_type == "choice_made" else "outcome_id"
				var member_id := String(dictionary["value"].get(member_key, ""))
				var member_exists := _event_has_choice_id(validated_events_by_id[referenced], member_id) \
					if member_key == "choice_id" else _event_has_outcome_id(validated_events_by_id[referenced], member_id)
				if not member_id.is_empty() and not member_exists:
					_add(source, event_id, path + ".value." + member_key,
						"Referenced %s '%s' does not exist in Event '%s'." % [member_key, member_id, referenced])
		return
	for key in ["all", "any", "none"]:
		var children = dictionary.get(key, [])
		if typeof(children) != TYPE_ARRAY:
			continue
		for index in children.size():
			_validate_event_history_references(source, event_id, children[index], path + "." + key + "[%d]" % index)


func _event_has_choice_id(event: Dictionary, choice_id: String) -> bool:
	var choices = event.get("choices", [])
	if typeof(choices) != TYPE_ARRAY:
		return false
	for choice in choices:
		if typeof(choice) == TYPE_DICTIONARY and String(choice.get("choice_id", "")) == choice_id:
			return true
	return false


func _event_has_outcome_id(event: Dictionary, outcome_id: String) -> bool:
	var resolutions: Array = []
	if typeof(event.get("default_resolution", null)) == TYPE_DICTIONARY:
		resolutions.append(event["default_resolution"])
	var choices = event.get("choices", [])
	if typeof(choices) == TYPE_ARRAY:
		for choice in choices:
			if typeof(choice) == TYPE_DICTIONARY and typeof(choice.get("resolution", null)) == TYPE_DICTIONARY:
				resolutions.append(choice["resolution"])
	for resolution in resolutions:
		var mode := String(resolution.get("mode", ""))
		if mode == "weighted":
			for outcome in resolution.get("outcomes", []):
				if typeof(outcome) == TYPE_DICTIONARY and String(outcome.get("outcome_id", "")) == outcome_id:
					return true
		elif mode == "score_check":
			for result_key in ["success", "failure"]:
				var result = resolution.get(result_key, null)
				if typeof(result) == TYPE_DICTIONARY and String(result.get("outcome_id", "")) == outcome_id:
					return true
	return false


func _validate_event_flow_references(source: String, event_id: String, event: Dictionary) -> void:
	var effects_with_paths: Array = []
	_collect_event_effects(event, effects_with_paths)
	for wrapper in effects_with_paths:
		var effect: Dictionary = wrapper["effect"]
		var effect_type := String(effect.get("type", ""))
		if effect_type not in ["queue_event", "schedule_event", "cancel_scheduled_event"]:
			continue
		if not effect.has("event_id"):
			continue
		var target_event_id := String(effect.get("event_id", ""))
		if not target_event_id.is_empty() and not validated_events_by_id.has(target_event_id):
			_add(source, event_id, String(wrapper["path"]) + ".event_id", "Referenced Event target '%s' does not exist." % target_event_id)


func _validate_event_flow_cycles() -> void:
	var graph: Dictionary = {}
	for event_id_value in validated_events_by_id:
		var event_id := String(event_id_value)
		graph[event_id] = []
		var effects_with_paths: Array = []
		_collect_event_effects(validated_events_by_id[event_id], effects_with_paths)
		for wrapper in effects_with_paths:
			var effect: Dictionary = wrapper["effect"]
			if String(effect.get("type", "")) not in ["queue_event", "schedule_event"]:
				continue
			var target := String(effect.get("event_id", ""))
			if validated_events_by_id.has(target):
				graph[event_id].append({"target": target, "path": wrapper["path"]})

	for event_id_value in graph:
		var event_id := String(event_id_value)
		for edge in graph[event_id]:
			var target := String(edge["target"])
			if target == event_id or _graph_path_exists(graph, target, event_id, {}):
				_add(String(_event_sources.get(event_id, "<memory>")), event_id,
					String(edge["path"]) + ".event_id",
					"Statically detectable circular Event queue/schedule chain: '%s' -> '%s'." % [event_id, target])


func _graph_path_exists(graph: Dictionary, current: String, goal: String, visited: Dictionary) -> bool:
	if current == goal:
		return true
	if visited.has(current):
		return false
	visited[current] = true
	for edge in graph.get(current, []):
		if _graph_path_exists(graph, String(edge["target"]), goal, visited):
			return true
	return false


func _collect_event_effects(event: Dictionary, output: Array) -> void:
	if event.has("default_resolution") and typeof(event["default_resolution"]) == TYPE_DICTIONARY:
		_collect_resolution_effects(event["default_resolution"], "default_resolution", output)
	var choices = event.get("choices", [])
	if typeof(choices) != TYPE_ARRAY:
		return
	for index in choices.size():
		if typeof(choices[index]) == TYPE_DICTIONARY and typeof(choices[index].get("resolution", null)) == TYPE_DICTIONARY:
			_collect_resolution_effects(choices[index]["resolution"], "choices[%d].resolution" % index, output)


func _collect_resolution_effects(resolution: Dictionary, path: String, output: Array) -> void:
	var mode := String(resolution.get("mode", ""))
	if mode == "deterministic":
		_collect_effect_array(resolution.get("effects", []), path + ".effects", output)
	elif mode == "weighted":
		var outcomes = resolution.get("outcomes", [])
		if typeof(outcomes) == TYPE_ARRAY:
			for index in outcomes.size():
				if typeof(outcomes[index]) == TYPE_DICTIONARY:
					_collect_effect_array(outcomes[index].get("effects", []), path + ".outcomes[%d].effects" % index, output)
	elif mode == "score_check":
		for result_key in ["success", "failure"]:
			if typeof(resolution.get(result_key, null)) == TYPE_DICTIONARY:
				_collect_effect_array(resolution[result_key].get("effects", []), path + "." + result_key + ".effects", output)


func _collect_effect_array(effects, path: String, output: Array) -> void:
	if typeof(effects) != TYPE_ARRAY:
		return
	for index in effects.size():
		if typeof(effects[index]) == TYPE_DICTIONARY:
			output.append({"effect": effects[index], "path": path + "[%d]" % index})


func _build_pool_event_lookup() -> void:
	for pool_id_value in validated_pools_by_id:
		validated_events_by_pool[String(pool_id_value)] = []
	for event_id_value in validated_events_by_id:
		var event: Dictionary = validated_events_by_id[event_id_value]
		var pool_ids: Array[String] = []
		if event.has("pool_id") and event["pool_id"] != null:
			pool_ids.append(String(event["pool_id"]))
		var trigger = event.get("trigger", {})
		if typeof(trigger) == TYPE_DICTIONARY and trigger.get("pool_id", null) != null:
			var trigger_pool := String(trigger["pool_id"])
			if trigger_pool not in pool_ids:
				pool_ids.append(trigger_pool)
		for pool_id in pool_ids:
			if validated_events_by_pool.has(pool_id):
				validated_events_by_pool[pool_id].append(event)


func _validate_no_executable_keys(source: String, event_id: String, path: String, value) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key_value in value:
			var key := String(key_value)
			if key in FORBIDDEN_EXECUTABLE_KEYS:
				_add(source, event_id, path + "." + key, "Executable code/method references are forbidden in Event JSON.")
			_validate_no_executable_keys(source, event_id, path + "." + key, value[key])
	elif typeof(value) == TYPE_ARRAY:
		for index in value.size():
			_validate_no_executable_keys(source, event_id, path + "[%d]" % index, value[index])


func _required_string(source: String, event_id: String, path: String, value) -> String:
	if typeof(value) != TYPE_STRING or String(value).strip_edges().is_empty():
		_add(source, event_id, path, "Required value must be a non-empty String.")
		return ""
	return String(value)


func _require_type(source: String, event_id: String, path: String, value, expected_type: int, message: String) -> void:
	if typeof(value) != expected_type:
		_add(source, event_id, path, message)


func _require_number(source: String, event_id: String, path: String, value) -> void:
	if not _is_number(value):
		_add(source, event_id, path, "Required value must be numeric.")


func _is_number(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


func _is_integer_number(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_equal_approx(float(value), round(float(value)))
	return false


func _add(source: String, event_id: String, path: String, message: String) -> void:
	diagnostics.append({
		"source": source,
		"event_id": event_id,
		"path": path,
		"message": message
	})
