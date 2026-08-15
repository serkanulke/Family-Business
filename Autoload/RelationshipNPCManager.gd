extends Node

signal relationship_candidate_created(
	character_id: int,
	linked_character_id: int
)

const RELATIONSHIP_NPC_DATA_PATH := \
	"res://Resources/Json/relationship_npc.json"

const UNIVERSITY_START_AGE := 18
const MAJOR_SELECTION_AGE := 21

var generation_config: Dictionary = {}
var name_config: Dictionary = {}

var relationship_candidate_ids: Array[int] = []

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	load_relationship_npc_data()


func load_relationship_npc_data() -> bool:
	generation_config = {}
	name_config = {}

	if not FileAccess.file_exists(RELATIONSHIP_NPC_DATA_PATH):
		push_error(
			"Relationship NPC file could not be found: "
			+ RELATIONSHIP_NPC_DATA_PATH
		)
		return false

	var file := FileAccess.open(
		RELATIONSHIP_NPC_DATA_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"Relationship NPC file could not be opened: "
			+ RELATIONSHIP_NPC_DATA_PATH
		)
		return false

	var parsed_value = JSON.parse_string(
		file.get_as_text()
	)

	if typeof(parsed_value) != TYPE_DICTIONARY:
		push_error(
			"Relationship NPC JSON root must be a Dictionary."
		)
		return false

	var root: Dictionary = parsed_value

	var generation_value = root.get(
		"generation",
		{}
	)

	var names_value = root.get(
		"names",
		{}
	)

	if typeof(generation_value) != TYPE_DICTIONARY:
		push_error(
			"Relationship NPC generation config is invalid."
		)
		return false

	if typeof(names_value) != TYPE_DICTIONARY:
		push_error(
			"Relationship NPC name config is invalid."
		)
		return false

	generation_config = generation_value
	name_config = names_value

	return validate_generation_config()


func validate_generation_config() -> bool:
	var minimum_age := int(
		generation_config.get(
			"minimum_age",
			18
		)
	)

	var maximum_age := int(
		generation_config.get(
			"maximum_age",
			50
		)
	)

	var maximum_age_gap := int(
		generation_config.get(
			"maximum_age_gap",
			14
		)
	)

	var maximum_relationship_age := int(
		generation_config.get(
			"maximum_relationship_age",
			54
		)
	)

	var maximum_female_fertility_age := int(
		generation_config.get(
			"maximum_female_fertility_age",
			49
		)
	)

	if minimum_age < 18:
		push_error(
			"Relationship NPC minimum age cannot be below 18."
		)
		return false

	if maximum_age < minimum_age:
		push_error(
			"Relationship NPC maximum age cannot be below minimum age."
		)
		return false

	if maximum_age_gap < 0:
		push_error(
			"Relationship NPC maximum age gap cannot be negative."
		)
		return false

	if maximum_relationship_age < minimum_age:
		push_error(
			"Maximum relationship age is invalid."
		)
		return false

	if maximum_female_fertility_age >= maximum_relationship_age:
		# This is allowed by design only when explicitly changed later.
		# Current confirmed values are 49 and 54.
		pass

	return true


func is_character_relationship_eligible(
	character: Dictionary
) -> bool:
	if character.is_empty():
		return false

	if not bool(
		character.get(
			"is_alive",
			true
		)
	):
		return false

	if not bool(
		character.get(
			"is_player_family",
			false
		)
	):
		return false

	if character.get(
		"partner_id",
		null
	) != null:
		return false

	var age := CharacterManager.get_character_age(
		character
	)

	var minimum_age := int(
		generation_config.get(
			"minimum_relationship_age",
			18
		)
	)

	var maximum_age := int(
		generation_config.get(
			"maximum_relationship_age",
			54
		)
	)

	return (
		age >= minimum_age
		and age <= maximum_age
	)


func get_candidate_age_bounds(
	family_character: Dictionary
) -> Vector2i:
	var family_age := CharacterManager.get_character_age(
		family_character
	)

	var minimum_age := int(
		generation_config.get(
			"minimum_age",
			18
		)
	)

	var maximum_age := int(
		generation_config.get(
			"maximum_age",
			50
		)
	)

	var maximum_age_gap := int(
		generation_config.get(
			"maximum_age_gap",
			14
		)
	)

	var min_candidate_age := maxi(
		minimum_age,
		family_age - maximum_age_gap
	)

	var max_candidate_age := mini(
		maximum_age,
		family_age + maximum_age_gap
	)

	return Vector2i(
		min_candidate_age,
		max_candidate_age
	)


