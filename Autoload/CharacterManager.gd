extends Node

signal character_died(
	character_id: int,
	death_date: String
)

signal character_born(
	character_id: int,
	parent_one_id: int,
	parent_two_id: int
)

signal age_reached(
	character_id: int,
	age: int
)

signal life_stage_changed(
	character_id: int,
	previous_stage: String,
	new_stage: String
)

signal character_retired(
	character_id: int
)

const CHARACTER_DATA_PATH := "res://Resources/Json/Character.json"
const MAJOR_DATA_PATH := "res://Resources/Json/Major.json"
const JOB_DATA_PATH := "res://Resources/Json/Job.json"

const UNIVERSITY_START_AGE := 18
const STARTING_MAJOR_CHANCE := 0.70
const NO_DIPLOMA_JOB_CHANCE_FOR_GRADUATE := 0.20

const AVATAR_FOLDER_PATH := "res://Resources/Characters/"
const DEFAULT_AVATAR_PATH := AVATAR_FOLDER_PATH + "default_avatar.png"

const GENDER_PORTRAIT_FOLDERS := {
	"male": "Male",
	"female": "Female"
}

const SKIN_PORTRAIT_FOLDERS := {
	"light": "Light",
	"mixed": "Mixed",
	"dark": "Dark"
}

const LIFE_STAGE_PORTRAIT_FOLDERS := {
	"baby": "Baby",
	"child": "Child",
	"teen": "Teen",
	"young_adult": "YoungAdult",
	"adult": "Adult",
	"elder": "Elder"
}

const RETIREMENT_AGE := 65
const PENSION_RATE := 0.10
const PENSION_SALARY_CAP := 25000

const LIFESPAN_THRESHOLDS := {
	"short": 68,
	"normal": 78,
	"long": 88
}

const DEATH_WINDOW_YEARS := 10.0
const BASE_ANNUAL_DEATH_CHANCE := 0.05
const ANNUAL_DEATH_CHANCE_INCREASE := 0.10

const NEUTRAL_HEALTH := 50.0
const HEALTH_POINTS_PER_AGE_YEAR := 10.0

const CHARACTER_STAT_NAMES: Array[String] = [
	"health",
	"happiness",
	"logic",
	"attractiveness",
	"social",
	"confidence",
	"discipline",
	"creativity"
]

const INHERITABLE_STAT_NAMES: Array[String] = [
	"health",
	"logic",
	"attractiveness",
	"social",
	"confidence",
	"discipline",
	"creativity"
]

const STARTING_WEAK_STAT_CHANCE := 0.10
const STARTING_MEDIUM_STAT_CHANCE := 0.80

const STARTING_WEAK_STAT_MIN := 15
const STARTING_WEAK_STAT_MAX := 34

const STARTING_MEDIUM_STAT_MIN := 35
const STARTING_MEDIUM_STAT_MAX := 65

const STARTING_STRONG_STAT_MIN := 66
const STARTING_STRONG_STAT_MAX := 85

const STARTING_HAPPINESS := 50

const BABY_STAT_MIN := 0
const BABY_STAT_MAX := 14
const MAX_PARENT_STAT_INHERITANCE_BONUS := 2
const MAX_STAT_VALUE := 100

const STARTING_CHARACTER_MIN_AGE := 18
const STARTING_CHARACTER_MAX_AGE := 25

const PUBLIC_UNIVERSITY_SCHOOL_ID := 4001

const SKIN_TONES: Array[String] = [
	"light",
	"mixed",
	"dark"
]


var characters: Array = []
var majors: Array = []
var jobs: Array = []
var next_character_id: int = 1


func _ready() -> void:
	load_characters()
	load_major_data()
	load_job_data()

	TimeManager.date_changed.connect(
		_on_date_changed
	)
	GameManager.new_game_starting.connect(
		_on_new_game_starting
	)

	update_all_life_stages()
	update_all_retirements()


func load_characters() -> void:
	if not FileAccess.file_exists(
		CHARACTER_DATA_PATH
	):
		push_error(
			"Character file could not be found: "
			+ CHARACTER_DATA_PATH
		)
		return

	var file := FileAccess.open(
		CHARACTER_DATA_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"Character file could not be opened: "
			+ CHARACTER_DATA_PATH
		)
		return

	var json_text := file.get_as_text()
	var json := JSON.new()
	var parse_result := json.parse(
		json_text
	)

	if parse_result != OK:
		push_error(
			"Character JSON error at line %d: %s"
			% [
				json.get_error_line(),
				json.get_error_message()
			]
		)
		return

	var data = json.data

	if typeof(data) != TYPE_DICTIONARY:
		push_error(
			"Character JSON root must be a Dictionary."
		)
		return

	if not data.has(
		"characters"
	):
		push_error(
			"Character JSON does not contain a characters array."
		)
		return

	if typeof(
		data["characters"]
	) != TYPE_ARRAY:
		push_error(
			"The characters value must be an Array."
		)
		return

	characters = data["characters"]

	normalize_character_ids()
	normalize_character_parent_links()
	normalize_character_portraits()
	initialize_next_character_id()

	print(
		"Characters loaded: ",
		characters.size()
	)

	if not characters.is_empty():
		var test_character: Dictionary = (
			characters[0]
		)

		print(
			"Test character ID: ",
			test_character.get(
				"character_id",
				null
			)
		)

		print(
			"Test character gender: ",
			test_character.get(
				"gender",
				""
			)
		)

		print(
			"Test character genetics: ",
			test_character.get(
				"genetics",
				{}
			)
		)


