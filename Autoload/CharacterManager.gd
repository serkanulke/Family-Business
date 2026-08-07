extends Node

signal character_died(
	character_id: int,
	death_date: String
)

signal character_born(
	character_id: int,
	mother_id: int,
	father_id: int
)

const CHARACTER_DATA_PATH := "res://Resources/Json/Character.json"
const MAJOR_DATA_PATH := "res://Resources/Json/Major.json"
const JOB_DATA_PATH := "res://Resources/Json/Job.json"

const UNIVERSITY_START_AGE := 18
const STARTING_MAJOR_CHANCE := 0.70
const NO_DIPLOMA_JOB_CHANCE_FOR_GRADUATE := 0.20

const AVATAR_FOLDER_PATH := "res://Resources/Characters/"
const DEFAULT_AVATAR_PATH := AVATAR_FOLDER_PATH + "default_avatar.png"

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

const HAIR_COLORS: Array[String] = [
	"blonde",
	"red",
	"brown",
	"black"
]

const SKIN_TONES: Array[String] = [
	"light",
	"mixed",
	"dark"
]

const EYE_COLORS: Array[String] = [
	"hazel",
	"green",
	"blue"
]


var characters: Array = []
var majors: Array = []
var jobs: Array = []
var next_character_id: int = 1


func _ready() -> void:
	load_characters()
	load_major_data()
	load_job_data()

	TimeManager.date_changed.connect(_on_date_changed)

	update_all_life_stages()
	update_all_retirements()

	
		
		


func load_characters() -> void:
	if not FileAccess.file_exists(CHARACTER_DATA_PATH):
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
	var parse_result := json.parse(json_text)

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

	if not data.has("characters"):
		push_error(
			"Character JSON does not contain a characters array."
		)
		return

	if typeof(data["characters"]) != TYPE_ARRAY:
		push_error(
			"The characters value must be an Array."
		)
		return

	characters = data["characters"]
	normalize_character_ids()
	initialize_next_character_id()

	print("Characters loaded: ", characters.size())

	if not characters.is_empty():
		var test_character: Dictionary = characters[0]

		print(
			"Test character ID: ",
			test_character.get("character_id", null)
		)

		print(
			"Test character gender: ",
			test_character.get("gender", "")
		)

		print(
			"Test character genetics: ",
			test_character.get("genetics", {})
		)


func load_json_array(
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

	var json_text := file.get_as_text()
	var json := JSON.new()
	var parse_result := json.parse(json_text)

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
			% [root_key, file_path]
		)
		return []

	if typeof(data[root_key]) != TYPE_ARRAY:
		push_error(
			"'%s' must be an Array: %s"
			% [root_key, file_path]
		)
		return []

	return data[root_key]


func load_major_data() -> void:
	majors = load_json_array(
		MAJOR_DATA_PATH,
		"majors"
	)

	for major_value in majors:
		if typeof(major_value) != TYPE_DICTIONARY:
			continue

		var major: Dictionary = major_value
		major["major_id"] = int(
			major.get("major_id", 0)
		)

	print("Majors loaded: ", majors.size())


func load_job_data() -> void:
	jobs = load_json_array(
		JOB_DATA_PATH,
		"jobs"
	)

	for job_value in jobs:
		if typeof(job_value) != TYPE_DICTIONARY:
			continue

		var job: Dictionary = job_value

		job["job_id"] = int(
			job.get("job_id", 0)
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
			job.get("base_salary", 0)
		)

	print("Jobs loaded: ", jobs.size())





func get_avatar_path(character: Dictionary) -> String:
	var genetics_value = character.get("genetics", {})

	if typeof(genetics_value) != TYPE_DICTIONARY:
		push_error(
			"Character genetics must be a Dictionary."
		)
		return DEFAULT_AVATAR_PATH

	var genetics: Dictionary = genetics_value

	var avatar_theme: String = character.get(
		"avatar_theme",
		""
	)

	var gender: String = character.get(
		"gender",
		""
	)

	var life_stage: String = character.get(
		"life_stage",
		""
	)

	var hair_color: String = genetics.get(
		"hair_color",
		""
	)

	var skin_tone: String = genetics.get(
		"skin_tone",
		""
	)

	var eye_color: String = genetics.get(
		"eye_color",
		""
	)

	var avatar_file_name := (
		"%s_%s_%s_%s_%s_%s.png"
		% [
			avatar_theme,
			gender,
			life_stage,
			hair_color,
			skin_tone,
			eye_color
		]
	)

	var avatar_path := (
		AVATAR_FOLDER_PATH
		+ avatar_file_name
	)

	if ResourceLoader.exists(avatar_path):
		return avatar_path

	return DEFAULT_AVATAR_PATH


