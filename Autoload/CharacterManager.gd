extends Node


const CHARACTER_DATA_PATH := "res://Resources/Json/Character.json"

const AVATAR_FOLDER_PATH := "res://Resources/Characters/"
const DEFAULT_AVATAR_PATH := AVATAR_FOLDER_PATH + "default_avatar.png"

const RETIREMENT_AGE := 65
const PENSION_RATE := 0.10
const PENSION_SALARY_CAP := 25000


var characters: Array = []


func _ready() -> void:
	load_characters()

	TimeManager.date_changed.connect(_on_date_changed)

	update_all_life_stages()
	update_all_retirements()

	if not characters.is_empty():
		var test_character: Dictionary = characters[0]

		print(
			"Resolved avatar path: ",
			get_avatar_path(test_character)
		)

		print(
			"Test character age: ",
			get_character_age(test_character)
		)

		print(
			"Test character life stage: ",
			test_character.get("life_stage", "")
		)


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
