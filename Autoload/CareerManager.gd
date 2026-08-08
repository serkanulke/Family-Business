extends Node


signal job_offer_requested(
	character_id: int,
	job_id: int,
	company_id: String,
	salary: int
)

const COMPANY_DATA_PATH := "res://Resources/Json/Companies.json"
const MIN_COMPANIES_PER_JOB := 5

const UNEMPLOYED_OFFER_COOLDOWN_DAYS := 7

const UNEMPLOYED_CHANCE_FIRST_30_DAYS := 0.005
const UNEMPLOYED_CHANCE_31_TO_60_DAYS := 0.01
const UNEMPLOYED_CHANCE_61_TO_90_DAYS := 0.015
const UNEMPLOYED_CHANCE_91_TO_180_DAYS := 0.02
const UNEMPLOYED_CHANCE_OVER_180_DAYS := 0.03

const EMPLOYED_MONTHLY_OFFER_CHANCE := 0.03

var companies: Array = []
var active_job_offers: Dictionary = {}

func _ready() -> void:
	load_company_data()
	validate_company_job_links()

	TimeManager.date_changed.connect(
		_on_date_changed
	)


func load_company_data() -> void:
	companies = CharacterManager.load_json_array(
		COMPANY_DATA_PATH,
		"companies"
	)

	normalize_company_data()

	print("Companies loaded: ", companies.size())


func normalize_company_data() -> void:
	for company in companies:
		if typeof(company) != TYPE_DICTIONARY:
			continue

		company["company_id"] = String(
			company.get("company_id", "")
		)

		company["company_name"] = String(
			company.get("company_name", "")
		)

		company["logo_path"] = String(
			company.get("logo_path", "")
		)

		var normalized_jobs: Array = []

		for job_id in company.get("jobs", []):
			normalized_jobs.append(int(job_id))

		company["jobs"] = normalized_jobs


func get_company_by_id(company_id: String) -> Dictionary:
	for company in companies:
		if company.get("company_id", "") == company_id:
			return company

	return {}


func get_job_by_id(job_id: int) -> Dictionary:
	for job in CharacterManager.jobs:
		if int(job.get("job_id", -1)) == job_id:
			return job

	return {}


func get_companies_for_job(job_id: int) -> Array:
	var matching_companies: Array = []

	for company in companies:
		var company_jobs: Array = company.get("jobs", [])

		if job_id in company_jobs:
			matching_companies.append(company)

	return matching_companies


func company_offers_job(
	company_id: String,
	job_id: int
) -> bool:
	var company := get_company_by_id(company_id)

	if company.is_empty():
		return false

	return job_id in company.get("jobs", [])


func validate_company_job_links() -> void:
	var job_company_counts: Dictionary = {}
	var invalid_job_ids: Array = []

	for job in CharacterManager.jobs:
		var job_id := int(
			job.get("job_id", -1)
		)

		if job_id >= 0:
			job_company_counts[job_id] = 0

	for company in companies:
		for job_id_value in company.get("jobs", []):
			var job_id := int(job_id_value)

			if not job_company_counts.has(job_id):
				if job_id not in invalid_job_ids:
					invalid_job_ids.append(job_id)

				continue

			job_company_counts[job_id] += 1

	var jobs_below_minimum: Array = []

	for job_id in job_company_counts:
		var company_count := int(
			job_company_counts[job_id]
		)

		if company_count < MIN_COMPANIES_PER_JOB:
			jobs_below_minimum.append({
				"job_id": job_id,
				"company_count": company_count
			})

	if invalid_job_ids.is_empty():
		print(
			"Company validation: no invalid job IDs."
		)
	else:
		push_error(
			"Companies.json contains invalid job IDs: %s"
			% [invalid_job_ids]
		)

	if jobs_below_minimum.is_empty():
		print(
			"Company validation: every job has at least %d companies."
			% MIN_COMPANIES_PER_JOB
		)
	else:
		push_error(
			"Jobs below minimum company count: %s"
			% [jobs_below_minimum]
		)