func get_avatar_texture(
	character: Dictionary
) -> Texture2D:
	var avatar_path := get_avatar_path(character)

	if not ResourceLoader.exists(avatar_path):
		push_error(
			"Avatar image could not be found: "
			+ avatar_path
		)
		return null

	var avatar_resource := ResourceLoader.load(
		avatar_path
	)

	if avatar_resource is not Texture2D:
		push_error(
			"Avatar file is not a Texture2D: "
			+ avatar_path
		)
		return null

	return avatar_resource as Texture2D
	
	
func _on_date_changed(_date_text: String) -> void:
	update_all_life_stages()
	update_all_retirements()
	update_all_death_checks()


func update_all_life_stages() -> void:
	for character_value in characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value

		if not character.get("is_alive", true):
			continue

		update_character_life_stage(character)


func update_character_life_stage(
	character: Dictionary
) -> void:
	var age := get_character_age(character)

	if age < 0:
		return

	var new_life_stage := get_life_stage_from_age(age)
	var current_life_stage: String = character.get(
		"life_stage",
		""
	)

	if current_life_stage == new_life_stage:
		return

	character["life_stage"] = new_life_stage

	print(
		"Character ",
		character.get("character_id", null),
		" life stage updated: ",
		current_life_stage,
		" -> ",
		new_life_stage
	)


func get_character_age(character: Dictionary) -> int:
	var birth_date: String = character.get(
		"birth_date",
		""
	)

	var date_parts := birth_date.split("-")

	if date_parts.size() != 3:
		push_error(
			"Invalid character birth date: "
			+ birth_date
		)
		return -1

	var birth_year := int(date_parts[0])
	var birth_month := int(date_parts[1])
	var birth_day := int(date_parts[2])

	var age := TimeManager.current_year - birth_year

	var birthday_has_not_happened := (
		TimeManager.current_month < birth_month
		or (
			TimeManager.current_month == birth_month
			and TimeManager.current_day < birth_day
		)
	)

	if birthday_has_not_happened:
		age -= 1

	return age


func get_life_stage_from_age(age: int) -> String:
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
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value

		if not character.get("is_alive", true):
			continue

		if character.get("is_retired", false):
			continue

		var age := get_character_age(character)

		if age >= RETIREMENT_AGE:
			retire_character(character)


func retire_character(character: Dictionary) -> void:
	var current_salary: int = int(
		character.get("salary", 0)
	)

	var pensionable_salary: int = mini(
		current_salary,
		PENSION_SALARY_CAP
	)

	var calculated_pension: int = int(
		round(
			float(pensionable_salary) * PENSION_RATE
		)
	)

	character["last_salary"] = current_salary
	character["pension"] = calculated_pension
	character["salary"] = 0
	character["is_retired"] = true

	print(
		"Character retired: ",
		character.get("character_id", null),
		" | Last salary: ",
		current_salary,
		" | Pension: ",
		calculated_pension
	)

func normalize_character_ids() -> void:
	for character_value in characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value

		character["character_id"] = int(
			character.get("character_id", 0)
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
		LIFESPAN_THRESHOLDS[lifespan_setting]
	)


func is_death_check_eligible(
	character: Dictionary
) -> bool:
	if not character.get("is_alive", true):
		return false

	var threshold := get_selected_lifespan_threshold()

	if threshold < 0:
		return false

	var effective_age := get_effective_death_age(
		character
	)

	if effective_age < 0.0:
		return false

	return effective_age >= float(threshold)

