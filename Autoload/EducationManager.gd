extends Node


signal education_event_requested(
	character_id: int,
	event_type: String,
	education_stage: String
)

signal major_selection_requested(
	character_id: int
)

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

const PRIMARY_START_AGE := 6
const MIDDLE_START_AGE := 12
const HIGH_START_AGE := 15
const UNIVERSITY_START_AGE := 18
const MAJOR_SELECTION_AGE := 21


var schools: Array = []
var education_event_queue: Array = []
var is_education_event_active: bool = false


func _ready() -> void:
	load_school_data()

	TimeManager.date_changed.connect(
		_on_date_changed
	)


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
	
func is_character_birthday(
	character: Dictionary
) -> bool:
	var birth_date := String(
		character.get("birth_date", "")
	)

	var date_parts := birth_date.split("-")

	if date_parts.size() != 3:
		return false

	var birth_month := int(date_parts[1])
	var birth_day := int(date_parts[2])

	return (
		TimeManager.current_month == birth_month
		and TimeManager.current_day == birth_day
	)

func get_birthday_education_event(
	character: Dictionary
) -> Dictionary:
	if not character.get(
		"is_player_family",
		false
	):
		return {}
	
	if not character.get("is_alive", true):
		return {}

	if not is_character_birthday(character):
		return {}

	var age := CharacterManager.get_character_age(
		character
	)

	match age:
		PRIMARY_START_AGE:
			return {
				"event_type": "school_enrollment",
				"education_stage": "primary_school"
			}

		MIDDLE_START_AGE:
			graduate_current_school(
				character,
				"primary_school"
			)

			return {
				"event_type": "school_transition",
				"education_stage": "middle_school"
			}

		HIGH_START_AGE:
			graduate_current_school(
				character,
				"middle_school"
			)

			return {
				"event_type": "school_transition",
				"education_stage": "high_school"
			}

		UNIVERSITY_START_AGE:
			graduate_current_school(
				character,
				"high_school"
			)

			return {
				"event_type": "university_choice",
				"education_stage": "university"
			}

		MAJOR_SELECTION_AGE:
			if should_request_major_selection(
				character
			):
				return {
					"event_type": "major_selection",
					"education_stage": "university"
				}

	return {}

func should_request_major_selection(
	character: Dictionary
) -> bool:
	if String(
		character.get(
			"education_status",
			"none"
		)
	) != "studying":
		return false

	if character.get(
		"school_id",
		null
	) == null:
		return false

	if character.get(
		"major_id",
		null
	) != null:
		return false

	var school_id := int(
		character.get("school_id", 0)
	)

	var school := get_school_by_id(
		school_id
	)

	if school.is_empty():
		return false

	return String(
		school.get(
			"education_stage",
			""
		)
	) == "university"

func _on_date_changed(
	_date_text: String
) -> void:
	check_university_graduations()
	check_birthday_education_events()


func check_birthday_education_events() -> void:
	var pending_events: Array = []

	for character_value in CharacterManager.characters:
		if typeof(
			character_value
		) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = (
			character_value
		)

		var education_event := (
			get_birthday_education_event(
				character
			)
		)

		if education_event.is_empty():
			continue

		pending_events.append({
			"character_id": int(
				character.get(
					"character_id",
					0
				)
			),
			"event_type": String(
				education_event.get(
					"event_type",
					""
				)
			),
			"education_stage": String(
				education_event.get(
					"education_stage",
					""
				)
			)
		})

	pending_events.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(
				a["character_id"]
			) < int(
				b["character_id"]
			)
	)

	for event_data in pending_events:
		education_event_queue.append(
			event_data
		)

	request_next_education_event()

func request_next_education_event() -> void:
	if is_education_event_active:
		return

	if education_event_queue.is_empty():
		return

	var event_data: Dictionary = (
		education_event_queue.pop_front()
	)

	is_education_event_active = true

	var character_id := int(
		event_data.get(
			"character_id",
			0
		)
	)

	var event_type := String(
		event_data.get(
			"event_type",
			""
		)
	)

	var education_stage := String(
		event_data.get(
			"education_stage",
			""
		)
	)

	if event_type == "major_selection":
		major_selection_requested.emit(
			character_id
		)
	else:
		education_event_requested.emit(
			character_id,
			event_type,
			education_stage
		)

	print(
		"Education event requested: ",
		event_type,
		" | Character: ",
		character_id,
		" | Stage: ",
		education_stage
	)

func complete_current_education_event() -> void:
	if not is_education_event_active:
		return

	is_education_event_active = false

	request_next_education_event()
	
func apply_school_stat_bonus(
	character: Dictionary,
	school: Dictionary
) -> void:
	var stat_bonus_value = school.get(
		"stat_bonus",
		{}
	)

	if typeof(stat_bonus_value) != TYPE_DICTIONARY:
		push_error(
			"School stat_bonus must be a Dictionary."
		)
		return

	var stat_bonus: Dictionary = stat_bonus_value

	for stat_name_value in stat_bonus.keys():
		var stat_name := String(
			stat_name_value
		)

		var bonus := int(
			stat_bonus.get(
				stat_name,
				0
			)
		)

		var current_value := int(
			character.get(
				stat_name,
				0
			)
		)

		character[stat_name] = mini(
			current_value + bonus,
			100
		)

