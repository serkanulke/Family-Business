extends Node

signal relationship_candidate_created(
	character_id: int,
	linked_character_id: int
)


signal family_relationship_changed()

const RELATIONSHIP_NPC_DATA_PATH := \
	"res://Resources/Json/relationship_npc.json"

const UNIVERSITY_START_AGE := 18
const MAJOR_SELECTION_AGE := 21
const DIVORCE_RELATIONSHIP_COOLDOWN_YEARS := 1

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

	var gender := _pick_candidate_gender(
		linked_character
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
		"portrait_variant_id": "",
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
		"relationship_cooldown_until": null,
		"parent_ids": [],
		"is_adopted": false,
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

	CharacterManager.ensure_character_portrait(
		candidate
	)

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

	var cooldown_until_value = candidate.get(
		"relationship_cooldown_until",
		null
	)

	if cooldown_until_value != null:
		if not GameManager.allow_ex_spouse_remarriage:
			return false

		if not _is_relationship_cooldown_finished(
			candidate
		):
			return false

	if not is_marriage_allowed_by_settings(
		candidate,
		partner
	):
		return false

	candidate["is_player_family"] = true
	candidate["relationship_status"] = "married"
	candidate["relationship_cooldown_until"] = null
	candidate["partner_id"] = partner_id
	candidate["linked_character_id"] = null

	partner["partner_id"] = candidate_id

	relationship_candidate_ids.erase(
		candidate_id
	)

	family_relationship_changed.emit()

	return true


func can_make_candidate_family_member(candidate_id: int, partner_id: int) -> bool:
	var candidate := CharacterManager.get_character_by_id(candidate_id)
	var partner := CharacterManager.get_character_by_id(partner_id)
	if candidate.is_empty() or partner.is_empty():
		return false
	if String(candidate.get("character_type", "")) != "relationship_npc" or int(candidate.get("linked_character_id", 0)) != partner_id:
		return false
	if candidate.get("partner_id", null) != null or partner.get("partner_id", null) != null:
		return false
	if candidate.get("relationship_cooldown_until", null) != null:
		if not GameManager.allow_ex_spouse_remarriage or not _is_relationship_cooldown_finished(candidate):
			return false
	return is_marriage_allowed_by_settings(candidate, partner)


func divorce_characters(
	first_character_id: int,
	second_character_id: int
) -> bool:
	var first_character := CharacterManager.get_character_by_id(
		first_character_id
	)

	var second_character := CharacterManager.get_character_by_id(
		second_character_id
	)

	if not are_married_partners(
		first_character,
		second_character
	):
		return false

	first_character["partner_id"] = null
	second_character["partner_id"] = null

	_handle_character_after_divorce(
		first_character
	)

	_handle_character_after_divorce(
		second_character
	)

	family_relationship_changed.emit()

	return true


func _handle_character_after_divorce(
	character: Dictionary
) -> void:
	if String(
		character.get(
			"character_type",
			""
		)
	) != "relationship_npc":
		return

	var character_id := int(
		character.get(
			"character_id",
			0
		)
	)

	_remove_departing_spouse_from_family_business(
		character_id
	)
	HouseManager.remove_character_from_house(
		character_id,
		"family_exit"
	)

	character["is_player_family"] = false
	character["relationship_status"] = "divorced"
	character["linked_character_id"] = null
	character["relationship_cooldown_until"] = (
		_get_date_years_later(
			TimeManager.get_iso_date_string(),
			DIVORCE_RELATIONSHIP_COOLDOWN_YEARS
		)
	)

	relationship_candidate_ids.erase(
		character_id
	)


func _remove_departing_spouse_from_family_business(
	character_id: int
) -> void:
	if character_id <= 0:
		return

	var assignment := BusinessManager.get_character_assignment(
		character_id
	)

	if assignment.is_empty():
		return

	var business_instance_id := String(
		assignment.get(
			"business_instance_id",
			""
		)
	)

	var slot_id := String(
		assignment.get(
			"slot_id",
			""
		)
	)

	if business_instance_id.is_empty() or slot_id.is_empty():
		return

	BusinessManager.remove_character_from_slot(
		business_instance_id,
		slot_id
	)


func get_returning_relationship_candidates_for(
	linked_character_id: int
) -> Array:
	var linked_character := CharacterManager.get_character_by_id(
		linked_character_id
	)

	if not is_character_relationship_eligible(
		linked_character
	):
		return []

	var candidates: Array = []

	for character_value in CharacterManager.characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value

		if can_return_as_relationship_candidate(
			character,
			linked_character
		):
			candidates.append(
				character
			)

	return candidates


func can_return_as_relationship_candidate(
	candidate: Dictionary,
	linked_character: Dictionary
) -> bool:
	if not GameManager.allow_ex_spouse_remarriage:
		return false

	if candidate.is_empty() or linked_character.is_empty():
		return false

	if String(
		candidate.get(
			"character_type",
			""
		)
	) != "relationship_npc":
		return false

	if String(
		candidate.get(
			"relationship_status",
			""
		)
	) != "divorced":
		return false

	if bool(
		candidate.get(
			"is_player_family",
			false
		)
	):
		return false

	if not bool(
		candidate.get(
			"is_alive",
			true
		)
	):
		return false

	if candidate.get(
		"partner_id",
		null
	) != null:
		return false

	if candidate.get(
		"linked_character_id",
		null
	) != null:
		return false

	if not is_character_relationship_eligible(
		linked_character
	):
		return false

	var candidate_id := int(
		candidate.get(
			"character_id",
			0
		)
	)

	var linked_character_id := int(
		linked_character.get(
			"character_id",
			0
		)
	)

	if candidate_id <= 0 or linked_character_id <= 0:
		return false

	if candidate_id == linked_character_id:
		return false

	if not _is_relationship_cooldown_finished(
		candidate
	):
		return false

	var candidate_age := CharacterManager.get_character_age(
		candidate
	)

	var linked_age := CharacterManager.get_character_age(
		linked_character
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

	if candidate_age < minimum_age or candidate_age > maximum_age:
		return false

	var maximum_age_gap := int(
		generation_config.get(
			"maximum_age_gap",
			14
		)
	)

	if absi(
		candidate_age - linked_age
	) > maximum_age_gap:
		return false

	return is_marriage_allowed_by_settings(
		candidate,
		linked_character
	)


func prepare_returning_relationship_candidate(
	candidate_id: int,
	linked_character_id: int
) -> bool:
	var candidate := CharacterManager.get_character_by_id(
		candidate_id
	)

	var linked_character := CharacterManager.get_character_by_id(
		linked_character_id
	)

	if not can_return_as_relationship_candidate(
		candidate,
		linked_character
	):
		return false

	candidate["linked_character_id"] = linked_character_id
	candidate["relationship_status"] = "candidate"

	if candidate_id not in relationship_candidate_ids:
		relationship_candidate_ids.append(
			candidate_id
		)

	relationship_candidate_created.emit(
		candidate_id,
		linked_character_id
	)

	return true


func is_marriage_allowed_by_settings(
	first_character: Dictionary,
	second_character: Dictionary
) -> bool:
	if first_character.is_empty() or second_character.is_empty():
		return false

	var first_gender := String(
		first_character.get(
			"gender",
			""
		)
	)

	var second_gender := String(
		second_character.get(
			"gender",
			""
		)
	)

	if first_gender.is_empty() or second_gender.is_empty():
		return false

	if (
		first_gender == second_gender
		and not GameManager.allow_same_sex_marriage
	):
		return false

	return true


func _pick_candidate_gender(
	linked_character: Dictionary
) -> String:
	var linked_gender := String(
		linked_character.get(
			"gender",
			""
		)
	)

	if not GameManager.allow_same_sex_marriage:
		if linked_gender == "female":
			return "male"

		if linked_gender == "male":
			return "female"

	return (
		"male"
		if rng.randi_range(0, 1) == 0
		else "female"
	)


func _is_relationship_cooldown_finished(
	character: Dictionary
) -> bool:
	var cooldown_until_value = character.get(
		"relationship_cooldown_until",
		null
	)

	if cooldown_until_value == null:
		return true

	var cooldown_until := String(
		cooldown_until_value
	)

	if cooldown_until.is_empty():
		return true

	var current_key := _iso_date_to_sort_key(
		TimeManager.get_iso_date_string()
	)

	var cooldown_key := _iso_date_to_sort_key(
		cooldown_until
	)

	if current_key < 0 or cooldown_key < 0:
		return false

	return current_key >= cooldown_key


func _iso_date_to_sort_key(
	iso_date: String
) -> int:
	var date_parts := iso_date.split(
		"-"
	)

	if date_parts.size() != 3:
		return -1

	var year := int(date_parts[0])
	var month := int(date_parts[1])
	var day := int(date_parts[2])

	if year <= 0 or month < 1 or month > 12 or day < 1 or day > 31:
		return -1

	return year * 10000 + month * 100 + day


func _get_date_years_later(
	iso_date: String,
	years_to_add: int
) -> String:
	var date_parts := iso_date.split(
		"-"
	)

	if date_parts.size() != 3:
		return ""

	var year := int(
		date_parts[0]
	) + maxi(
		years_to_add,
		0
	)

	var month := int(
		date_parts[1]
	)

	var day := int(
		date_parts[2]
	)

	return "%04d-%02d-%02d" % [
		year,
		month,
		day
	]


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


func are_married_partners(
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

	var partner_one_id := int(
		partner_one.get(
			"character_id",
			0
		)
	)

	var partner_two_id := int(
		partner_two.get(
			"character_id",
			0
		)
	)

	if partner_one_id <= 0 or partner_two_id <= 0:
		return false

	return (
		partner_one.get(
			"partner_id",
			null
		) == partner_two_id
		and partner_two.get(
			"partner_id",
			null
		) == partner_one_id
	)


func can_use_donor_conception(
	carrier: Dictionary,
	spouse: Dictionary
) -> bool:
	if not are_married_partners(
		carrier,
		spouse
	):
		return false

	if String(
		carrier.get(
			"gender",
			""
		)
	) != "female":
		return false

	if String(
		spouse.get(
			"gender",
			""
		)
	) != "female":
		return false

	return can_have_biological_child(
		carrier
	)


func create_donor_conceived_child(
	first_name: String,
	gender: String,
	carrier_id: int,
	spouse_id: int
) -> Dictionary:
	var carrier := CharacterManager.get_character_by_id(
		carrier_id
	)

	var spouse := CharacterManager.get_character_by_id(
		spouse_id
	)

	if not can_use_donor_conception(
		carrier,
		spouse
	):
		return {}

	var donor_genetics := (
		CharacterManager.generate_random_genetics()
	)

	return CharacterManager.create_donor_conceived_baby_character(
		first_name,
		gender,
		carrier_id,
		spouse_id,
		donor_genetics
	)


func can_adopt(
	partner_one: Dictionary,
	partner_two: Dictionary
) -> bool:
	if not are_married_partners(
		partner_one,
		partner_two
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


func create_adopted_child(
	first_name: String,
	gender: String,
	parent_one_id: int,
	parent_two_id: int
) -> Dictionary:
	var parent_one := CharacterManager.get_character_by_id(
		parent_one_id
	)

	var parent_two := CharacterManager.get_character_by_id(
		parent_two_id
	)

	if not can_adopt(
		parent_one,
		parent_two
	):
		return {}

	return CharacterManager.create_adopted_child_character(
		first_name,
		gender,
		parent_one_id,
		parent_two_id
	)