func kill_character(
	character: Dictionary
) -> void:
	if not character.get("is_alive", true):
		return

	var character_id := int(
		character.get("character_id", 0)
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
	var actual_age := get_character_age(character)

	if actual_age < 0:
		return -1.0

	var health := clampf(
		float(character.get("health", 50)),
		0.0,
		100.0
	)

	var health_age_modifier := (
		(NEUTRAL_HEALTH - health)
		/ HEALTH_POINTS_PER_AGE_YEAR
	)

	return float(actual_age) + health_age_modifier

func get_annual_death_chance(
	character: Dictionary
) -> float:
	if not is_death_check_eligible(character):
		return 0.0

	var threshold := float(
		get_selected_lifespan_threshold()
	)

	var effective_age := get_effective_death_age(
		character
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

	return clampf(annual_chance, 0.0, 1.0)

func get_daily_death_chance(
	character: Dictionary
) -> float:
	var annual_chance := get_annual_death_chance(
		character
	)

	if annual_chance <= 0.0:
		return 0.0

	if annual_chance >= 1.0:
		return 1.0

	return 1.0 - pow(
		1.0 - annual_chance,
		1.0 / 365.0
	)

func update_all_death_checks() -> void:
	for character_value in characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value

		if not character.get("is_alive", true):
			continue

		if not is_death_check_eligible(character):
			continue

		check_character_death(character)


func check_character_death(
	character: Dictionary
) -> void:
	var daily_chance := get_daily_death_chance(
		character
	)

	if daily_chance <= 0.0:
		return

	if daily_chance >= 1.0:
		kill_character(character)
		return

	if randf() <= daily_chance:
		kill_character(character)


func character_meets_required_stats(
	character: Dictionary,
	required_stats: Dictionary
) -> bool:
	for stat_name_value in required_stats.keys():
		var stat_name := String(stat_name_value)

		var required_value := float(
			required_stats.get(stat_name, 0)
		)

		var character_value := float(
			character.get(stat_name, 0)
		)

		if character_value < required_value:
			return false

	return true

func get_eligible_starting_majors(
	character: Dictionary
) -> Array:
	var eligible_majors: Array = []
	var character_age := get_character_age(character)

	if character_age < 0:
		return eligible_majors

	for major_value in majors:
		if typeof(major_value) != TYPE_DICTIONARY:
			continue

		var major: Dictionary = major_value

		if bool(
			major.get(
				"is_fallback",
				false
			)
		):
			continue

		var duration_years := int(
			major.get("duration_years", 0)
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

		if typeof(required_stats_value) != TYPE_DICTIONARY:
			continue

		var required_stats: Dictionary = (
			required_stats_value
		)

		if not character_meets_required_stats(
			character,
			required_stats
		):
			continue

		eligible_majors.append(major)

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

	var date_parts := birth_date.split("-")

	if date_parts.size() != 3:
		push_error(
			"Invalid character birth date: "
			+ birth_date
		)
		return ""

	var birth_year := int(date_parts[0])
	var birth_month := int(date_parts[1])
	var birth_day := int(date_parts[2])

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

	if typeof(event_log_value) != TYPE_ARRAY:
		event_log_value = []

	var event_log: Array = event_log_value

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
		get_eligible_starting_majors(character)
	)

	if eligible_majors.is_empty():
		print(
			"No eligible starting major for character: ",
			character.get("character_id", 0)
		)
		return

	if randf() > STARTING_MAJOR_CHANCE:
		print(
			"Character started without a major: ",
			character.get("character_id", 0)
		)
		return

	var selected_major_value = (
		eligible_majors.pick_random()
	)

	if typeof(selected_major_value) != TYPE_DICTIONARY:
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
		selected_major.get("major_name", ""),
		" | Character: ",
		character.get("character_id", 0)
	)

func get_eligible_no_diploma_jobs(
	character: Dictionary
) -> Array:
	var eligible_jobs: Array = []

	for job_value in jobs:
		if typeof(job_value) != TYPE_DICTIONARY:
			continue

		var job: Dictionary = job_value

		if job.get("required_major_id", null) != null:
			continue

		var required_stats_value = job.get(
			"required_stats",
			{}
		)

		if typeof(required_stats_value) != TYPE_DICTIONARY:
			continue

		if not character_meets_required_stats(
			character,
			required_stats_value
		):
			continue

		eligible_jobs.append(job)

	return eligible_jobs

func get_eligible_major_jobs(
	character: Dictionary,
	major_id: int
) -> Array:
	var eligible_jobs: Array = []

	for job_value in jobs:
		if typeof(job_value) != TYPE_DICTIONARY:
			continue

		var job: Dictionary = job_value
		var required_major_id = job.get(
			"required_major_id",
			null
		)

		if required_major_id == null:
			continue

		if int(required_major_id) != major_id:
			continue

		var required_stats_value = job.get(
			"required_stats",
			{}
		)

		if typeof(required_stats_value) != TYPE_DICTIONARY:
			continue

		if not character_meets_required_stats(
			character,
			required_stats_value
		):
			continue

		eligible_jobs.append(job)

	return eligible_jobs

func apply_starting_job(
	character: Dictionary,
	job: Dictionary
) -> void:
	character["job_id"] = int(
		job.get("job_id", 0)
	)

	character["salary"] = int(
		job.get("base_salary", 0)
	)

	print(
		"Starting job assigned: ",
		job.get("job_name", ""),
		" | Salary: ",
		character.get("salary", 0),
		" | Character: ",
		character.get("character_id", 0)
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
			get_eligible_no_diploma_jobs(character)
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
					int(major_id_value)
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
			character.get("character_id", 0)
		)
		return

	var selected_job_value = (
		selected_job_pool.pick_random()
	)

	if typeof(selected_job_value) != TYPE_DICTIONARY:
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
			generated_stats.get(stat_name, 0)
		)
		