func add_education_event_log(
	character: Dictionary,
	event_type: String,
	school_id: int,
	major_id = null
) -> void:
	var event_log_value = character.get(
		"event_log",
		[]
	)

	if typeof(event_log_value) != TYPE_ARRAY:
		push_error(
			"Character event_log must be an Array."
		)
		return

	var event_log: Array = event_log_value

	event_log.append({
		"event_type": event_type,
		"date": TimeManager.get_iso_date_string(),
		"school_id": school_id,
		"major_id": major_id
	})

	character["event_log"] = event_log

func enroll_character_in_school(
	character_id: int,
	school_id: int
) -> bool:
	var character := CharacterManager.get_character_by_id(
		character_id
	)

	if character.is_empty():
		push_error(
			"Character could not be found: "
			+ str(character_id)
		)
		return false

	if not character.get(
		"is_alive",
		true
	):
		return false

	var school := get_school_by_id(
		school_id
	)

	if school.is_empty():
		push_error(
			"School could not be found: "
			+ str(school_id)
		)
		return false
		
	var character_age := CharacterManager.get_character_age(
		character
	)

	var expected_stage := (
		get_expected_education_stage_for_age(
			character_age
		)
	)

	if expected_stage.is_empty():
		push_error(
			"Character is not at a school enrollment age: "
			+ str(character_age)
		)
		return false

	var school_stage := String(
		school.get(
			"education_stage",
			""
		)
	)

	if school_stage != expected_stage:
		push_error(
			"School stage does not match character age. "
			+ "Expected: "
			+ expected_stage
			+ " | Received: "
			+ school_stage
		)
		return false

	character["school_id"] = school_id
	character["major_id"] = null

	character["education_status"] = "studying"

	character["education_start_date"] = (
		TimeManager.get_iso_date_string()
	)

	character["major_selection_date"] = null
	character["expected_graduation_date"] = null
	character["graduation_date"] = null

	apply_school_stat_bonus(
		character,
		school
	)

	add_education_event_log(
		character,
		"education_started",
		school_id
	)

	print(
		"Character enrolled in school: ",
		character_id,
		" | School: ",
		school_id
	)

	complete_current_education_event()

	return true

func graduate_current_school(
	character: Dictionary,
	expected_stage: String
) -> bool:
	if String(
		character.get(
			"education_status",
			"none"
		)
	) != "studying":
		return false

	var school_id_value = character.get(
		"school_id",
		null
	)

	if school_id_value == null:
		return false

	var school_id := int(school_id_value)

	var school := get_school_by_id(
		school_id
	)

	if school.is_empty():
		return false

	if String(
		school.get(
			"education_stage",
			""
		)
	) != expected_stage:
		return false

	var graduation_date := (
		TimeManager.get_iso_date_string()
	)

	character["education_status"] = "graduated"
	character["graduation_date"] = graduation_date

	add_education_event_log(
		character,
		"education_graduated",
		school_id,
		character.get(
			"major_id",
			null
		)
	)

	print(
		"Character graduated from school: ",
		character.get(
			"character_id",
			0
		),
		" | School: ",
		school_id,
		" | Date: ",
		graduation_date
	)

	return true

func decline_university(
	character_id: int
) -> bool:
	var character := CharacterManager.get_character_by_id(
		character_id
	)

	if character.is_empty():
		push_error(
			"Character could not be found: "
			+ str(character_id)
		)
		return false

	if not character.get(
		"is_alive",
		true
	):
		return false
		
	if not character.get(
		"is_player_family",
		false
	):
		return false

	var age := CharacterManager.get_character_age(
		character
	)

	if age != UNIVERSITY_START_AGE:
		push_error(
			"University can only be declined at age 18."
		)
		return false

	character["major_id"] = null
	character["major_selection_date"] = null
	character["expected_graduation_date"] = null

	print(
		"Character declined university: ",
		character_id
	)

	complete_current_education_event()

	return true

func is_fallback_major(
	major: Dictionary
) -> bool:
	return bool(
		major.get(
			"is_fallback",
			false
		)
	)

func get_eligible_normal_majors(
	character: Dictionary
) -> Array:
	var eligible_majors: Array = []

	for major_value in CharacterManager.majors:
		if typeof(
			major_value
		) != TYPE_DICTIONARY:
			continue

		var major: Dictionary = major_value

		if is_fallback_major(major):
			continue

		var required_stats_value = major.get(
			"required_stats",
			{}
		)

		if typeof(
			required_stats_value
		) != TYPE_DICTIONARY:
			continue

		var required_stats: Dictionary = (
			required_stats_value
		)

		if not CharacterManager.character_meets_required_stats(
			character,
			required_stats
		):
			continue

		eligible_majors.append(
			major
		)

	return eligible_majors
	
func get_fallback_majors() -> Array:
	var fallback_majors: Array = []

	for major_value in CharacterManager.majors:
		if typeof(
			major_value
		) != TYPE_DICTIONARY:
			continue

		var major: Dictionary = major_value

		if is_fallback_major(major):
			fallback_majors.append(
				major
			)

	return fallback_majors