func is_character_eligible_for_external_jobs(
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

	if bool(character.get("is_retired", false)):
		return false

	if character.get("education_status", "") != "graduated":
		return false

	return true


func character_meets_job_requirements(
	character: Dictionary,
	job: Dictionary
) -> bool:
	if not is_character_eligible_for_external_jobs(character):
		return false

	var required_major_id = job.get(
		"required_major_id",
		null
	)

	if required_major_id != null:
		var character_major_id = character.get(
			"major_id",
			null
		)

		if character_major_id == null:
			return false

		if int(character_major_id) != int(required_major_id):
			return false

	var required_stats: Dictionary = job.get(
		"required_stats",
		{}
	)

	return CharacterManager.character_meets_required_stats(
		character,
		required_stats
	)


func get_eligible_external_jobs(
	character: Dictionary
) -> Array:
	var eligible_jobs: Array = []

	if not is_character_eligible_for_external_jobs(character):
		return eligible_jobs

	for job in CharacterManager.jobs:
		if character_meets_job_requirements(
			character,
			job
		):
			eligible_jobs.append(job)

	return eligible_jobs


func get_eligible_external_offers(
	character: Dictionary
) -> Array:
	var offers: Array = []

	var eligible_jobs := get_eligible_external_jobs(
		character
	)

	for job in eligible_jobs:
		var job_id := int(
			job.get("job_id", -1)
		)

		if job_id < 0:
			continue

		var matching_companies := get_companies_for_job(
			job_id
		)

		for company in matching_companies:
			offers.append({
				"job_id": job_id,
				"company_id": company.get(
					"company_id",
					""
				),
				"salary": int(
					job.get(
						"base_salary",
						0
					)
				)
			})

	return offers

func get_unemployed_offer_pool(
	character: Dictionary
) -> Array:
	if not is_character_eligible_for_external_jobs(character):
		return []

	if character.get("job_id", null) != null:
		return []

	return get_eligible_external_offers(character)


func get_employed_advancement_offer_pool(
	character: Dictionary
) -> Array:
	var offers: Array = []

	if not is_character_eligible_for_external_jobs(character):
		return offers

	var current_job_id = character.get(
		"job_id",
		null
	)

	if current_job_id == null:
		return offers

	var current_salary := int(
		character.get(
			"salary",
			0
		)
	)

	var eligible_offers := get_eligible_external_offers(
		character
	)

	for offer in eligible_offers:
		var offered_job_id := int(
			offer.get(
				"job_id",
				-1
			)
		)

		var offered_salary := int(
			offer.get(
				"salary",
				0
			)
		)

		if offered_job_id == int(current_job_id):
			continue

		if offered_salary <= current_salary:
			continue

		offers.append(offer)

	return offers

func iso_date_to_game_day_index(
	date_text: String
) -> int:
	var parts := date_text.split("-")

	if parts.size() != 3:
		return -1

	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])

	if month < 1 or month > 12:
		return -1

	var result := year * 365

	for month_index in range(month - 1):
		result += TimeManager.DAYS_IN_MONTH[
			month_index
		]

	result += day - 1

	return result


func get_current_game_day_index() -> int:
	return iso_date_to_game_day_index(
		TimeManager.get_iso_date_string()
	)


func get_days_since_iso_date(
	date_text: String
) -> int:
	var start_day := iso_date_to_game_day_index(
		date_text
	)

	if start_day < 0:
		return 0

	return maxi(
		get_current_game_day_index() - start_day,
		0
	)

func ensure_unemployment_start_date(
	character: Dictionary
) -> void:
	if character.get("job_id", null) != null:
		character["unemployment_start_date"] = null
		return

	if character.get(
		"unemployment_start_date",
		null
	) != null:
		return

	var graduation_date = character.get(
		"graduation_date",
		null
	)

	if graduation_date != null:
		character["unemployment_start_date"] = String(
			graduation_date
		)
	else:
		character["unemployment_start_date"] = (
			TimeManager.get_iso_date_string()
		)

func get_unemployed_daily_offer_chance(
	character: Dictionary
) -> float:
	ensure_unemployment_start_date(character)

	var start_date = character.get(
		"unemployment_start_date",
		null
	)

	if start_date == null:
		return 0.0

	var unemployed_days := get_days_since_iso_date(
		String(start_date)
	)

	if unemployed_days <= 30:
		return UNEMPLOYED_CHANCE_FIRST_30_DAYS

	if unemployed_days <= 60:
		return UNEMPLOYED_CHANCE_31_TO_60_DAYS

	if unemployed_days <= 90:
		return UNEMPLOYED_CHANCE_61_TO_90_DAYS

	if unemployed_days <= 180:
		return UNEMPLOYED_CHANCE_91_TO_180_DAYS

	return UNEMPLOYED_CHANCE_OVER_180_DAYS

func is_character_assigned_to_family_business(
	character_id: int
) -> bool:
	var business_manager := get_node_or_null(
		"/root/BusinessManager"
	)

	if business_manager == null:
		return false

	if not business_manager.has_method(
		"is_character_assigned"
	):
		return false

	return bool(
		business_manager.call(
			"is_character_assigned",
			character_id
		)
	)

func game_day_index_to_iso_date(
	day_index: int
) -> String:
	if day_index < 0:
		return ""

	var year := int(
		floor(
			float(day_index) / 365.0
		)
	)

	var remaining_days := (
		day_index - year * 365
	)

	var month := 1

	while (
		month <= 12
		and remaining_days
		>= TimeManager.DAYS_IN_MONTH[
			month - 1
		]
	):
		remaining_days -= (
			TimeManager.DAYS_IN_MONTH[
				month - 1
			]
		)

		month += 1

	var day := remaining_days + 1

	return "%04d-%02d-%02d" % [
		year,
		month,
		day
	]