func parent_has_max_stat(
	parent: Dictionary,
	stat_name: String
) -> bool:
	if parent.is_empty():
		return false

	return int(
		parent.get(stat_name, 0)
	) >= MAX_STAT_VALUE

func should_baby_inherit_stat_bonus(
	stat_name: String,
	parent_one: Dictionary,
	parent_two: Dictionary
) -> bool:
	if not INHERITABLE_STAT_NAMES.has(stat_name):
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

		generated_stats[stat_name] = stat_value

	return generated_stats

func initialize_next_character_id() -> void:
	var highest_character_id := 0

	for character_value in characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value
		var character_id := int(
			character.get("character_id", 0)
		)

		highest_character_id = maxi(
			highest_character_id,
			character_id
		)

	next_character_id = highest_character_id + 1


func generate_character_id() -> int:
	var generated_id := next_character_id
	next_character_id += 1

	return generated_id

func generate_birth_date_for_age(
	target_age: int
) -> String:
	var birth_month := randi_range(1, 12)
	

	var max_day: int = TimeManager.DAYS_IN_MONTH[
	birth_month - 1
]

	var birth_day := randi_range(1, max_day)

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

	var latest_birth_month := TimeManager.current_month
	var birth_month := randi_range(
		1,
		latest_birth_month
	)

	var max_day: int = TimeManager.DAYS_IN_MONTH[
		birth_month - 1
	]

	var birth_day: int

	if birth_month == TimeManager.current_month:
		var latest_birth_day := TimeManager.current_day - 1

		if latest_birth_day < 1:
			birth_month -= 1

			if birth_month < 1:
				birth_month = 12
				birth_year -= 1

			max_day = TimeManager.DAYS_IN_MONTH[
				birth_month - 1
			]

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
		"hair_color": HAIR_COLORS.pick_random(),
		"skin_tone": SKIN_TONES.pick_random(),
		"eye_color": EYE_COLORS.pick_random()
	}

func create_base_starting_character(
	first_name: String,
	gender: String
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

	var selected_age := randi_range(
		STARTING_CHARACTER_MIN_AGE,
		STARTING_CHARACTER_MAX_AGE
	)

	var character: Dictionary = {
		"character_id": generate_character_id(),

		"first_name": first_name.strip_edges(),
		"gender": normalized_gender,

		"avatar_theme": "classic",
		"genetics": generate_random_genetics(),

		"is_alive": true,
		"birth_date": generate_starting_birth_date_for_age(
			selected_age
		),
		"death_date": null,
		"life_stage": "young_adult",

		"is_player_family": true,

		"father_id": null,
		"mother_id": null,
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

		"flag_ids": [],
		"event_log": []
	}

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
	gender: String
) -> Dictionary:
	var character := create_base_starting_character(
		first_name,
		gender
	)

	if character.is_empty():
		return {}

	assign_starting_major(character)
	assign_starting_job(character)

	characters.append(character)

	print(
		"Starting character created: ",
		character.get("character_id", 0),
		" | Name: ",
		character.get("first_name", ""),
		" | Gender: ",
		character.get("gender", ""),
		" | Age: ",
		get_character_age(character),
		" | Major: ",
		character.get("major_id", null),
		" | Job: ",
		character.get("job_id", null),
		" | Salary: ",
		character.get("salary", 0)
	)

	return character

func reset_characters_for_new_game() -> void:
	characters.clear()
	next_character_id = 1

	print("Characters reset for new game.")

func get_parent_genetic_value(
	parent: Dictionary,
	genetic_name: String
) -> String:
	var genetics: Dictionary = parent["genetics"]

	return String(
		genetics[genetic_name]
	)
	