func create_relationship_candidate(
	linked_character_id: int
) -> Dictionary:
	var linked_character := CharacterManager.get_character_by_id(
		linked_character_id
	)

	if not is_character_relationship_eligible(
		linked_character
	):
		return {}

	var age_bounds := get_candidate_age_bounds(
		linked_character
	)

	if age_bounds.x > age_bounds.y:
		return {}

	var candidate_age := rng.randi_range(
		age_bounds.x,
		age_bounds.y
	)

	var gender := (
		"male"
		if rng.randi_range(0, 1) == 0
		else "female"
	)

	var first_name := pick_random_name(
		gender
	)

	if first_name.is_empty():
		return {}

	var stats := CharacterManager.generate_starting_character_stats()

	var candidate: Dictionary = {
		"character_id": CharacterManager.generate_character_id(),
		"character_type": "relationship_npc",
		"first_name": first_name,
		"gender": gender,
		"avatar_theme": "classic",
		"genetics": CharacterManager.generate_random_genetics(),
		"is_alive": true,
		"birth_date": CharacterManager.generate_birth_date_for_age(
			candidate_age
		),
		"death_date": null,
		"life_stage": CharacterManager.get_life_stage_from_age(
			candidate_age
		),
		"is_player_family": false,
		"linked_character_id": linked_character_id,
		"relationship_status": "candidate",
		"father_id": null,
		"mother_id": null,
		"partner_id": null,
		"children_ids": [],
		"school_id": null,
		"major_id": null,
		"education_status": "graduated",
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

	CharacterManager.apply_stats_to_character(
		candidate,
		stats
	)

	generate_education_and_career(
		candidate
	)

	CharacterManager.characters.append(
		candidate
	)

	relationship_candidate_ids.append(
		int(candidate["character_id"])
	)

	relationship_candidate_created.emit(
		int(candidate["character_id"]),
		linked_character_id
	)

	return candidate


func pick_random_name(
	gender: String
) -> String:
	var names_value = name_config.get(
		gender,
		[]
	)

	if typeof(names_value) != TYPE_ARRAY:
		return ""

	var names: Array = names_value

	if names.is_empty():
		return ""

	return str(
		names[
			rng.randi_range(
				0,
				names.size() - 1
			)
		]
	)


func generate_education_and_career(
	candidate: Dictionary
) -> void:
	var age := CharacterManager.get_character_age(
		candidate
	)

	if age < UNIVERSITY_START_AGE:
		return

	var university_track_chance := float(
		generation_config.get(
			"university_track_chance",
			0.70
		)
	)

	var uses_university_track := (
		rng.randf() < university_track_chance
	)

	if uses_university_track:
		apply_university_track(
			candidate,
			age
		)
	else:
		apply_non_university_track(
			candidate
		)

	if String(
		candidate.get(
			"education_status",
			""
		)
	) == "studying":
		return

	assign_initial_job(
		candidate
	)


func apply_non_university_track(
	candidate: Dictionary
) -> void:
	candidate["school_id"] = int(
		generation_config.get(
			"public_high_school_id",
			3001
		)
	)

	candidate["major_id"] = null
	candidate["education_status"] = "graduated"
	candidate["graduation_date"] = (
		CharacterManager.get_date_for_character_age(
			candidate,
			18
		)
	)


func apply_university_track(
	candidate: Dictionary,
	age: int
) -> void:
	var university_id := int(
		generation_config.get(
			"public_university_id",
			4001
		)
	)

	candidate["school_id"] = university_id
	candidate["education_start_date"] = (
		CharacterManager.get_date_for_character_age(
			candidate,
			UNIVERSITY_START_AGE
		)
	)

	if age < MAJOR_SELECTION_AGE:
		candidate["education_status"] = "studying"
		return

	var eligible_majors := get_eligible_majors(
		candidate
	)

	if eligible_majors.is_empty():
		eligible_majors = get_fallback_majors()

	if eligible_majors.is_empty():
		apply_non_university_track(
			candidate
		)
		return

	var selected_major: Dictionary = (
		eligible_majors[
			rng.randi_range(
				0,
				eligible_majors.size() - 1
			)
		]
	)

	var major_id := int(
		selected_major.get(
			"major_id",
			0
		)
	)

	var duration_years := int(
		selected_major.get(
			"duration_years",
			0
		)
	)

	candidate["major_id"] = major_id

	candidate["major_selection_date"] = (
		CharacterManager.get_date_for_character_age(
			candidate,
			MAJOR_SELECTION_AGE
		)
	)

	var graduation_age := (
		UNIVERSITY_START_AGE
		+ duration_years
	)

	candidate["expected_graduation_date"] = (
		CharacterManager.get_date_for_character_age(
			candidate,
			graduation_age
		)
	)

	if age < graduation_age:
		candidate["education_status"] = "studying"
		return

	candidate["education_status"] = "graduated"
	candidate["graduation_date"] = (
		candidate["expected_graduation_date"]
	)


func get_eligible_majors(
	candidate: Dictionary
) -> Array:
	var eligible: Array = []

	for major_value in CharacterManager.majors:
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

		var required_stats_value = major.get(
			"required_stats",
			{}
		)

		if typeof(required_stats_value) != TYPE_DICTIONARY:
			continue

		if not CharacterManager.character_meets_required_stats(
			candidate,
			required_stats_value
		):
			continue

		eligible.append(
			major
		)

	return eligible


func get_fallback_majors() -> Array:
	var fallback: Array = []

	for major_value in CharacterManager.majors:
		if typeof(major_value) != TYPE_DICTIONARY:
			continue

		var major: Dictionary = major_value

		if bool(
			major.get(
				"is_fallback",
				false
			)
		):
			fallback.append(
				major
			)

	return fallback


func assign_initial_job(
	candidate: Dictionary
) -> void:
	var unemployment_chance := float(
		generation_config.get(
			"unemployment_chance",
			0.02
		)
	)

	if rng.randf() < unemployment_chance:
		candidate["unemployment_start_date"] = (
			TimeManager.get_iso_date_string()
		)
		return

	var eligible_jobs := get_eligible_jobs_for_candidate(
		candidate
	)

	if eligible_jobs.is_empty():
		candidate["unemployment_start_date"] = (
			TimeManager.get_iso_date_string()
		)
		return

	var selected_job: Dictionary = (
		eligible_jobs[
			rng.randi_range(
				0,
				eligible_jobs.size() - 1
			)
		]
	)

	var job_id := int(
		selected_job.get(
			"job_id",
			0
		)
	)

	var matching_companies := CareerManager.get_companies_for_job(
		job_id
	)

	if matching_companies.is_empty():
		candidate["unemployment_start_date"] = (
			TimeManager.get_iso_date_string()
		)
		return

	var selected_company: Dictionary = (
		matching_companies[
			rng.randi_range(
				0,
				matching_companies.size() - 1
			)
		]
	)

	candidate["job_id"] = job_id
	candidate["company_id"] = String(
		selected_company.get(
			"company_id",
			""
		)
	)
	candidate["salary"] = int(
		selected_job.get(
			"base_salary",
			0
		)
	)


func get_eligible_jobs_for_candidate(
	candidate: Dictionary
) -> Array:
	var eligible: Array = []

	var major_id_value = candidate.get(
		"major_id",
		null
	)

	for job_value in CharacterManager.jobs:
		if typeof(job_value) != TYPE_DICTIONARY:
			continue

		var job: Dictionary = job_value
		var required_major_id = job.get(
			"required_major_id",
			null
		)

		if major_id_value == null:
			if required_major_id != null:
				continue
		else:
			if required_major_id == null:
				continue

			if int(required_major_id) != int(major_id_value):
				continue

		var required_stats_value = job.get(
			"required_stats",
			{}
		)

		if typeof(required_stats_value) != TYPE_DICTIONARY:
			continue

		if not CharacterManager.character_meets_required_stats(
			candidate,
			required_stats_value
		):
			continue

		eligible.append(
			job
		)

	return eligible


func make_candidate_family_member(
	candidate_id: int,
	partner_id: int
) -> bool:
	var candidate := CharacterManager.get_character_by_id(
		candidate_id
	)

	var partner := CharacterManager.get_character_by_id(
		partner_id
	)

	if candidate.is_empty() or partner.is_empty():
		return false

	if String(
		candidate.get(
			"character_type",
			""
		)
	) != "relationship_npc":
		return false

	if int(
		candidate.get(
			"linked_character_id",
			0
		)
	) != partner_id:
		return false

	if candidate.get(
		"partner_id",
		null
	) != null:
		return false

	if partner.get(
		"partner_id",
		null
	) != null:
		return false

	candidate["is_player_family"] = true
	candidate["relationship_status"] = "married"
	candidate["partner_id"] = partner_id
	candidate["linked_character_id"] = null

	partner["partner_id"] = candidate_id

	relationship_candidate_ids.erase(
		candidate_id
	)

	return true


func can_receive_new_relationship_event(
	character: Dictionary
) -> bool:
	return is_character_relationship_eligible(
		character
	)


func can_have_biological_child(
	carrier: Dictionary
) -> bool:
	if carrier.is_empty():
		return false

	if not bool(
		carrier.get(
			"is_alive",
			true
		)
	):
		return false

	if String(
		carrier.get(
			"gender",
			""
		)
	) != "female":
		return false

	var age := CharacterManager.get_character_age(
		carrier
	)

	return (
		age >= 18
		and age <= int(
			generation_config.get(
				"maximum_female_fertility_age",
				49
			)
		)
	)


func can_adopt(
	partner_one: Dictionary,
	partner_two: Dictionary
) -> bool:
	if partner_one.is_empty() or partner_two.is_empty():
		return false

	if not bool(
		partner_one.get(
			"is_alive",
			true
		)
	):
		return false

	if not bool(
		partner_two.get(
			"is_alive",
			true
		)
	):
		return false

	if partner_one.get(
		"partner_id",
		null
	) != partner_two.get(
		"character_id",
		null
	):
		return false

	if partner_two.get(
		"partner_id",
		null
	) != partner_one.get(
		"character_id",
		null
	):
		return false

	var gender_one := String(
		partner_one.get(
			"gender",
			""
		)
	)

	var gender_two := String(
		partner_two.get(
			"gender",
			""
		)
	)

	if gender_one != gender_two:
		return false

	var maximum_relationship_age := int(
		generation_config.get(
			"maximum_relationship_age",
			54
		)
	)

	var age_one := CharacterManager.get_character_age(
		partner_one
	)

	var age_two := CharacterManager.get_character_age(
		partner_two
	)

	return (
		age_one >= 18
		and age_one <= maximum_relationship_age
		and age_two >= 18
		and age_two <= maximum_relationship_age
	)