func add_game_days_to_iso_date(
	date_text: String,
	days_to_add: int
) -> String:
	var starting_index := (
		iso_date_to_game_day_index(
			date_text
		)
	)

	if starting_index < 0:
		return ""

	return game_day_index_to_iso_date(
		starting_index + days_to_add
	)

func is_unemployed_offer_on_cooldown(
	character: Dictionary
) -> bool:
	var cooldown_until = character.get(
		"job_offer_cooldown_until",
		null
	)

	if cooldown_until == null:
		return false

	var cooldown_day := (
		iso_date_to_game_day_index(
			String(cooldown_until)
		)
	)

	if cooldown_day < 0:
		character[
			"job_offer_cooldown_until"
		] = null

		return false

	if get_current_game_day_index() <= cooldown_day:
		return true

	character[
		"job_offer_cooldown_until"
	] = null

	return false


func start_unemployed_offer_cooldown(
	character: Dictionary
) -> void:
	var current_date := (
		TimeManager.get_iso_date_string()
	)

	character[
		"job_offer_cooldown_until"
	] = add_game_days_to_iso_date(
		current_date,
		UNEMPLOYED_OFFER_COOLDOWN_DAYS
	)

func select_random_offer_from_pool(
	offers: Array
) -> Dictionary:
	if offers.is_empty():
		return {}

	var offers_by_job: Dictionary = {}

	for offer_value in offers:
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue

		var offer: Dictionary = offer_value

		var job_id := int(
			offer.get(
				"job_id",
				-1
			)
		)

		if job_id < 0:
			continue

		if not offers_by_job.has(job_id):
			offers_by_job[job_id] = []

		offers_by_job[job_id].append(
			offer
		)

	if offers_by_job.is_empty():
		return {}

	var eligible_job_ids: Array = (
		offers_by_job.keys()
	)

	var selected_job_id = (
		eligible_job_ids.pick_random()
	)

	var company_offers: Array = (
		offers_by_job[
			selected_job_id
		]
	)

	if company_offers.is_empty():
		return {}

	var selected_offer_value = (
		company_offers.pick_random()
	)

	if typeof(selected_offer_value) != TYPE_DICTIONARY:
		return {}

	return selected_offer_value

func request_job_offer(
	character: Dictionary,
	offer: Dictionary
) -> void:
	if offer.is_empty():
		return

	var character_id := int(
		character.get(
			"character_id",
			0
		)
	)

	var job_id := int(
		offer.get(
			"job_id",
			-1
		)
	)

	var company_id := String(
		offer.get(
			"company_id",
			""
		)
	)

	var salary := int(
		offer.get(
			"salary",
			0
		)
	)

	if (
		character_id <= 0
		or job_id < 0
		or company_id.is_empty()
	):
		return

	if active_job_offers.has(
		character_id
	):
		return

	active_job_offers[
		character_id
	] = {
		"job_id": job_id,
		"company_id": company_id,
		"salary": salary
	}

	job_offer_requested.emit(
		character_id,
		job_id,
		company_id,
		salary
	)

	var job := get_job_by_id(job_id)
	var company := get_company_by_id(
		company_id
	)

	print(
		"JOB OFFER | Character: ",
		character_id,
		" | Job: ",
		job.get("job_name", job_id),
		" | Company: ",
		company.get(
			"company_name",
			company_id
		),
		" | Salary: ",
		salary
	)

func check_unemployed_character_offer(
	character: Dictionary
) -> void:
	if character.get("job_id", null) != null:
		return

	var character_id := int(
		character.get(
			"character_id",
			0
		)
	)

	if active_job_offers.has(
		character_id
	):
		return

	if is_character_assigned_to_family_business(
		character_id
	):
		return

	if is_unemployed_offer_on_cooldown(
		character
	):
		return

	var offer_pool := (
		get_unemployed_offer_pool(
			character
		)
	)

	if offer_pool.is_empty():
		return

	var daily_chance := (
		get_unemployed_daily_offer_chance(
			character
		)
	)

	if randf() > daily_chance:
		return

	var selected_offer := (
		select_random_offer_from_pool(
			offer_pool
		)
	)

	if selected_offer.is_empty():
		return

	start_unemployed_offer_cooldown(
		character
	)

	request_job_offer(
		character,
		selected_offer
	)