func get_available_majors_for_character(
	character_id: int
) -> Array:
	var character := CharacterManager.get_character_by_id(
		character_id
	)

	if character.is_empty():
		push_error(
			"Character could not be found: "
			+ str(character_id)
		)
		return []

	if not should_request_major_selection(
		character
	):
		return []

	var eligible_normal_majors := (
		get_eligible_normal_majors(
			character
		)
	)

	if not eligible_normal_majors.is_empty():
		return eligible_normal_majors

	var fallback_majors := get_fallback_majors()

	if fallback_majors.is_empty():
		push_error(
			"No fallback majors could be found."
		)
		return []

	return fallback_majors

func get_major_by_id(
	major_id: int
) -> Dictionary:
	for major_value in CharacterManager.majors:
		if typeof(
			major_value
		) != TYPE_DICTIONARY:
			continue

		var major: Dictionary = major_value

		if int(
			major.get(
				"major_id",
				0
			)
		) == major_id:
			return major

	return {}

func is_major_available_for_character(
	character_id: int,
	major_id: int
) -> bool:
	var available_majors := (
		get_available_majors_for_character(
			character_id
		)
	)

	for major_value in available_majors:
		if typeof(
			major_value
		) != TYPE_DICTIONARY:
			continue

		var major: Dictionary = major_value

		if int(
			major.get(
				"major_id",
				0
			)
		) == major_id:
			return true

	return false

func get_expected_major_graduation_date(
	character: Dictionary,
	major: Dictionary
) -> String:
	var birth_date := String(
		character.get(
			"birth_date",
			""
		)
	)

	var date_parts := birth_date.split("-")

	if date_parts.size() != 3:
		push_error(
			"Invalid character birth date: "
			+ birth_date
		)
		return ""

	var birth_year := int(
		date_parts[0]
	)

	var birth_month := int(
		date_parts[1]
	)

	var birth_day := int(
		date_parts[2]
	)

	var duration_years := int(
		major.get(
			"duration_years",
			0
		)
	)

	if duration_years < 3:
		push_error(
			"Major duration cannot be less than 3 years."
		)
		return ""

	var graduation_age := (
		UNIVERSITY_START_AGE
		+ duration_years
	)

	var graduation_year := (
		birth_year
		+ graduation_age
	)

	return "%04d-%02d-%02d" % [
		graduation_year,
		birth_month,
		birth_day
	]

func select_major(
	character_id: int,
	major_id: int
) -> bool:
	var character := CharacterManager.get_character_by_id(
		character_id
	)

	if character.is_empty():
		push_error(
			"Character could not be found: "
			+ str(character_id)
		)
		return false

	if not character.get(
		"is_alive",
		true
	):
		return false

	if not is_major_available_for_character(
		character_id,
		major_id
	):
		push_error(
			"Major is not available for character: "
			+ str(major_id)
		)
		return false

	var major := get_major_by_id(
		major_id
	)

	if major.is_empty():
		push_error(
			"Major could not be found: "
			+ str(major_id)
		)
		return false

	var duration_years := int(
		major.get(
			"duration_years",
			0
		)
	)

	var selection_date := (
		TimeManager.get_iso_date_string()
	)

	var expected_graduation_date := (
		get_expected_major_graduation_date(
			character,
			major
		)
	)

	if expected_graduation_date.is_empty():
		return false

	character["major_id"] = major_id

	character["major_selection_date"] = (
		selection_date
	)

	character["expected_graduation_date"] = (
		expected_graduation_date
	)

	add_education_event_log(
		character,
		"major_selected",
		int(
			character.get(
				"school_id",
				0
			)
		),
		major_id
	)

	print(
		"Major selected: ",
		major_id,
		" | Character: ",
		character_id,
		" | Expected graduation: ",
		expected_graduation_date
	)

	if duration_years == 3:
		graduate_current_school(
			character,
			"university"
		)

	complete_current_education_event()

	return true

func check_university_graduations() -> void:
	var current_date := (
		TimeManager.get_iso_date_string()
	)

	for character_value in CharacterManager.characters:
		if typeof(
			character_value
		) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = (
			character_value
		)

		if not character.get(
			"is_alive",
			true
		):
			continue

		if String(
			character.get(
				"education_status",
				"none"
			)
		) != "studying":
			continue

		if character.get(
			"major_id",
			null
		) == null:
			continue

		var expected_date_value = character.get(
			"expected_graduation_date",
			null
		)

		if expected_date_value == null:
			continue

		var expected_date := String(
			expected_date_value
		)

		if expected_date.is_empty():
			continue

		if current_date != expected_date:
			continue

		graduate_current_school(
			character,
			"university"
		)

func get_expected_education_stage_for_age(
	age: int
) -> String:
	match age:
		PRIMARY_START_AGE:
			return "primary_school"

		MIDDLE_START_AGE:
			return "middle_school"

		HIGH_START_AGE:
			return "high_school"

		UNIVERSITY_START_AGE:
			return "university"

	return ""