func generate_inherited_eye_color(
	parent_one: Dictionary,
	parent_two: Dictionary
) -> String:
	var eye_one := get_parent_genetic_value(
		parent_one,
		"eye_color"
	)

	var eye_two := get_parent_genetic_value(
		parent_two,
		"eye_color"
	)

	if eye_one == eye_two:
		return eye_one

	var one_parent_has_hazel := (
		eye_one == "hazel"
		or eye_two == "hazel"
	)

	if one_parent_has_hazel:
		if randf() < 0.65:
			return "hazel"

		if eye_one == "hazel":
			return eye_two

		return eye_one

	return String(
		[
			eye_one,
			eye_two
		].pick_random()
	)
	

func generate_inherited_hair_color(
	parent_one: Dictionary,
	parent_two: Dictionary
) -> String:
	var hair_one := get_parent_genetic_value(
		parent_one,
		"hair_color"
	)

	var hair_two := get_parent_genetic_value(
		parent_two,
		"hair_color"
	)

	if hair_one == hair_two:
		return hair_one

	return String(
		[
			hair_one,
			hair_two
		].pick_random()
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
		"hair_color": generate_inherited_hair_color(
			parent_one,
			parent_two
		),
		"skin_tone": generate_inherited_skin_tone(
			parent_one,
			parent_two
		),
		"eye_color": generate_inherited_eye_color(
			parent_one,
			parent_two
		)
	}

func get_character_by_id(
	character_id: int
) -> Dictionary:
	for character_value in characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value

		if int(
			character.get("character_id", 0)
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

	if typeof(children_ids_value) != TYPE_ARRAY:
		push_error(
			"Parent children_ids must be an Array."
		)
		return

	var children_ids: Array = children_ids_value

	if children_ids.has(child_id):
		return

	children_ids.append(child_id)
	parent["children_ids"] = children_ids

func create_base_baby_character(
	first_name: String,
	gender: String,
	mother: Dictionary,
	father: Dictionary
) -> Dictionary:
	var cleaned_name := first_name.strip_edges()

	if cleaned_name.is_empty():
		push_error(
			"Baby first name cannot be empty."
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
			"Invalid baby gender: "
			+ gender
		)
		return {}

	var baby: Dictionary = {
		"character_id": generate_character_id(),

		"first_name": cleaned_name,
		"gender": normalized_gender,

		"avatar_theme": "classic",
		"genetics": generate_baby_genetics(
			mother,
			father
		),

		"is_alive": true,
		"birth_date": TimeManager.get_iso_date_string(),
		"death_date": null,
		"life_stage": "baby",

		"is_player_family": true,

		"father_id": int(
			father["character_id"]
		),
		"mother_id": int(
			mother["character_id"]
		),
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

		"flag_ids": [],
		"event_log": []
	}

	var baby_stats := generate_baby_stats(
		mother,
		father
	)

	apply_stats_to_character(
		baby,
		baby_stats
	)

	return baby

func create_baby_character(
	first_name: String,
	gender: String,
	mother_id: int,
	father_id: int
) -> Dictionary:
	if mother_id == father_id:
		push_error(
			"Mother and father cannot have the same character ID."
		)
		return {}

	var mother := get_character_by_id(
		mother_id
	)

	if mother.is_empty():
		push_error(
			"Mother character could not be found: "
			+ str(mother_id)
		)
		return {}

	var father := get_character_by_id(
		father_id
	)

	if father.is_empty():
		push_error(
			"Father character could not be found: "
			+ str(father_id)
		)
		return {}

	if not mother.get("is_alive", true):
		push_error(
			"Mother character is not alive: "
			+ str(mother_id)
		)
		return {}

	if not father.get("is_alive", true):
		push_error(
			"Father character is not alive: "
			+ str(father_id)
		)
		return {}

	var baby := create_base_baby_character(
		first_name,
		gender,
		mother,
		father
	)

	if baby.is_empty():
		return {}

	var baby_id := int(
		baby["character_id"]
	)

	characters.append(baby)

	add_child_id_to_parent(
		mother,
		baby_id
	)

	add_child_id_to_parent(
		father,
		baby_id
	)

	character_born.emit(
		baby_id,
		mother_id,
		father_id
	)

	print(
		"Baby character created: ",
		baby_id,
		" | Name: ",
		baby.get("first_name", ""),
		" | Gender: ",
		baby.get("gender", ""),
		" | Mother: ",
		mother_id,
		" | Father: ",
		father_id,
		" | Birth date: ",
		baby.get("birth_date", "")
	)

	return baby
	