func check_employed_character_offer(
	character: Dictionary
) -> void:
	if character.get("job_id", null) == null:
		return

	var character_id := int(
		character.get(
			"character_id",
			0
		)
	)
	
	if active_job_offers.has(
		character_id
	):
		return

	if is_character_assigned_to_family_business(
		character_id
	):
		return

	var offer_pool := (
		get_employed_advancement_offer_pool(
			character
		)
	)

	if offer_pool.is_empty():
		return

	if randf() > EMPLOYED_MONTHLY_OFFER_CHANCE:
		return

	var selected_offer := (
		select_random_offer_from_pool(
			offer_pool
		)
	)

	if selected_offer.is_empty():
		return

	request_job_offer(
		character,
		selected_offer
	)

func _on_date_changed(
	_date_text: String
) -> void:
	for character_value in CharacterManager.characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = (
			character_value
		)

		if not is_character_eligible_for_external_jobs(
			character
		):
			continue

		if character.get(
			"job_id",
			null
		) == null:
			check_unemployed_character_offer(
				character
			)

			continue

		if TimeManager.current_day != 1:
			continue

		check_employed_character_offer(
			character
		)

func get_character_by_id(
	character_id: int
) -> Dictionary:
	for character_value in CharacterManager.characters:
		if typeof(character_value) != TYPE_DICTIONARY:
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

func get_active_job_offer(
	character_id: int
) -> Dictionary:
	if not active_job_offers.has(
		character_id
	):
		return {}

	var offer_value = active_job_offers[
		character_id
	]

	if typeof(offer_value) != TYPE_DICTIONARY:
		return {}

	return offer_value

func is_active_job_offer_valid(
	character: Dictionary,
	offer: Dictionary
) -> bool:
	if character.is_empty():
		return false

	if offer.is_empty():
		return false

	if not is_character_eligible_for_external_jobs(
		character
	):
		return false

	var character_id := int(
		character.get(
			"character_id",
			0
		)
	)

	if is_character_assigned_to_family_business(
		character_id
	):
		return false

	var job_id := int(
		offer.get(
			"job_id",
			-1
		)
	)

	var company_id := String(
		offer.get(
			"company_id",
			""
		)
	)

	var job := get_job_by_id(job_id)

	if job.is_empty():
		return false

	if not company_offers_job(
		company_id,
		job_id
	):
		return false

	if not character_meets_job_requirements(
		character,
		job
	):
		return false

	var canonical_salary := int(
		job.get(
			"base_salary",
			0
		)
	)

	if int(
		offer.get(
			"salary",
			-1
		)
	) != canonical_salary:
		return false

	var current_job_id = character.get(
		"job_id",
		null
	)

	if current_job_id != null:
		var current_salary := int(
			character.get(
				"salary",
				0
			)
		)

		if job_id == int(current_job_id):
			return false

		if canonical_salary <= current_salary:
			return false

	return true

func accept_job_offer(
	character_id: int
) -> bool:
	var character := get_character_by_id(
		character_id
	)

	if character.is_empty():
		return false

	var offer := get_active_job_offer(
		character_id
	)

	if not is_active_job_offer_valid(
		character,
		offer
	):
		active_job_offers.erase(
			character_id
		)

		return false

	var job_id := int(
		offer.get(
			"job_id",
			-1
		)
	)

	var company_id := String(
		offer.get(
			"company_id",
			""
		)
	)

	var salary := int(
		offer.get(
			"salary",
			0
		)
	)

	character["job_id"] = job_id
	character["company_id"] = company_id
	character["salary"] = salary

	character[
		"unemployment_start_date"
	] = null

	character[
		"job_offer_cooldown_until"
	] = null

	active_job_offers.erase(
		character_id
	)

	print(
		"JOB OFFER ACCEPTED | Character: ",
		character_id,
		" | Job: ",
		job_id,
		" | Company: ",
		company_id,
		" | Salary: ",
		salary
	)

	return true

func reject_job_offer(
	character_id: int
) -> bool:
	if not active_job_offers.has(
		character_id
	):
		return false

	active_job_offers.erase(
		character_id
	)

	print(
		"JOB OFFER REJECTED | Character: ",
		character_id
	)

	return true

func assign_company_for_existing_job(
	character: Dictionary
) -> bool:
	if character.is_empty():
		return false

	var job_id_value = character.get(
		"job_id",
		null
	)

	if job_id_value == null:
		return false

	var job_id := int(
		job_id_value
	)

	var matching_companies := (
		get_companies_for_job(
			job_id
		)
	)

	if matching_companies.is_empty():
		push_error(
			"No company found for starting job: %d"
			% job_id
		)

		return false

	var company_value = (
		matching_companies.pick_random()
	)

	if typeof(company_value) != TYPE_DICTIONARY:
		return false

	var company: Dictionary = company_value

	var company_id := String(
		company.get(
			"company_id",
			""
		)
	)

	if company_id.is_empty():
		return false

	character["company_id"] = company_id

	print(
		"Starting company assigned: ",
		company.get(
			"company_name",
			company_id
		),
		" | Character: ",
		character.get(
			"character_id",
			0
		),
		" | Job: ",
		job_id
	)

	return true
