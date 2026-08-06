extends Node


const SCHOOL_DATA_PATH := "res://Resources/Json/School.json"
const DEFAULT_SCHOOL_ICON_PATH := \
	"res://Resources/Icons/Schools/default_school.svg"


const VALID_EDUCATION_STAGES: Array[String] = [
	"primary_school",
	"middle_school",
	"high_school",
	"university"
]

const VALID_SCHOOL_TYPES: Array[String] = [
	"public",
	"private",
	"prestige"
]


var schools: Array = []


func _ready() -> void:
	load_school_data()


func load_school_data() -> void:
	var loaded_schools := _load_json_array(
		SCHOOL_DATA_PATH,
		"schools"
	)

	var normalized_schools: Array = []
	var used_school_ids: Dictionary = {}

	for school_value in loaded_schools:
		if typeof(school_value) != TYPE_DICTIONARY:
			push_error(
				"School entry must be a Dictionary."
			)
			continue

		var school: Dictionary = school_value

		var school_id := int(
			school.get("school_id", 0)
		)

		var education_stage := String(
			school.get("education_stage", "")
		).strip_edges().to_lower()

		var school_type := String(
			school.get("school_type", "")
		).strip_edges().to_lower()

		var base_cost := int(
			school.get("base_cost", 0)
		)

		var stat_bonus_value = school.get(
			"stat_bonus",
			{}
		)

		if school_id <= 0:
			push_error(
				"School has an invalid school_id."
			)
			continue

		if used_school_ids.has(school_id):
			push_error(
				"Duplicate school_id: "
				+ str(school_id)
			)
			continue

		if not VALID_EDUCATION_STAGES.has(
			education_stage
		):
			push_error(
				"Invalid education stage for school %d: %s"
				% [
					school_id,
					education_stage
				]
			)
			continue

		if not VALID_SCHOOL_TYPES.has(
			school_type
		):
			push_error(
				"Invalid school type for school %d: %s"
				% [
					school_id,
					school_type
				]
			)
			continue

		if typeof(stat_bonus_value) != TYPE_DICTIONARY:
			push_error(
				"School stat_bonus must be a Dictionary: "
				+ str(school_id)
			)
			continue

		school["school_id"] = school_id
		school["education_stage"] = education_stage
		school["school_type"] = school_type
		school["base_cost"] = maxi(base_cost, 0)

		used_school_ids[school_id] = true
		normalized_schools.append(school)

	schools = normalized_schools

	print(
		"Schools loaded: ",
		schools.size()
	)


func get_school_by_id(
	school_id: int
) -> Dictionary:
	for school_value in schools:
		if typeof(school_value) != TYPE_DICTIONARY:
			continue

		var school: Dictionary = school_value

		if int(
			school.get("school_id", 0)
		) == school_id:
			return school

	return {}


func get_schools_for_stage(
	education_stage: String
) -> Array:
	var normalized_stage := (
		education_stage
		.strip_edges()
		.to_lower()
	)

	var matching_schools: Array = []

	if not VALID_EDUCATION_STAGES.has(
		normalized_stage
	):
		push_error(
			"Invalid education stage: "
			+ education_stage
		)
		return matching_schools

	for school_value in schools:
		if typeof(school_value) != TYPE_DICTIONARY:
			continue

		var school: Dictionary = school_value

		if String(
			school.get("education_stage", "")
		) == normalized_stage:
			matching_schools.append(school)

	return matching_schools


func has_school(
	school_id: int
) -> bool:
	return not get_school_by_id(
		school_id
	).is_empty()


func _load_json_array(
	file_path: String,
	root_key: String
) -> Array:
	if not FileAccess.file_exists(file_path):
		push_error(
			"JSON file could not be found: "
			+ file_path
		)
		return []

	var file := FileAccess.open(
		file_path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"JSON file could not be opened: "
			+ file_path
		)
		return []

	var json := JSON.new()

	var parse_result := json.parse(
		file.get_as_text()
	)

	if parse_result != OK:
		push_error(
			"JSON error in %s at line %d: %s"
			% [
				file_path,
				json.get_error_line(),
				json.get_error_message()
			]
		)
		return []

	var data = json.data

	if typeof(data) != TYPE_DICTIONARY:
		push_error(
			"JSON root must be a Dictionary: "
			+ file_path
		)
		return []

	if not data.has(root_key):
		push_error(
			"JSON does not contain '%s': %s"
			% [
				root_key,
				file_path
			]
		)
		return []

	var array_value = data[root_key]

	if typeof(array_value) != TYPE_ARRAY:
		push_error(
			"'%s' must be an Array: %s"
			% [
				root_key,
				file_path
			]
		)
		return []

	var loaded_array: Array = array_value

	return loaded_array
	
