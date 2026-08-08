extends Node


signal worker_pool_changed
signal worker_npcs_generated(count: int)
signal worker_npc_retired(npc_id: String)


const NPC_DATA_PATH := "res://Resources/Json/npc.json"

const AGE_FILTER_ALL := "all"
const AGE_FILTER_YOUNG_ADULT := "young_adult"
const AGE_FILTER_ADULT := "adult"
const AGE_FILTER_ELDER := "elder"

const VALID_AGE_FILTERS: Array[String] = [
	AGE_FILTER_ALL,
	AGE_FILTER_YOUNG_ADULT,
	AGE_FILTER_ADULT,
	AGE_FILTER_ELDER
]

const DAYS_IN_MONTH: Array[int] = [
	31, 28, 31, 30, 31, 30,
	31, 31, 30, 31, 30, 31
]


var worker_npcs: Array = []

var generation_config: Dictionary = {}
var name_config: Dictionary = {}
var portrait_config: Dictionary = {}

var next_worker_npc_number: int = 1
var months_until_next_generation: int = 1
var last_processed_month_key: int = -1

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()

	load_npc_generation_data()

	if not TimeManager.date_changed.is_connected(
		_on_date_changed
	):
		TimeManager.date_changed.connect(
			_on_date_changed
		)

	if not GameManager.new_game_started.is_connected(
		_on_new_game_started
	):
		GameManager.new_game_started.connect(
			_on_new_game_started
		)

	print(
		"Worker NPCs loaded: ",
		worker_npcs.size()
	)


