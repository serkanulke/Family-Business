extends Node


const COMPANY_DATA_PATH := "res://Resources/Json/Companies.json"
const MIN_COMPANIES_PER_JOB := 5


var companies: Array = []


func _ready() -> void:
	load_company_data()
	validate_company_job_links()


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

	if bool(character.get("is_dead", false)):
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