func load_json_array(
	file_path: String,
	root_key: String
) -> Array:
	if not FileAccess.file_exists(
		file_path
	):
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

	var json_text := file.get_as_text()
	var json := JSON.new()
	var parse_result := json.parse(
		json_text
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

	if not data.has(
		root_key
	):
		push_error(
			"JSON does not contain '%s': %s"
			% [
				root_key,
				file_path
			]
		)
		return []

	if typeof(
		data[root_key]
	) != TYPE_ARRAY:
		push_error(
			"'%s' must be an Array: %s"
			% [
				root_key,
				file_path
			]
		)
		return []

	return data[root_key]


func load_major_data() -> void:
	majors = load_json_array(
		MAJOR_DATA_PATH,
		"majors"
	)

	for major_value in majors:
		if typeof(
			major_value
		) != TYPE_DICTIONARY:
			continue

		var major: Dictionary = (
			major_value
		)

		major["major_id"] = int(
			major.get(
				"major_id",
				0
			)
		)

	print(
		"Majors loaded: ",
		majors.size()
	)


func load_job_data() -> void:
	jobs = load_json_array(
		JOB_DATA_PATH,
		"jobs"
	)

	for job_value in jobs:
		if typeof(
			job_value
		) != TYPE_DICTIONARY:
			continue

		var job: Dictionary = (
			job_value
		)

		job["job_id"] = int(
			job.get(
				"job_id",
				0
			)
		)

		var required_major_id = job.get(
			"required_major_id",
			null
		)

		if required_major_id != null:
			job["required_major_id"] = int(
				required_major_id
			)

		job["base_salary"] = int(
			job.get(
				"base_salary",
				0
			)
		)

	print(
		"Jobs loaded: ",
		jobs.size()
	)


func get_gender_portrait_folder(
	gender: String
) -> String:
	return String(
		GENDER_PORTRAIT_FOLDERS.get(
			gender.strip_edges().to_lower(),
			""
		)
	)


func get_skin_portrait_folder(
	skin_tone: String
) -> String:
	return String(
		SKIN_PORTRAIT_FOLDERS.get(
			skin_tone.strip_edges().to_lower(),
			""
		)
	)


func get_life_stage_portrait_folder(
	life_stage: String
) -> String:
	return String(
		LIFE_STAGE_PORTRAIT_FOLDERS.get(
			life_stage.strip_edges().to_lower(),
			""
		)
	)


func get_portrait_folder_path(
	gender: String,
	skin_tone: String,
	life_stage: String = "young_adult"
) -> String:
	var gender_folder := get_gender_portrait_folder(
		gender
	)
	var skin_folder := get_skin_portrait_folder(
		skin_tone
	)
	var life_stage_folder := (
		get_life_stage_portrait_folder(
			life_stage
		)
	)

	if (
		gender_folder.is_empty()
		or skin_folder.is_empty()
		or life_stage_folder.is_empty()
	):
		return ""

	return AVATAR_FOLDER_PATH.path_join(
		gender_folder
	).path_join(
		skin_folder
	).path_join(
		life_stage_folder
	)


func normalize_portrait_variant_id(
	variant_id: String
) -> String:
	var normalized := variant_id.strip_edges()

	if normalized.is_empty():
		return ""

	if normalized.is_valid_int():
		return "character_%03d" % int(normalized)

	return normalized


func get_portrait_variant_id_from_path(
	portrait_path: String
) -> String:
	var cleaned_path := portrait_path.strip_edges().replace(
		"\\",
		"/"
	)

	if not cleaned_path.to_lower().ends_with(
		".png"
	):
		return ""

	if cleaned_path.to_lower() == DEFAULT_AVATAR_PATH.to_lower():
		return ""

	return normalize_portrait_variant_id(
		cleaned_path.get_file().get_basename()
	)


func resolve_portrait_path(
	gender: String,
	skin_tone: String,
	life_stage: String,
	portrait_variant_id: String
) -> String:
	var folder_path := get_portrait_folder_path(
		gender,
		skin_tone,
		life_stage
	)
	var normalized_variant := (
		normalize_portrait_variant_id(
			portrait_variant_id
		)
	)

	if (
		folder_path.is_empty()
		or normalized_variant.is_empty()
	):
		return ""

	var portrait_path := folder_path.path_join(
		normalized_variant + ".png"
	)

	if not ResourceLoader.exists(
		portrait_path
	):
		return ""

	return portrait_path


func get_available_portrait_variants(
	gender: String,
	skin_tone: String,
	life_stage: String
) -> Array[String]:
	var result: Array[String] = []
	var folder_path := get_portrait_folder_path(
		gender,
		skin_tone,
		life_stage
	)

	if folder_path.is_empty():
		return result

	var directory := DirAccess.open(
		folder_path
	)

	if directory == null:
		push_warning(
			"Portrait folder could not be opened: "
			+ folder_path
		)
		return result

	directory.list_dir_begin()
	var file_name := directory.get_next()

	while not file_name.is_empty():
		if (
			not directory.current_is_dir()
			and file_name.to_lower().ends_with(
				".png"
			)
		):
			var full_path := folder_path.path_join(
				file_name
			)
			var variant_id := (
				get_portrait_variant_id_from_path(
					file_name
				)
			)

			if (
				not variant_id.is_empty()
				and ResourceLoader.exists(
					full_path
				)
				and not result.has(
					variant_id
				)
			):
				result.append(
					variant_id
				)

		file_name = directory.get_next()

	directory.list_dir_end()
	result.sort()

	return result


func select_random_portrait_variant(
	gender: String,
	skin_tone: String,
	life_stage: String,
	excluded_variant_ids: Array = []
) -> String:
	var variants := get_available_portrait_variants(
		gender,
		skin_tone,
		life_stage
	)

	for excluded_value in excluded_variant_ids:
		variants.erase(
			normalize_portrait_variant_id(
				String(excluded_value)
			)
		)

	if variants.is_empty():
		return ""

	return String(
		variants.pick_random()
	)


func get_portrait_paths(
	gender: String,
	skin_tone: String,
	life_stage: String = "young_adult"
) -> Array[String]:
	var result: Array[String] = []
	var variants := get_available_portrait_variants(
		gender,
		skin_tone,
		life_stage
	)

	for variant_id in variants:
		var portrait_path := resolve_portrait_path(
			gender,
			skin_tone,
			life_stage,
			variant_id
		)

		if not portrait_path.is_empty():
			result.append(
				portrait_path
			)

	return result


func get_random_portrait_path(
	gender: String,
	skin_tone: String,
	life_stage: String = "young_adult",
	excluded_variant_ids: Array = []
) -> String:
	var variant_id := select_random_portrait_variant(
		gender,
		skin_tone,
		life_stage,
		excluded_variant_ids
	)
	var portrait_path := resolve_portrait_path(
		gender,
		skin_tone,
		life_stage,
		variant_id
	)

	if portrait_path.is_empty():
		push_warning(
			"No eligible portrait PNG found for gender '%s', skin tone '%s', and life stage '%s'."
			% [
				gender,
				skin_tone,
				life_stage
			]
		)
		return DEFAULT_AVATAR_PATH

	return portrait_path


func get_parent_portrait_variant_exclusions(
	child_gender: String,
	parent_ids: Array
) -> Array[String]:
	var result: Array[String] = []
	var normalized_child_gender := (
		child_gender.strip_edges().to_lower()
	)

	for parent_id_value in parent_ids:
		var parent := get_character_by_id(
			int(parent_id_value)
		)

		if parent.is_empty():
			continue

		if String(
			parent.get(
				"gender",
				""
			)
		).strip_edges().to_lower() != normalized_child_gender:
			continue

		var variant_id := normalize_portrait_variant_id(
			String(
				parent.get(
					"portrait_variant_id",
					""
				)
			)
		)

		if variant_id.is_empty():
			variant_id = get_portrait_variant_id_from_path(
				String(
					parent.get(
						"portrait_path",
						""
					)
				)
			)

		if (
			not variant_id.is_empty()
			and not result.has(
				variant_id
			)
		):
			result.append(
				variant_id
			)

	return result


func normalize_legacy_portrait_path(
	portrait_path: String
) -> String:
	var normalized := portrait_path.strip_edges().replace(
		"\\",
		"/"
	)

	if normalized.is_empty():
		return ""

	var replacements := {
		"res://Resources/Characters/Man/": "res://Resources/Characters/Male/",
		"res://Resources/Characters/man/": "res://Resources/Characters/Male/",
		"res://Resources/Characters/Woman/": "res://Resources/Characters/Female/",
		"res://Resources/Characters/woman/": "res://Resources/Characters/Female/"
	}

	for old_prefix in replacements:
		if normalized.begins_with(
			String(old_prefix)
		):
			return String(replacements[old_prefix]) + normalized.trim_prefix(
				String(old_prefix)
			)

	return normalized


func ensure_character_portrait(
	character: Dictionary
) -> String:
	var genetics_value = character.get(
		"genetics",
		{}
	)

	if typeof(
		genetics_value
	) != TYPE_DICTIONARY:
		push_warning(
			"Character genetics must be a Dictionary for portrait resolution."
		)
		character["portrait_path"] = DEFAULT_AVATAR_PATH
		return DEFAULT_AVATAR_PATH

	var genetics: Dictionary = genetics_value
	var gender := String(
		character.get(
			"gender",
			""
		)
	).strip_edges().to_lower()
	var skin_tone := String(
		genetics.get(
			"skin_tone",
			""
		)
	).strip_edges().to_lower()
	var life_stage := String(
		character.get(
			"life_stage",
			""
		)
	).strip_edges().to_lower()
	var direct_path := normalize_legacy_portrait_path(
		String(
			character.get(
				"portrait_path",
				""
			)
		)
	)
	var variant_id := normalize_portrait_variant_id(
		String(
			character.get(
				"portrait_variant_id",
				""
			)
		)
	)

	if variant_id.is_empty():
		variant_id = get_portrait_variant_id_from_path(
			direct_path
		)

	var resolved_path := resolve_portrait_path(
		gender,
		skin_tone,
		life_stage,
		variant_id
	)

	if resolved_path.is_empty():
		var parent_ids_value = character.get(
			"parent_ids",
			[]
		)
		var parent_ids: Array = []

		if typeof(parent_ids_value) == TYPE_ARRAY:
			parent_ids = parent_ids_value

		var exclusions := (
			get_parent_portrait_variant_exclusions(
				gender,
				parent_ids
			)
		)
		var selected_variant := (
			select_random_portrait_variant(
				gender,
				skin_tone,
				life_stage,
				exclusions
			)
		)

		if not selected_variant.is_empty():
			variant_id = selected_variant
			resolved_path = resolve_portrait_path(
				gender,
				skin_tone,
				life_stage,
				variant_id
			)

	if not variant_id.is_empty():
		character["portrait_variant_id"] = variant_id
	elif not character.has(
		"portrait_variant_id"
	):
		character["portrait_variant_id"] = ""

	if resolved_path.is_empty():
		push_warning(
			"Character %s has no eligible portrait for gender '%s', skin tone '%s', and life stage '%s'; using the default avatar."
			% [
				str(
					character.get(
						"character_id",
						"unknown"
					)
				),
				gender,
				skin_tone,
				life_stage
			]
		)
		character["portrait_path"] = DEFAULT_AVATAR_PATH
		return DEFAULT_AVATAR_PATH

	character["portrait_path"] = resolved_path
	return resolved_path


func normalize_character_portraits() -> void:
	for character_value in characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		ensure_character_portrait(
			character_value
		)


func get_avatar_path(
	character: Dictionary
) -> String:
	if character.is_empty():
		return DEFAULT_AVATAR_PATH

	return ensure_character_portrait(
		character
	)


func get_avatar_texture(
	character: Dictionary
) -> Texture2D:
	var avatar_path := get_avatar_path(
		character
	)

	if not ResourceLoader.exists(
		avatar_path
	):
		push_error(
			"Avatar image could not be found: "
			+ avatar_path
		)
		return null

	var avatar_resource := (
		ResourceLoader.load(
			avatar_path
		)
	)

	if avatar_resource is not Texture2D:
		push_error(
			"Avatar file is not a Texture2D: "
			+ avatar_path
		)
		return null

	return avatar_resource as Texture2D


func _on_date_changed(
	_date_text: String
) -> void:
	var previous_states: Array[Dictionary] = []

	for character_value in characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value
		if not bool(character.get("is_alive", true)):
			continue

		previous_states.append({
			"character": character,
			"character_id": int(character.get("character_id", 0)),
			"previous_stage": String(character.get("life_stage", "")),
			"was_retired": bool(character.get("is_retired", false)),
			"is_birthday": _is_character_birthday_today(character)
		})

	update_all_life_stages()
	update_all_retirements()

	for previous_state in previous_states:
		var character: Dictionary = previous_state["character"]
		var character_id := int(previous_state["character_id"])

		if bool(previous_state["is_birthday"]):
			var age := get_character_age(character)
			if age >= 0:
				age_reached.emit(
					character_id,
					age
				)

		var previous_stage := String(previous_state["previous_stage"])
		var new_stage := String(character.get("life_stage", ""))
		if previous_stage != new_stage:
			life_stage_changed.emit(
				character_id,
				previous_stage,
				new_stage
			)

		if (
			not bool(previous_state["was_retired"])
			and bool(character.get("is_retired", false))
		):
			character_retired.emit(
				character_id
			)

	update_all_death_checks()


func _on_new_game_starting() -> void:
	reset_characters_for_new_game()


func _is_character_birthday_today(
	character: Dictionary
) -> bool:
	return did_character_age_change_today(
		character
	)


func update_all_life_stages() -> void:
	for character_value in characters:
		if typeof(
			character_value
		) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = (
			character_value
		)

		if not bool(
			character.get(
				"is_alive",
				true
			)
		):
			continue

		update_character_life_stage(
			character
		)


func update_character_life_stage(
	character: Dictionary
) -> void:
	var age := get_character_age(
		character
	)

	if age < 0:
		return

	var new_life_stage := (
		get_life_stage_from_age(
			age
		)
	)

	var current_life_stage: String = String(
		character.get(
			"life_stage",
			""
		)
	)

	if current_life_stage == new_life_stage:
		return

	character["life_stage"] = (
		new_life_stage
	)

	ensure_character_portrait(
		character
	)

	print(
		"Character ",
		character.get(
			"character_id",
			null
		),
		" life stage updated: ",
		current_life_stage,
		" -> ",
		new_life_stage
	)


func get_character_age(
	character: Dictionary
) -> int:
	return get_character_age_on_date(
		character,
		TimeManager.get_iso_date_string()
	)


func get_character_age_on_date(
	character: Dictionary,
	date_text: String
) -> int:
	var birth_date: String = String(
		character.get(
			"birth_date",
			""
		)
	)

	var birth_date_parts := GameCalendar.parse_iso_date(
		birth_date
	)
	var current_date_parts := GameCalendar.parse_iso_date(
		date_text
	)

	if not bool(
		birth_date_parts.get(
			"valid",
			false
		)
	):
		push_error(
			"Invalid character birth date: "
			+ birth_date
		)
		return -1

	if not bool(
		current_date_parts.get(
			"valid",
			false
		)
	):
		push_error(
			"Invalid current date for character age: "
			+ date_text
		)
		return -1

	var birth_year := int(
		birth_date_parts["year"]
	)
	var birth_month := int(
		birth_date_parts["month"]
	)
	var birth_day := int(
		birth_date_parts["day"]
	)
	var current_year := int(
		current_date_parts["year"]
	)
	var current_month := int(
		current_date_parts["month"]
	)
	var current_day := int(
		current_date_parts["day"]
	)

	var age := (
		current_year
		- birth_year
	)

	var birthday_has_not_happened := (
		current_month < birth_month
		or (
			current_month == birth_month
			and current_day < birth_day
		)
	)

	if birthday_has_not_happened:
		age -= 1

	return age


func did_character_age_change_today(
	character: Dictionary
) -> bool:
	var current_date := TimeManager.get_iso_date_string()
	var previous_date := GameCalendar.add_days(
		current_date,
		-1
	)

	if previous_date.is_empty():
		return false

	var current_age := get_character_age_on_date(
		character,
		current_date
	)
	var previous_age := get_character_age_on_date(
		character,
		previous_date
	)

	return (
		current_age >= 0
		and previous_age >= 0
		and current_age > previous_age
	)


func get_life_stage_from_age(
	age: int
) -> String:
	if age <= 5:
		return "baby"

	if age <= 11:
		return "child"

	if age <= 17:
		return "teen"

	if age <= 34:
		return "young_adult"

	if age <= 59:
		return "adult"

	return "elder"


func update_all_retirements() -> void:
	for character_value in characters:
		if typeof(
			character_value
		) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = (
			character_value
		)

		if not bool(
			character.get(
				"is_alive",
				true
			)
		):
			continue

		if bool(
			character.get(
				"is_retired",
				false
			)
		):
			continue

		var age := get_character_age(
			character
		)

		if age >= RETIREMENT_AGE:
			retire_character(
				character
			)


func retire_character(
	character: Dictionary
) -> void:
	var current_salary: int = int(
		character.get(
			"salary",
			0
		)
	)

	var pensionable_salary: int = mini(
		current_salary,
		PENSION_SALARY_CAP
	)

	var calculated_pension: int = int(
		round(
			float(
				pensionable_salary
			)
			* PENSION_RATE
		)
	)

	character["last_salary"] = (
		current_salary
	)

	character["pension"] = (
		calculated_pension
	)

	character["salary"] = 0
	character["is_retired"] = true

	BusinessManager.remove_character_from_any_slot(
		int(
			character.get(
				"character_id",
				0
			)
		)
	)

	print(
		"Character retired: ",
		character.get(
			"character_id",
			null
		),
		" | Last salary: ",
		current_salary,
		" | Pension: ",
		calculated_pension
	)


func normalize_character_ids() -> void:
	for character_value in characters:
		if typeof(
			character_value
		) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = (
			character_value
		)

		character["character_id"] = int(
			character.get(
				"character_id",
				0
			)
		)


func normalize_character_flag_ids() -> void:
	for character_value in characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value
		var flag_values = character.get("flag_ids", [])
		if typeof(flag_values) != TYPE_ARRAY:
			character["flag_ids"] = []
			continue

		var normalized_flags: Array = []
		for flag_value in flag_values:
			var normalized_flag = (
				int(flag_value)
				if typeof(flag_value) in [TYPE_INT, TYPE_FLOAT]
				else flag_value
			)
			if normalized_flag not in normalized_flags:
				normalized_flags.append(normalized_flag)
		character["flag_ids"] = normalized_flags


func normalize_character_parent_links() -> void:
	for character_value in characters:
		if typeof(
			character_value
		) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = (
			character_value
		)

		var normalized_parent_ids: Array[int] = []

		var parent_ids_value = character.get(
			"parent_ids",
			null
		)

		if typeof(
			parent_ids_value
		) == TYPE_ARRAY:
			for parent_id_value in parent_ids_value:
				if parent_id_value == null:
					continue

				var parent_id := int(
					parent_id_value
				)

				if parent_id <= 0:
					continue

				if parent_id not in normalized_parent_ids:
					normalized_parent_ids.append(
						parent_id
					)
		else:
			var legacy_mother_id = character.get(
				"mother_id",
				null
			)

			var legacy_father_id = character.get(
				"father_id",
				null
			)

			if legacy_mother_id != null:
				var mother_id := int(
					legacy_mother_id
				)

				if mother_id > 0:
					normalized_parent_ids.append(
						mother_id
					)

			if legacy_father_id != null:
				var father_id := int(
					legacy_father_id
				)

				if (
					father_id > 0
					and father_id not in normalized_parent_ids
				):
					normalized_parent_ids.append(
						father_id
					)

		character["parent_ids"] = (
			normalized_parent_ids
		)

		if not character.has(
			"is_adopted"
		):
			character["is_adopted"] = false

		character.erase(
			"mother_id"
		)

		character.erase(
			"father_id"
		)


func get_selected_lifespan_threshold() -> int:
	if not GameManager.has_lifespan_setting():
		push_error(
			"Lifespan setting has not been selected."
		)
		return -1

	var lifespan_setting: String = (
		GameManager.lifespan_setting
	)

	if not LIFESPAN_THRESHOLDS.has(
		lifespan_setting
	):
		push_error(
			"Unknown lifespan setting: "
			+ lifespan_setting
		)
		return -1

	return int(
		LIFESPAN_THRESHOLDS[
			lifespan_setting
		]
	)


func is_death_check_eligible(
	character: Dictionary
) -> bool:
	if not bool(
		character.get(
			"is_alive",
			true
		)
	):
		return false

	var threshold := (
		get_selected_lifespan_threshold()
	)

	if threshold < 0:
		return false

	var effective_age := (
		get_effective_death_age(
			character
		)
	)

	if effective_age < 0.0:
		return false

	return effective_age >= float(
		threshold
	)


func kill_character(
	character: Dictionary
) -> void:
	if not bool(
		character.get(
			"is_alive",
			true
		)
	):
		return

	var character_id := int(
		character.get(
			"character_id",
			0
		)
	)

	var death_date := (
		TimeManager.get_iso_date_string()
	)

	character["is_alive"] = false
	character["death_date"] = death_date

	character_died.emit(
		character_id,
		death_date
	)

	print(
		"Character died: ",
		character_id,
		" | Death date: ",
		death_date
	)


func get_effective_death_age(
	character: Dictionary
) -> float:
	var actual_age := (
		get_character_age(
			character
		)
	)

	if actual_age < 0:
		return -1.0

	var health := clampf(
		float(
			character.get(
				"health",
				50
			)
		),
		0.0,
		100.0
	)

	var health_age_modifier := (
		(
			NEUTRAL_HEALTH
			- health
		)
		/ HEALTH_POINTS_PER_AGE_YEAR
	)

	return (
		float(
			actual_age
		)
		+ health_age_modifier
	)


func get_annual_death_chance(
	character: Dictionary
) -> float:
	if not is_death_check_eligible(
		character
	):
		return 0.0

	var threshold := float(
		get_selected_lifespan_threshold()
	)

	var effective_age := (
		get_effective_death_age(
			character
		)
	)

	var years_after_threshold := maxf(
		effective_age - threshold,
		0.0
	)

	if years_after_threshold >= DEATH_WINDOW_YEARS:
		return 1.0

	var annual_chance := (
		BASE_ANNUAL_DEATH_CHANCE
		+ (
			years_after_threshold
			* ANNUAL_DEATH_CHANCE_INCREASE
		)
	)

	return clampf(
		annual_chance,
		0.0,
		1.0
	)


func get_daily_death_chance(
	character: Dictionary
) -> float:
	var annual_chance := (
		get_annual_death_chance(
			character
		)
	)

	if annual_chance <= 0.0:
		return 0.0

	if annual_chance >= 1.0:
		return 1.0

	return (
		1.0
		- pow(
			1.0 - annual_chance,
			1.0 / 365.0
		)
	)


func update_all_death_checks() -> void:
	for character_value in characters:
		if typeof(
			character_value
		) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = (
			character_value
		)

		if not bool(
			character.get(
				"is_alive",
				true
			)
		):
			continue

		if not is_death_check_eligible(
			character
		):
			continue

		check_character_death(
			character
		)


func check_character_death(
	character: Dictionary
) -> void:
	var daily_chance := (
		get_daily_death_chance(
			character
		)
	)

	if daily_chance <= 0.0:
		return

	if daily_chance >= 1.0:
		kill_character(
			character
		)
		return

	if randf() <= daily_chance:
		kill_character(
			character
		)


func character_meets_required_stats(
	character: Dictionary,
	required_stats: Dictionary
) -> bool:
	for stat_name_value in required_stats.keys():
		var stat_name := String(
			stat_name_value
		)

		var required_value := float(
			required_stats.get(
				stat_name,
				0
			)
		)

		var character_value := float(
			character.get(
				stat_name,
				0
			)
		)

		if character_value < required_value:
			return false

	return true


func get_eligible_starting_majors(
	character: Dictionary
) -> Array:
	var eligible_majors: Array = []

	var character_age := (
		get_character_age(
			character
		)
	)

	if character_age < 0:
		return eligible_majors

	for major_value in majors:
		if typeof(
			major_value
		) != TYPE_DICTIONARY:
			continue

		var major: Dictionary = (
			major_value
		)

		if bool(
			major.get(
				"is_fallback",
				false
			)
		):
			continue

		var duration_years := int(
			major.get(
				"duration_years",
				0
			)
		)

		var graduation_age := (
			UNIVERSITY_START_AGE
			+ duration_years
		)

		if character_age < graduation_age:
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

		if not character_meets_required_stats(
			character,
			required_stats
		):
			continue

		eligible_majors.append(
			major
		)

	return eligible_majors


func get_date_for_character_age(
	character: Dictionary,
	target_age: int
) -> String:
	var birth_date := String(
		character.get(
			"birth_date",
			""
		)
	)

	var date_parts := birth_date.split(
		"-"
	)

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

	return "%04d-%02d-%02d" % [
		birth_year + target_age,
		birth_month,
		birth_day
	]


func apply_starting_education_history(
	character: Dictionary,
	major: Dictionary
) -> void:
	var major_id := int(
		major.get(
			"major_id",
			0
		)
	)

	var duration_years := int(
		major.get(
			"duration_years",
			0
		)
	)

	var university_start_date := (
		get_date_for_character_age(
			character,
			UNIVERSITY_START_AGE
		)
	)

	var major_selection_date := (
		get_date_for_character_age(
			character,
			21
		)
	)

	var graduation_date := (
		get_date_for_character_age(
			character,
			UNIVERSITY_START_AGE
			+ duration_years
		)
	)

	if (
		university_start_date.is_empty()
		or major_selection_date.is_empty()
		or graduation_date.is_empty()
	):
		return

	character["school_id"] = (
		PUBLIC_UNIVERSITY_SCHOOL_ID
	)

	character["major_id"] = major_id
	character["education_status"] = "graduated"

	character["education_start_date"] = (
		university_start_date
	)

	character["major_selection_date"] = (
		major_selection_date
	)

	character["expected_graduation_date"] = (
		graduation_date
	)

	character["graduation_date"] = (
		graduation_date
	)

	var event_log_value = character.get(
		"event_log",
		[]
	)

	if typeof(
		event_log_value
	) != TYPE_ARRAY:
		event_log_value = []

	var event_log: Array = (
		event_log_value
	)

	event_log.append({
		"event_type": "education_started",
		"date": university_start_date,
		"school_id": PUBLIC_UNIVERSITY_SCHOOL_ID,
		"major_id": null
	})

	event_log.append({
		"event_type": "major_selected",
		"date": major_selection_date,
		"school_id": PUBLIC_UNIVERSITY_SCHOOL_ID,
		"major_id": major_id
	})

	event_log.append({
		"event_type": "education_graduated",
		"date": graduation_date,
		"school_id": PUBLIC_UNIVERSITY_SCHOOL_ID,
		"major_id": major_id
	})

	character["event_log"] = event_log


func assign_starting_major(
	character: Dictionary
) -> void:
	character["major_id"] = null

	var eligible_majors := (
		get_eligible_starting_majors(
			character
		)
	)

	if eligible_majors.is_empty():
		print(
			"No eligible starting major for character: ",
			character.get(
				"character_id",
				0
			)
		)
		return

	if randf() > STARTING_MAJOR_CHANCE:
		print(
			"Character started without a major: ",
			character.get(
				"character_id",
				0
			)
		)
		return

	var selected_major_value = (
		eligible_majors.pick_random()
	)

	if typeof(
		selected_major_value
	) != TYPE_DICTIONARY:
		return

	var selected_major: Dictionary = (
		selected_major_value
	)

	apply_starting_education_history(
		character,
		selected_major
	)

	print(
		"Starting major assigned: ",
		selected_major.get(
			"major_name",
			""
		),
		" | Character: ",
		character.get(
			"character_id",
			0
		)
	)


func get_eligible_no_diploma_jobs(
	character: Dictionary
) -> Array:
	var eligible_jobs: Array = []

	for job_value in jobs:
		if typeof(
			job_value
		) != TYPE_DICTIONARY:
			continue

		var job: Dictionary = (
			job_value
		)

		if job.get(
			"required_major_id",
			null
		) != null:
			continue

		var required_stats_value = job.get(
			"required_stats",
			{}
		)

		if typeof(
			required_stats_value
		) != TYPE_DICTIONARY:
			continue

		if not character_meets_required_stats(
			character,
			required_stats_value
		):
			continue

		eligible_jobs.append(
			job
		)

	return eligible_jobs


func get_eligible_major_jobs(
	character: Dictionary,
	major_id: int
) -> Array:
	var eligible_jobs: Array = []

	for job_value in jobs:
		if typeof(
			job_value
		) != TYPE_DICTIONARY:
			continue

		var job: Dictionary = (
			job_value
		)

		var required_major_id = job.get(
			"required_major_id",
			null
		)

		if required_major_id == null:
			continue

		if int(
			required_major_id
		) != major_id:
			continue

		var required_stats_value = job.get(
			"required_stats",
			{}
		)

		if typeof(
			required_stats_value
		) != TYPE_DICTIONARY:
			continue

		if not character_meets_required_stats(
			character,
			required_stats_value
		):
			continue

		eligible_jobs.append(
			job
		)

	return eligible_jobs


func apply_starting_job(
	character: Dictionary,
	job: Dictionary
) -> void:
	character["job_id"] = int(
		job.get(
			"job_id",
			0
		)
	)

	character["salary"] = int(
		job.get(
			"base_salary",
			0
		)
	)

	print(
		"Starting job assigned: ",
		job.get(
			"job_name",
			""
		),
		" | Salary: ",
		character.get(
			"salary",
			0
		),
		" | Character: ",
		character.get(
			"character_id",
			0
		)
	)


func assign_starting_job(
	character: Dictionary
) -> void:
	character["job_id"] = null
	character["company_id"] = null
	character["salary"] = 0

	var major_id_value = character.get(
		"major_id",
		null
	)

	var selected_job_pool: Array = []

	if major_id_value == null:
		selected_job_pool = (
			get_eligible_no_diploma_jobs(
				character
			)
		)
	else:
		var should_use_no_diploma_job := (
			randf()
			< NO_DIPLOMA_JOB_CHANCE_FOR_GRADUATE
		)

		if should_use_no_diploma_job:
			selected_job_pool = (
				get_eligible_no_diploma_jobs(
					character
				)
			)
		else:
			selected_job_pool = (
				get_eligible_major_jobs(
					character,
					int(
						major_id_value
					)
				)
			)

			if selected_job_pool.is_empty():
				selected_job_pool = (
					get_eligible_no_diploma_jobs(
						character
					)
				)

	if selected_job_pool.is_empty():
		print(
			"No eligible starting job for character: ",
			character.get(
				"character_id",
				0
			)
		)
		return

	var selected_job_value = (
		selected_job_pool.pick_random()
	)

	if typeof(
		selected_job_value
	) != TYPE_DICTIONARY:
		return

	apply_starting_job(
		character,
		selected_job_value
	)


func generate_starting_stat_value() -> int:
	var roll := randf()

	if roll < STARTING_WEAK_STAT_CHANCE:
		return randi_range(
			STARTING_WEAK_STAT_MIN,
			STARTING_WEAK_STAT_MAX
		)

	var medium_limit := (
		STARTING_WEAK_STAT_CHANCE
		+ STARTING_MEDIUM_STAT_CHANCE
	)

	if roll < medium_limit:
		return randi_range(
			STARTING_MEDIUM_STAT_MIN,
			STARTING_MEDIUM_STAT_MAX
		)

	return randi_range(
		STARTING_STRONG_STAT_MIN,
		STARTING_STRONG_STAT_MAX
	)


func generate_starting_character_stats() -> Dictionary:
	var generated_stats: Dictionary = {}

	for stat_name in CHARACTER_STAT_NAMES:
		if stat_name == "happiness":
			generated_stats[stat_name] = (
				STARTING_HAPPINESS
			)
			continue

		generated_stats[stat_name] = (
			generate_starting_stat_value()
		)

	return generated_stats


func apply_stats_to_character(
	character: Dictionary,
	generated_stats: Dictionary
) -> void:
	for stat_name in CHARACTER_STAT_NAMES:
		character[stat_name] = int(
			generated_stats.get(
				stat_name,
				0
			)
		)


func set_character_stat(character_id: int, stat_name: String, value: int) -> Dictionary:
	if stat_name not in CHARACTER_STAT_NAMES:
		return {}
	var character := get_character_by_id(character_id)
	if character.is_empty():
		return {}
	var before := int(character.get(stat_name, 0))
	var after := clampi(value, 0, 100)
	character[stat_name] = after
	return {"before": before, "after": after, "applied_amount": after - before}


func set_character_flag(character_id: int, flag_id: Variant, enabled: bool) -> bool:
	if flag_id == null or str(flag_id).is_empty():
		return false
	var normalized_flag_id = int(flag_id) if typeof(flag_id) in [TYPE_INT, TYPE_FLOAT] else flag_id
	var character := get_character_by_id(character_id)
	if character.is_empty():
		return false
	var flags_value = character.get("flag_ids", [])
	var flags: Array = flags_value.duplicate() if typeof(flags_value) == TYPE_ARRAY else []
	if enabled:
		if normalized_flag_id not in flags:
			flags.append(normalized_flag_id)
	else:
		flags.erase(normalized_flag_id)
	character["flag_ids"] = flags
	return true


func parent_has_max_stat(
	parent: Dictionary,
	stat_name: String
) -> bool:
	if parent.is_empty():
		return false

	return int(
		parent.get(
			stat_name,
			0
		)
	) >= MAX_STAT_VALUE


func should_baby_inherit_stat_bonus(
	stat_name: String,
	parent_one: Dictionary,
	parent_two: Dictionary
) -> bool:
	if not INHERITABLE_STAT_NAMES.has(
		stat_name
	):
		return false

	return (
		parent_has_max_stat(
			parent_one,
			stat_name
		)
		or parent_has_max_stat(
			parent_two,
			stat_name
		)
	)


func generate_baby_stats(
	parent_one: Dictionary,
	parent_two: Dictionary
) -> Dictionary:
	var generated_stats: Dictionary = {}

	for stat_name in CHARACTER_STAT_NAMES:
		var stat_value := randi_range(
			BABY_STAT_MIN,
			BABY_STAT_MAX
		)

		if should_baby_inherit_stat_bonus(
			stat_name,
			parent_one,
			parent_two
		):
			stat_value += (
				MAX_PARENT_STAT_INHERITANCE_BONUS
			)

		generated_stats[stat_name] = (
			stat_value
		)

	return generated_stats


func generate_baby_stats_without_parent_inheritance() -> Dictionary:
	var generated_stats: Dictionary = {}

	for stat_name in CHARACTER_STAT_NAMES:
		generated_stats[stat_name] = randi_range(
			BABY_STAT_MIN,
			BABY_STAT_MAX
		)

	return generated_stats


func initialize_next_character_id() -> void:
	var highest_character_id := 0

	for character_value in characters:
		if typeof(
			character_value
		) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = (
			character_value
		)

		var character_id := int(
			character.get(
				"character_id",
				0
			)
		)

		highest_character_id = maxi(
			highest_character_id,
			character_id
		)

	next_character_id = (
		highest_character_id
		+ 1
	)


func generate_character_id() -> int:
	var generated_id := (
		next_character_id
	)

	next_character_id += 1

	return generated_id


func generate_birth_date_for_age(
	target_age: int
) -> String:
	var birth_month := randi_range(
		1,
		12
	)

	var max_day: int = (
		TimeManager.DAYS_IN_MONTH[
			birth_month - 1
		]
	)

	var birth_day := randi_range(
		1,
		max_day
	)

	var birth_year := (
		TimeManager.current_year
		- target_age
	)

	var birthday_has_not_happened := (
		birth_month > TimeManager.current_month
		or (
			birth_month == TimeManager.current_month
			and birth_day > TimeManager.current_day
		)
	)

	if birthday_has_not_happened:
		birth_year -= 1

	return "%04d-%02d-%02d" % [
		birth_year,
		birth_month,
		birth_day
	]


func generate_starting_birth_date_for_age(
	target_age: int
) -> String:
	var birth_year := (
		TimeManager.current_year
		- target_age
	)

	var latest_birth_month := (
		TimeManager.current_month
	)

	var birth_month := randi_range(
		1,
		latest_birth_month
	)

	var max_day: int = (
		TimeManager.DAYS_IN_MONTH[
			birth_month - 1
		]
	)

	var birth_day: int

	if birth_month == TimeManager.current_month:
		var latest_birth_day := (
			TimeManager.current_day
			- 1
		)

		if latest_birth_day < 1:
			birth_month -= 1

			if birth_month < 1:
				birth_month = 12
				birth_year -= 1

			max_day = (
				TimeManager.DAYS_IN_MONTH[
					birth_month - 1
				]
			)

			birth_day = randi_range(
				1,
				max_day
			)
		else:
			birth_day = randi_range(
				1,
				latest_birth_day
			)
	else:
		birth_day = randi_range(
			1,
			max_day
		)

	return "%04d-%02d-%02d" % [
		birth_year,
		birth_month,
		birth_day
	]


func generate_random_genetics() -> Dictionary:
	return {
		"skin_tone": SKIN_TONES.pick_random()
	}


func create_base_starting_character(
	first_name: String,
	gender: String,
	selected_skin_tone: String = "",
	selected_portrait_path: String = ""
) -> Dictionary:
	var normalized_gender := (
		gender.strip_edges().to_lower()
	)

	if normalized_gender not in [
		"female",
		"male"
	]:
		push_error(
			"Invalid starting character gender: "
			+ gender
		)
		return {}

	var normalized_skin_tone := (
		selected_skin_tone.strip_edges().to_lower()
	)

	var genetics := generate_random_genetics()

	if not normalized_skin_tone.is_empty():
		if not SKIN_TONES.has(
			normalized_skin_tone
		):
			push_error(
				"Invalid starting character skin tone: "
				+ selected_skin_tone
			)
			return {}

		genetics["skin_tone"] = normalized_skin_tone

	var selected_age := randi_range(
		STARTING_CHARACTER_MIN_AGE,
		STARTING_CHARACTER_MAX_AGE
	)
	var selected_life_stage := get_life_stage_from_age(
		selected_age
	)
	var resolved_portrait_path := (
		normalize_legacy_portrait_path(
			selected_portrait_path
		)
	)
	var selected_variant_id := (
		get_portrait_variant_id_from_path(
			resolved_portrait_path
		)
	)

	var character: Dictionary = {
		"character_id": generate_character_id(),

		"first_name": first_name.strip_edges(),
		"gender": normalized_gender,

		"avatar_theme": "classic",
		"genetics": genetics,

		"is_alive": true,
		"birth_date": generate_starting_birth_date_for_age(
			selected_age
		),
		"death_date": null,
		"life_stage": selected_life_stage,

		"is_player_family": true,

		"parent_ids": [],
		"is_adopted": false,
		"partner_id": null,
		"children_ids": [],

		"school_id": null,
		"major_id": null,

		"education_status": "none",
		"education_start_date": null,
		"major_selection_date": null,
		"expected_graduation_date": null,
		"graduation_date": null,

		"is_retired": false,
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"last_salary": 0,
		"pension": 0,

		"unemployment_start_date": null,
		"job_offer_cooldown_until": null,

		"flag_ids": [],
		"event_log": []
	}

	character["portrait_variant_id"] = selected_variant_id

	if not resolved_portrait_path.is_empty():
		character["portrait_path"] = resolved_portrait_path

	ensure_character_portrait(
		character
	)

	var starting_stats := (
		generate_starting_character_stats()
	)

	apply_stats_to_character(
		character,
		starting_stats
	)

	return character


func create_starting_character(
	first_name: String,
	gender: String,
	skin_tone: String = "",
	portrait_path: String = ""
) -> Dictionary:
	var character := (
		create_base_starting_character(
			first_name,
			gender,
			skin_tone,
			portrait_path
		)
	)

	if character.is_empty():
		return {}

	assign_starting_major(
		character
	)

	assign_starting_job(
		character
	)

	characters.append(
		character
	)

	print(
		"Starting character created: ",
		character.get(
			"character_id",
			0
		),
		" | Name: ",
		character.get(
			"first_name",
			""
		),
		" | Gender: ",
		character.get(
			"gender",
			""
		),
		" | Age: ",
		get_character_age(
			character
		),
		" | Major: ",
		character.get(
			"major_id",
			null
		),
		" | Job: ",
		character.get(
			"job_id",
			null
		),
		" | Salary: ",
		character.get(
			"salary",
			0
		)
	)

	return character


func reset_characters_for_new_game() -> void:
	if characters.is_empty() and next_character_id == 1:
		return

	characters.clear()
	next_character_id = 1

	print(
		"Characters reset for new game."
	)


func get_parent_genetic_value(
	parent: Dictionary,
	genetic_name: String
) -> String:
	var genetics_value = parent.get(
		"genetics",
		{}
	)

	if typeof(
		genetics_value
	) != TYPE_DICTIONARY:
		return ""

	var genetics: Dictionary = (
		genetics_value
	)

	return String(
		genetics.get(
			genetic_name,
			""
		)
	)


func generate_inherited_skin_tone(
	parent_one: Dictionary,
	parent_two: Dictionary
) -> String:
	var skin_one := get_parent_genetic_value(
		parent_one,
		"skin_tone"
	)

	var skin_two := get_parent_genetic_value(
		parent_two,
		"skin_tone"
	)

	if skin_one == skin_two:
		return skin_one

	return String(
		SKIN_TONES.pick_random()
	)


func generate_baby_genetics(
	parent_one: Dictionary,
	parent_two: Dictionary
) -> Dictionary:
	return {
		"skin_tone": generate_inherited_skin_tone(
			parent_one,
			parent_two
		)
	}


func is_valid_genetics_profile(
	genetics: Dictionary
) -> bool:
	var skin_tone := String(
		genetics.get(
			"skin_tone",
			""
		)
	)

	return skin_tone in SKIN_TONES


func get_character_by_id(
	character_id: int
) -> Dictionary:
	for character_value in characters:
		if typeof(
			character_value
		) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = (
			character_value
		)

		if int(
			character.get(
				"character_id",
				0
			)
		) == character_id:
			return character

	return {}


func add_child_id_to_parent(
	parent: Dictionary,
	child_id: int
) -> void:
	var children_ids_value = parent.get(
		"children_ids",
		[]
	)

	if typeof(
		children_ids_value
	) != TYPE_ARRAY:
		push_error(
			"Parent children_ids must be an Array."
		)
		return

	var children_ids: Array = (
		children_ids_value
	)

	if children_ids.has(
		child_id
	):
		return

	children_ids.append(
		child_id
	)

	parent["children_ids"] = (
		children_ids
	)


func create_base_child_character(
	first_name: String,
	gender: String,
	parent_one: Dictionary,
	parent_two: Dictionary,
	genetic_source_one: Dictionary,
	genetic_source_two: Dictionary,
	is_adopted: bool
) -> Dictionary:
	var cleaned_name := (
		first_name.strip_edges()
	)

	if cleaned_name.is_empty():
		push_error(
			"Child first name cannot be empty."
		)
		return {}

	var normalized_gender := (
		gender.strip_edges().to_lower()
	)

	if normalized_gender not in [
		"female",
		"male"
	]:
		push_error(
			"Invalid child gender: "
			+ gender
		)
		return {}

	var parent_one_id := int(
		parent_one[
			"character_id"
		]
	)

	var parent_two_id := int(
		parent_two[
			"character_id"
		]
	)

	var child_genetics: Dictionary

	if is_adopted:
		child_genetics = generate_random_genetics()
	else:
		var genetics_one_value = genetic_source_one.get(
			"genetics",
			{}
		)

		var genetics_two_value = genetic_source_two.get(
			"genetics",
			{}
		)

		if (
			typeof(genetics_one_value) != TYPE_DICTIONARY
			or typeof(genetics_two_value) != TYPE_DICTIONARY
		):
			push_error(
				"Biological genetic sources must contain genetics Dictionaries."
			)
			return {}

		var genetics_one: Dictionary = genetics_one_value
		var genetics_two: Dictionary = genetics_two_value

		if (
			not is_valid_genetics_profile(genetics_one)
			or not is_valid_genetics_profile(genetics_two)
		):
			push_error(
				"Biological genetic source contains an invalid genetics profile."
			)
			return {}

		child_genetics = generate_baby_genetics(
			genetic_source_one,
			genetic_source_two
		)

	var child: Dictionary = {
		"character_id": generate_character_id(),

		"first_name": cleaned_name,
		"gender": normalized_gender,

		"avatar_theme": "classic",
		"genetics": child_genetics,
		"portrait_variant_id": "",

		"is_alive": true,
		"birth_date": TimeManager.get_iso_date_string(),
		"death_date": null,
		"life_stage": "baby",

		"is_player_family": true,

		"parent_ids": [
			parent_one_id,
			parent_two_id
		],
		"is_adopted": is_adopted,
		"partner_id": null,
		"children_ids": [],

		"school_id": null,
		"major_id": null,

		"education_status": "none",
		"education_start_date": null,
		"major_selection_date": null,
		"expected_graduation_date": null,
		"graduation_date": null,

		"is_retired": false,
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"last_salary": 0,
		"pension": 0,

		"unemployment_start_date": null,
		"job_offer_cooldown_until": null,

		"flag_ids": [],
		"event_log": []
	}

	var child_stats: Dictionary

	if is_adopted:
		child_stats = (
			generate_baby_stats_without_parent_inheritance()
		)
	else:
		child_stats = generate_baby_stats(
			genetic_source_one,
			genetic_source_two
		)

	apply_stats_to_character(
		child,
		child_stats
	)

	ensure_character_portrait(
		child
	)

	return child


func create_base_baby_character(
	first_name: String,
	gender: String,
	parent_one: Dictionary,
	parent_two: Dictionary
) -> Dictionary:
	return create_base_child_character(
		first_name,
		gender,
		parent_one,
		parent_two,
		parent_one,
		parent_two,
		false
	)


func _finalize_new_child(
	child: Dictionary,
	parent_one: Dictionary,
	parent_two: Dictionary
) -> Dictionary:
	if child.is_empty():
		return {}

	var child_id := int(
		child[
			"character_id"
		]
	)

	var parent_one_id := int(
		parent_one[
			"character_id"
		]
	)

	var parent_two_id := int(
		parent_two[
			"character_id"
		]
	)

	characters.append(
		child
	)

	add_child_id_to_parent(
		parent_one,
		child_id
	)

	add_child_id_to_parent(
		parent_two,
		child_id
	)

	character_born.emit(
		child_id,
		parent_one_id,
		parent_two_id
	)

	return child


func _get_valid_child_parents(
	parent_one_id: int,
	parent_two_id: int
) -> Array:
	if parent_one_id == parent_two_id:
		push_error(
			"A child cannot have the same character in both parent slots."
		)
		return []

	var parent_one := get_character_by_id(
		parent_one_id
	)

	if parent_one.is_empty():
		push_error(
			"Parent one could not be found: "
			+ str(
				parent_one_id
			)
		)
		return []

	var parent_two := get_character_by_id(
		parent_two_id
	)

	if parent_two.is_empty():
		push_error(
			"Parent two could not be found: "
			+ str(
				parent_two_id
			)
		)
		return []

	if not bool(
		parent_one.get(
			"is_alive",
			true
		)
	):
		push_error(
			"Parent one is not alive: "
			+ str(
				parent_one_id
			)
		)
		return []

	if not bool(
		parent_two.get(
			"is_alive",
			true
		)
	):
		push_error(
			"Parent two is not alive: "
			+ str(
				parent_two_id
			)
		)
		return []

	return [
		parent_one,
		parent_two
	]


func create_baby_character(
	first_name: String,
	gender: String,
	parent_one_id: int,
	parent_two_id: int
) -> Dictionary:
	var parents := _get_valid_child_parents(
		parent_one_id,
		parent_two_id
	)

	if parents.size() != 2:
		return {}

	var parent_one: Dictionary = parents[0]
	var parent_two: Dictionary = parents[1]

	var baby := create_base_baby_character(
		first_name,
		gender,
		parent_one,
		parent_two
	)

	if baby.is_empty():
		return {}

	_finalize_new_child(
		baby,
		parent_one,
		parent_two
	)

	print(
		"Baby character created: ",
		baby.get(
			"character_id",
			0
		),
		" | Name: ",
		baby.get(
			"first_name",
			""
		),
		" | Gender: ",
		baby.get(
			"gender",
			""
		),
		" | Parent 1: ",
		parent_one_id,
		" | Parent 2: ",
		parent_two_id,
		" | Birth date: ",
		baby.get(
			"birth_date",
			""
		)
	)

	return baby


func create_donor_conceived_baby_character(
	first_name: String,
	gender: String,
	carrier_id: int,
	second_parent_id: int,
	donor_genetics: Dictionary
) -> Dictionary:
	var parents := _get_valid_child_parents(
		carrier_id,
		second_parent_id
	)

	if parents.size() != 2:
		return {}

	var carrier: Dictionary = parents[0]
	var second_parent: Dictionary = parents[1]

	if String(
		carrier.get(
			"gender",
			""
		)
	) != "female":
		push_error(
			"Donor-conceived baby's carrier must be female."
		)
		return {}

	if not is_valid_genetics_profile(
		donor_genetics
	):
		push_error(
			"Anonymous donor genetics are invalid."
		)
		return {}

	var anonymous_donor: Dictionary = {
		"genetics": donor_genetics.duplicate(true)
	}

	var baby := create_base_child_character(
		first_name,
		gender,
		carrier,
		second_parent,
		carrier,
		anonymous_donor,
		false
	)

	if baby.is_empty():
		return {}

	_finalize_new_child(
		baby,
		carrier,
		second_parent
	)

	print(
		"Donor-conceived baby created: ",
		baby.get(
			"character_id",
			0
		),
		" | Carrier: ",
		carrier_id,
		" | Second parent: ",
		second_parent_id
	)

	return baby


func create_adopted_child_character(
	first_name: String,
	gender: String,
	parent_one_id: int,
	parent_two_id: int
) -> Dictionary:
	var parents := _get_valid_child_parents(
		parent_one_id,
		parent_two_id
	)

	if parents.size() != 2:
		return {}

	var parent_one: Dictionary = parents[0]
	var parent_two: Dictionary = parents[1]

	var child := create_base_child_character(
		first_name,
		gender,
		parent_one,
		parent_two,
		{},
		{},
		true
	)

	if child.is_empty():
		return {}

	_finalize_new_child(
		child,
		parent_one,
		parent_two
	)

	print(
		"Adopted child created: ",
		child.get(
			"character_id",
			0
		),
		" | Parent 1: ",
		parent_one_id,
		" | Parent 2: ",
		parent_two_id
	)

	return child