func load_npc_generation_data() -> bool:
	generation_config = {}
	name_config = {}
	portrait_config = {}

	if not FileAccess.file_exists(
		NPC_DATA_PATH
	):
		push_error(
			"NPC file could not be found: "
			+ NPC_DATA_PATH
		)
		return false

	var file: FileAccess = FileAccess.open(
		NPC_DATA_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"NPC file could not be opened: "
			+ NPC_DATA_PATH
		)
		return false

	var parsed_value = JSON.parse_string(
		file.get_as_text()
	)

	if typeof(parsed_value) != TYPE_DICTIONARY:
		push_error(
			"NPC file root must be a Dictionary."
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

	var portraits_value = root.get(
		"portraits",
		{}
	)

	if typeof(generation_value) != TYPE_DICTIONARY:
		push_error(
			"NPC generation config is invalid."
		)
		return false

	if typeof(names_value) != TYPE_DICTIONARY:
		push_error(
			"NPC name config is invalid."
		)
		return false

	if typeof(portraits_value) != TYPE_DICTIONARY:
		push_error(
			"NPC portrait config is invalid."
		)
		return false

	generation_config = generation_value
	name_config = names_value
	portrait_config = portraits_value

	return _validate_generation_config()


func _validate_generation_config() -> bool:
	var min_age: int = int(
		generation_config.get(
			"minimum_entry_age",
			24
		)
	)

	var max_age: int = int(
		generation_config.get(
			"maximum_entry_age",
			50
		)
	)

	var retirement_age: int = int(
		generation_config.get(
			"retirement_age",
			65
		)
	)

	if min_age < 0:
		push_error(
			"NPC minimum entry age cannot be negative."
		)
		return false

	if max_age < min_age:
		push_error(
			"NPC maximum entry age cannot be below minimum entry age."
		)
		return false

	if retirement_age <= max_age:
		push_error(
			"NPC retirement age must be above maximum entry age."
		)
		return false

	return true


func _on_new_game_started(
	_starting_character: Dictionary
) -> void:
	reset_worker_npcs_for_new_game()


func reset_worker_npcs_for_new_game() -> void:
	worker_npcs.clear()
	next_worker_npc_number = 1

	last_processed_month_key = (
		TimeManager.current_year * 100
		+ TimeManager.current_month
	)

	var initial_min: int = int(
		generation_config.get(
			"initial_pool_min",
			8
		)
	)

	var initial_max: int = int(
		generation_config.get(
			"initial_pool_max",
			12
		)
	)

	var initial_count: int = _random_int_inclusive(
		initial_min,
		initial_max
	)

	generate_worker_npcs(
		initial_count
	)

	months_until_next_generation = (
		_roll_next_generation_interval()
	)

	print(
		"Worker NPC pool reset.",
		" | Initial: ",
		worker_npcs.size(),
		" | Next generation in months: ",
		months_until_next_generation
	)


func _on_date_changed(
	_date_text: String
) -> void:
	_process_retirements()

	if TimeManager.current_day != 1:
		return

	var current_month_key: int = (
		TimeManager.current_year * 100
		+ TimeManager.current_month
	)

	if current_month_key == last_processed_month_key:
		return

	last_processed_month_key = current_month_key

	months_until_next_generation -= 1

	if months_until_next_generation > 0:
		return

	var generation_min: int = int(
		generation_config.get(
			"generation_count_min",
			1
		)
	)

	var generation_max: int = int(
		generation_config.get(
			"generation_count_max",
			3
		)
	)

	var generation_count: int = _random_int_inclusive(
		generation_min,
		generation_max
	)

	generate_worker_npcs(
		generation_count
	)

	months_until_next_generation = (
		_roll_next_generation_interval()
	)


func _roll_next_generation_interval() -> int:
	var interval_min: int = int(
		generation_config.get(
			"generation_interval_months_min",
			1
		)
	)

	var interval_max: int = int(
		generation_config.get(
			"generation_interval_months_max",
			3
		)
	)

	return _random_int_inclusive(
		interval_min,
		interval_max
	)


func _random_int_inclusive(
	min_value: int,
	max_value: int
) -> int:
	if max_value <= min_value:
		return min_value

	return rng.randi_range(
		min_value,
		max_value
	)


func generate_worker_npcs(
	count: int
) -> Array:
	var generated: Array = []

	if count <= 0:
		return generated

	for _index in range(count):
		var worker: Dictionary = (
			_create_worker_npc()
		)

		if worker.is_empty():
			continue

		worker_npcs.append(
			worker
		)

		generated.append(
			worker
		)

	if not generated.is_empty():
		worker_npcs_generated.emit(
			generated.size()
		)

		worker_pool_changed.emit()

		print(
			"Worker NPCs generated: ",
			generated.size(),
			" | Total: ",
			worker_npcs.size()
		)

	return generated


func _create_worker_npc() -> Dictionary:
	var gender: String = (
		"male"
		if rng.randi_range(0, 1) == 0
		else "female"
	)

	var first_name: String = (
		_pick_random_name(
			gender
		)
	)

	var last_name: String = (
		_pick_random_last_name()
	)

	if first_name.is_empty():
		return {}

	if last_name.is_empty():
		return {}

	var minimum_age: int = int(
		generation_config.get(
			"minimum_entry_age",
			24
		)
	)

	var maximum_age: int = int(
		generation_config.get(
			"maximum_entry_age",
			50
		)
	)

	var age: int = _random_int_inclusive(
		minimum_age,
		maximum_age
	)

	var npc_id: String = _generate_worker_npc_id()

	return {
		"id": npc_id,
		"first_name": first_name,
		"last_name": last_name,
		"gender": gender,
		"birth_date": _generate_birth_date_for_age(
			age
		),
		"portrait_path": _pick_random_portrait(
			gender
		),
		"stats": _generate_stats(),
		"is_retired": false
	}


func _generate_worker_npc_id() -> String:
	var npc_id: String = "npc_%06d" % (
		next_worker_npc_number
	)

	next_worker_npc_number += 1

	return npc_id


func _pick_random_name(
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

	var index: int = rng.randi_range(
		0,
		names.size() - 1
	)

	return str(
		names[index]
	)


func _pick_random_last_name() -> String:
	var names_value = name_config.get(
		"last_names",
		[]
	)

	if typeof(names_value) != TYPE_ARRAY:
		return ""

	var names: Array = names_value

	if names.is_empty():
		return ""

	var index: int = rng.randi_range(
		0,
		names.size() - 1
	)

	return str(
		names[index]
	)


func _pick_random_portrait(
	gender: String
) -> String:
	var portraits_value = portrait_config.get(
		gender,
		[]
	)

	if typeof(portraits_value) != TYPE_ARRAY:
		return ""

	var portraits: Array = portraits_value

	if portraits.is_empty():
		return ""

	var index: int = rng.randi_range(
		0,
		portraits.size() - 1
	)

	return str(
		portraits[index]
	)


func _generate_stats() -> Dictionary:
	var stat_min: int = int(
		generation_config.get(
			"stat_min",
			0
		)
	)

	var stat_max: int = int(
		generation_config.get(
			"stat_max",
			100
		)
	)

	return {
		"health": _random_int_inclusive(
			stat_min,
			stat_max
		),
		"logic": _random_int_inclusive(
			stat_min,
			stat_max
		),
		"discipline": _random_int_inclusive(
			stat_min,
			stat_max
		),
		"creativity": _random_int_inclusive(
			stat_min,
			stat_max
		),
		"social": _random_int_inclusive(
			stat_min,
			stat_max
		),
		"confidence": _random_int_inclusive(
			stat_min,
			stat_max
		),
		"attractiveness": _random_int_inclusive(
			stat_min,
			stat_max
		),
		"happiness": _random_int_inclusive(
			stat_min,
			stat_max
		)
	}


func _generate_birth_date_for_age(
	target_age: int
) -> String:
	var birth_month: int = rng.randi_range(
		1,
		12
	)

	var max_day: int = DAYS_IN_MONTH[
		birth_month - 1
	]

	var birth_day: int = rng.randi_range(
		1,
		max_day
	)

	var birth_year: int = (
		TimeManager.current_year
		- target_age
	)

	var birthday_has_happened: bool = (
		birth_month < TimeManager.current_month
		or (
			birth_month == TimeManager.current_month
			and birth_day <= TimeManager.current_day
		)
	)

	if not birthday_has_happened:
		birth_year -= 1

	return "%04d-%02d-%02d" % [
		birth_year,
		birth_month,
		birth_day
	]


func get_worker_npc_by_id(
	npc_id: String
) -> Dictionary:
	if npc_id.is_empty():
		return {}

	for worker_value in worker_npcs:
		if typeof(worker_value) != TYPE_DICTIONARY:
			continue

		var worker: Dictionary = worker_value

		if str(
			worker.get(
				"id",
				""
			)
		) == npc_id:
			return worker

	return {}


func get_worker_age(
	worker: Dictionary
) -> int:
	var birth_date: String = str(
		worker.get(
			"birth_date",
			""
		)
	)

	if birth_date.is_empty():
		return -1

	var parts: PackedStringArray = (
		birth_date.split("-")
	)

	if parts.size() != 3:
		return -1

	if not parts[0].is_valid_int():
		return -1

	if not parts[1].is_valid_int():
		return -1

	if not parts[2].is_valid_int():
		return -1

	var birth_year: int = int(
		parts[0]
	)

	var birth_month: int = int(
		parts[1]
	)

	var birth_day: int = int(
		parts[2]
	)

	var age: int = (
		TimeManager.current_year
		- birth_year
	)

	var birthday_has_happened: bool = (
		TimeManager.current_month > birth_month
		or (
			TimeManager.current_month == birth_month
			and TimeManager.current_day >= birth_day
		)
	)

	if not birthday_has_happened:
		age -= 1

	return age


func get_worker_life_stage(
	worker: Dictionary
) -> String:
	var age: int = get_worker_age(
		worker
	)

	if age < 0:
		return ""

	if age <= 34:
		return AGE_FILTER_YOUNG_ADULT

	if age <= 59:
		return AGE_FILTER_ADULT

	return AGE_FILTER_ELDER


func _matches_age_filter(
	worker: Dictionary,
	age_filter: String
) -> bool:
	var normalized_filter: String = (
		age_filter.strip_edges().to_lower()
	)

	if normalized_filter.is_empty():
		normalized_filter = AGE_FILTER_ALL

	if not VALID_AGE_FILTERS.has(
		normalized_filter
	):
		return false

	if normalized_filter == AGE_FILTER_ALL:
		return true

	return get_worker_life_stage(
		worker
	) == normalized_filter


func is_worker_npc_assigned(
	npc_id: String
) -> bool:
	if npc_id.is_empty():
		return false

	for business_value in BusinessManager.businesses:
		if typeof(business_value) != TYPE_DICTIONARY:
			continue

		var business: Dictionary = business_value

		var slots_value = business.get(
			"slots",
			[]
		)

		if typeof(slots_value) != TYPE_ARRAY:
			continue

		var slots: Array = slots_value

		for slot_value in slots:
			if typeof(slot_value) != TYPE_DICTIONARY:
				continue

			var slot: Dictionary = slot_value

			if str(
				slot.get(
					"assigned_npc_id",
					""
				)
			) == npc_id:
				return true

	return false


func is_worker_available(
	worker: Dictionary
) -> bool:
	if worker.is_empty():
		return false

	if bool(
		worker.get(
			"is_retired",
			false
		)
	):
		return false

	var retirement_age: int = int(
		generation_config.get(
			"retirement_age",
			65
		)
	)

	var age: int = get_worker_age(
		worker
	)

	if age < 0:
		return false

	if age >= retirement_age:
		return false

	var npc_id: String = str(
		worker.get(
			"id",
			""
		)
	)

	return not is_worker_npc_assigned(
		npc_id
	)


func get_available_worker_npcs(
	age_filter: String = AGE_FILTER_ALL
) -> Array:
	var result: Array = []

	for worker_value in worker_npcs:
		if typeof(worker_value) != TYPE_DICTIONARY:
			continue

		var worker: Dictionary = worker_value

		if not is_worker_available(
			worker
		):
			continue

		if not _matches_age_filter(
			worker,
			age_filter
		):
			continue

		result.append(
			worker.duplicate(true)
		)

	return result


func get_candidates_for_slot(
	business_type_id: String,
	slot_id: String,
	age_filter: String = AGE_FILTER_ALL
) -> Array:
	var slot_definition: Dictionary = (
		BusinessManager.get_slot_definition(
			business_type_id,
			slot_id
		)
	)

	if slot_definition.is_empty():
		return []

	var available_workers: Array = (
		get_available_worker_npcs(
			age_filter
		)
	)

	var candidates: Array = []

	for worker_value in available_workers:
		if typeof(worker_value) != TYPE_DICTIONARY:
			continue

		var worker: Dictionary = worker_value

		var performance: Dictionary = (
			BusinessManager.get_worker_slot_performance(
				worker,
				slot_definition
			)
		)

		if performance.is_empty():
			continue

		var score: float = float(
			performance.get(
				"score",
				0.0
			)
		)

		var income: int = int(
			BusinessManager.calculate_worker_slot_gross(
				worker,
				slot_definition
			)
		)

		candidates.append(
			{
				"npc_id": str(
					worker.get(
						"id",
						""
					)
				),
				"first_name": str(
					worker.get(
						"first_name",
						""
					)
				),
				"last_name": str(
					worker.get(
						"last_name",
						""
					)
				),
				"gender": str(
					worker.get(
						"gender",
						""
					)
				),
				"age": get_worker_age(
					worker
				),
				"life_stage": get_worker_life_stage(
					worker
				),
				"portrait_path": str(
					worker.get(
						"portrait_path",
						""
					)
				),
				"stats": worker.get(
					"stats",
					{}
				),
				"performance_score": score,
				"performance_tier": str(
					performance.get(
						"tier",
						""
					)
				),
				"performance_multiplier": float(
					performance.get(
						"multiplier",
						0.0
					)
				),
				"business_income": income
			}
		)

	candidates.sort_custom(
		_sort_candidates_descending
	)

	return candidates


func _sort_candidates_descending(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var a_score: float = float(
		a.get(
			"performance_score",
			0.0
		)
	)

	var b_score: float = float(
		b.get(
			"performance_score",
			0.0
		)
	)

	if not is_equal_approx(
		a_score,
		b_score
	):
		return a_score > b_score

	return str(
		a.get(
			"npc_id",
			""
		)
	) < str(
		b.get(
			"npc_id",
			""
		)
	)


func _process_retirements() -> void:
	var retirement_age: int = int(
		generation_config.get(
			"retirement_age",
			65
		)
	)

	var changed: bool = false

	for worker_value in worker_npcs:
		if typeof(worker_value) != TYPE_DICTIONARY:
			continue

		var worker: Dictionary = worker_value

		if bool(
			worker.get(
				"is_retired",
				false
			)
		):
			continue

		var age: int = get_worker_age(
			worker
		)

		if age < retirement_age:
			continue

		worker["is_retired"] = true
		changed = true

		worker_npc_retired.emit(
			str(
				worker.get(
					"id",
					""
				)
			)
		)

	if changed:
		worker_pool_changed.emit()
