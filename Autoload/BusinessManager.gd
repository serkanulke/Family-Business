extends Node


signal family_business_slot_changed(
	business_instance_id: String,
	slot_id: String,
	character_id: int
)


signal family_business_created(
	business_instance_id: String,
	business_type_id: String,
	plot_id: String,
	purchase_cost: int
)

signal family_business_upgraded(
	business_instance_id: String,
	new_level: int,
	upgrade_cost: int
)


const BUSINESS_DATA_PATH := "res://Resources/Json/Business.json"
const BUSINESS_TYPES_DATA_PATH := "res://Resources/Json/BusinessTypes.json"


var businesses: Array = []
var business_types: Array = []
var performance_model: Dictionary = {}
var next_business_instance_number: int = 1


func _ready() -> void:
	load_business_data()
	load_business_type_data()


func load_business_data() -> void:
	businesses = CharacterManager.load_json_array(
		BUSINESS_DATA_PATH,
		"businesses"
	)

	_initialize_next_business_instance_number()

	print(
		"Family businesses loaded: ",
		businesses.size()
	)


func load_business_type_data() -> void:
	business_types = []
	performance_model = {}

	if not FileAccess.file_exists(BUSINESS_TYPES_DATA_PATH):
		push_error(
			"BusinessTypes file could not be found: "
			+ BUSINESS_TYPES_DATA_PATH
		)
		return

	var file := FileAccess.open(
		BUSINESS_TYPES_DATA_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"BusinessTypes file could not be opened: "
			+ BUSINESS_TYPES_DATA_PATH
		)
		return

	var json_text := file.get_as_text()
	var json := JSON.new()
	var parse_result := json.parse(json_text)

	if parse_result != OK:
		push_error(
			"BusinessTypes JSON error at line %d: %s"
			% [
				json.get_error_line(),
				json.get_error_message()
			]
		)
		return

	var data = json.data

	if typeof(data) != TYPE_DICTIONARY:
		push_error(
			"BusinessTypes JSON root must be a Dictionary."
		)
		return

	var business_types_value = data.get(
		"business_types",
		[]
	)

	if typeof(business_types_value) != TYPE_ARRAY:
		push_error(
			"BusinessTypes 'business_types' must be an Array."
		)
		return

	var performance_model_value = data.get(
		"performance_model",
		{}
	)

	if typeof(performance_model_value) != TYPE_DICTIONARY:
		push_error(
			"BusinessTypes 'performance_model' must be a Dictionary."
		)
		return

	business_types = business_types_value
	performance_model = performance_model_value

	print(
		"Business types loaded: ",
		business_types.size()
	)


func get_business_type_by_id(
	business_type_id: String
) -> Dictionary:
	for business_type_value in business_types:
		if typeof(business_type_value) != TYPE_DICTIONARY:
			continue

		var business_type: Dictionary = business_type_value

		if str(
			business_type.get(
				"business_type_id",
				""
			)
		) == business_type_id:
			return business_type

	return {}


func get_level_definition(
	business_type_id: String,
	level: int
) -> Dictionary:
	var business_type := get_business_type_by_id(
		business_type_id
	)

	if business_type.is_empty():
		return {}

	for level_value in business_type.get(
		"levels",
		[]
	):
		if typeof(level_value) != TYPE_DICTIONARY:
			continue

		var level_definition: Dictionary = level_value

		if int(
			level_definition.get(
				"level",
				0
			)
		) == level:
			return level_definition

	return {}


func get_slot_definition(
	business_type_id: String,
	slot_id: String
) -> Dictionary:
	var business_type := get_business_type_by_id(
		business_type_id
	)

	if business_type.is_empty():
		return {}

	for slot_value in business_type.get(
		"slot_definitions",
		[]
	):
		if typeof(slot_value) != TYPE_DICTIONARY:
			continue

		var slot_definition: Dictionary = slot_value

		if str(
			slot_definition.get(
				"slot_id",
				""
			)
		) == slot_id:
			return slot_definition

	return {}


func get_level_slot_definitions(
	business_type_id: String,
	level: int
) -> Array:
	var result: Array = []

	var level_definition := get_level_definition(
		business_type_id,
		level
	)

	if level_definition.is_empty():
		return result

	for slot_id_value in level_definition.get(
		"slot_ids",
		[]
	):
		var slot_id := str(slot_id_value)

		var slot_definition := get_slot_definition(
			business_type_id,
			slot_id
		)

		if slot_definition.is_empty():
			continue

		result.append(slot_definition)

	return result


func get_level_max_gross(
	business_type_id: String,
	level: int
) -> int:
	var total := 0

	for slot_definition_value in get_level_slot_definitions(
		business_type_id,
		level
	):
		if typeof(slot_definition_value) != TYPE_DICTIONARY:
			continue

		var slot_definition: Dictionary = slot_definition_value

		total += int(
			slot_definition.get(
				"base_gross_contribution",
				0
			)
		)

	return total


func get_level_fixed_monthly_expense(
	business_type_id: String,
	level: int
) -> int:
	var level_definition := get_level_definition(
		business_type_id,
		level
	)

	if level_definition.is_empty():
		return 0

	return int(
		level_definition.get(
			"fixed_monthly_expense",
			0
		)
	)


func worker_meets_slot_requirements(
	worker: Dictionary,
	slot_definition: Dictionary
) -> bool:
	if worker.is_empty():
		return false

	if slot_definition.is_empty():
		return false

	var required_stats_value = slot_definition.get(
		"required_stats",
		{}
	)

	if typeof(required_stats_value) != TYPE_DICTIONARY:
		return false

	var required_stats: Dictionary = required_stats_value

	return CharacterManager.character_meets_required_stats(
		worker,
		required_stats
	)


func get_worker_performance_score(
	worker: Dictionary,
	slot_definition: Dictionary
) -> float:
	if not worker_meets_slot_requirements(
		worker,
		slot_definition
	):
		return -1.0

	var required_stats_value = slot_definition.get(
		"required_stats",
		{}
	)

	if typeof(required_stats_value) != TYPE_DICTIONARY:
		return -1.0

	var required_stats: Dictionary = required_stats_value

	if required_stats.is_empty():
		return -1.0

	var total := 0.0
	var stat_count := 0

	for stat_name_value in required_stats.keys():
		var stat_name := str(stat_name_value)

		total += float(
			worker.get(
				stat_name,
				0
			)
		)

		stat_count += 1

	if stat_count <= 0:
		return -1.0

	return total / float(stat_count)


func get_performance_tier_for_score(
	score: float
) -> Dictionary:
	var tiers_value = performance_model.get(
		"tiers",
		[]
	)

	if typeof(tiers_value) != TYPE_ARRAY:
		return {}

	for tier_value in tiers_value:
		if typeof(tier_value) != TYPE_DICTIONARY:
			continue

		var tier: Dictionary = tier_value

		var min_score := float(
			tier.get(
				"min_score",
				0
			)
		)

		var max_score := float(
			tier.get(
				"max_score",
				0
			)
		)

		if score < min_score:
			continue

		if score > max_score:
			continue

		return tier

	return {}


func get_worker_slot_performance(
	worker: Dictionary,
	slot_definition: Dictionary
) -> Dictionary:
	var score := get_worker_performance_score(
		worker,
		slot_definition
	)

	if score < 0.0:
		return {}

	var tier := get_performance_tier_for_score(
		score
	)

	if tier.is_empty():
		return {}

	return {
		"score": score,
		"tier": str(
			tier.get(
				"tier",
				""
			)
		),
		"multiplier": float(
			tier.get(
				"multiplier",
				0.0
			)
		)
	}


func calculate_worker_slot_gross(
	worker: Dictionary,
	slot_definition: Dictionary
) -> int:
	var performance := get_worker_slot_performance(
		worker,
		slot_definition
	)

	if performance.is_empty():
		return 0

	var base_gross := int(
		slot_definition.get(
			"base_gross_contribution",
			0
		)
	)

	var multiplier := float(
		performance.get(
			"multiplier",
			0.0
		)
	)

	return int(
		round(
			float(base_gross)
			* multiplier
		)
	)


func get_business_visual_path(
	business_type_id: String,
	visual_variant_id: String,
	level: int
) -> String:
	var business_type := get_business_type_by_id(
		business_type_id
	)

	if business_type.is_empty():
		return ""

	var placeholder_path := str(
		business_type.get(
			"placeholder_visual_path",
			""
		)
	)

	if visual_variant_id.is_empty():
		return placeholder_path

	var building_folder := str(
		business_type.get(
			"building_folder",
			""
		)
	)

	if building_folder.is_empty():
		return placeholder_path

	var candidate_path := (
		building_folder
		+ "/"
		+ visual_variant_id
		+ "/level_%02d.png"
		% level
	)

	if ResourceLoader.exists(candidate_path):
		return candidate_path

	return placeholder_path


func _initialize_next_business_instance_number() -> void:
	next_business_instance_number = 1

	for business_value in businesses:
		if typeof(business_value) != TYPE_DICTIONARY:
			continue

		var business: Dictionary = business_value
		var instance_id := str(
			business.get(
				"business_instance_id",
				""
			)
		)

		if not instance_id.begins_with("business_"):
			continue

		var number_text := instance_id.trim_prefix(
			"business_"
		)

		if not number_text.is_valid_int():
			continue

		next_business_instance_number = maxi(
			next_business_instance_number,
			int(number_text) + 1
		)


func _generate_business_instance_id() -> String:
	var instance_id := "business_%04d" % (
		next_business_instance_number
	)

	next_business_instance_number += 1

	return instance_id


func get_business_on_plot(
	plot_id: String
) -> Dictionary:
	if plot_id.is_empty():
		return {}

	for business_value in businesses:
		if typeof(business_value) != TYPE_DICTIONARY:
			continue

		var business: Dictionary = business_value

		if str(
			business.get(
				"plot_id",
				""
			)
		) == plot_id:
			return business

	return {}


func is_plot_occupied_by_business(
	plot_id: String
) -> bool:
	return not get_business_on_plot(
		plot_id
	).is_empty()


func get_business_acquisition_cost(
	business_type_id: String,
	is_new_construction: bool
) -> int:
	var level_one := get_level_definition(
		business_type_id,
		1
	)

	if level_one.is_empty():
		return 0

	var base_cost := int(
		level_one.get(
			"cost",
			0
		)
	)

	if base_cost <= 0:
		return 0

	if is_new_construction:
		return EconomyManager.get_new_construction_cost(
			base_cost
		)

	return base_cost


func _select_visual_variant(
	business_type: Dictionary,
	requested_variant_id: String
) -> String:
	var variants_value = business_type.get(
		"visual_variants",
		[]
	)

	if typeof(variants_value) != TYPE_ARRAY:
		return ""

	var variants: Array = variants_value

	if not requested_variant_id.is_empty():
		if variants.has(requested_variant_id):
			return requested_variant_id

		return ""

	if variants.is_empty():
		return ""

	return str(
		variants[
			randi_range(
				0,
				variants.size() - 1
			)
		]
	)


func _create_runtime_slots_for_level(
	business_type_id: String,
	level: int
) -> Array:
	var runtime_slots: Array = []

	var level_definition := get_level_definition(
		business_type_id,
		level
	)

	if level_definition.is_empty():
		return runtime_slots

	for slot_id_value in level_definition.get(
		"slot_ids",
		[]
	):
		runtime_slots.append(
			{
				"slot_id": str(slot_id_value),
				"assigned_character_id": null
			}
		)

	return runtime_slots


func create_business_instance(
	business_type_id: String,
	plot_id: String,
	is_new_construction: bool,
	requested_visual_variant_id: String = ""
) -> Dictionary:
	if plot_id.is_empty():
		return {}

	if is_plot_occupied_by_business(
		plot_id
	):
		return {}

	var business_type := get_business_type_by_id(
		business_type_id
	)

	if business_type.is_empty():
		return {}

	var level_one := get_level_definition(
		business_type_id,
		1
	)

	if level_one.is_empty():
		return {}

	var purchase_cost := get_business_acquisition_cost(
		business_type_id,
		is_new_construction
	)

	if purchase_cost <= 0:
		return {}

	if not GameManager.can_afford(
		purchase_cost
	):
		return {}

	var visual_variant_id := _select_visual_variant(
		business_type,
		requested_visual_variant_id
	)

	var variants_value = business_type.get(
		"visual_variants",
		[]
	)

	if (
		not requested_visual_variant_id.is_empty()
		and typeof(variants_value) == TYPE_ARRAY
		and not variants_value.has(
			requested_visual_variant_id
		)
	):
		return {}

	var runtime_slots := _create_runtime_slots_for_level(
		business_type_id,
		1
	)

	if runtime_slots.is_empty():
		return {}

	if not GameManager.spend_family_money(
		purchase_cost
	):
		return {}

	var business_instance_id := (
		_generate_business_instance_id()
	)

	var business_instance := {
		"business_instance_id": business_instance_id,
		"business_type_id": business_type_id,
		"visual_variant_id": visual_variant_id,
		"plot_id": plot_id,
		"level": 1,
		"slots": runtime_slots
	}

	businesses.append(
		business_instance
	)

	family_business_created.emit(
		business_instance_id,
		business_type_id,
		plot_id,
		purchase_cost
	)

	print(
		"FAMILY BUSINESS CREATED | ID: ",
		business_instance_id,
		" | Type: ",
		business_type_id,
		" | Plot: ",
		plot_id,
		" | New Construction: ",
		is_new_construction,
		" | Cost: ",
		purchase_cost
	)

	return business_instance


func upgrade_business(
	business_instance_id: String
) -> bool:
	var business := get_business_by_instance_id(
		business_instance_id
	)

	if business.is_empty():
		return false

	var business_type_id := str(
		business.get(
			"business_type_id",
			""
		)
	)

	if business_type_id.is_empty():
		return false

	var business_type := get_business_type_by_id(
		business_type_id
	)

	if business_type.is_empty():
		return false

	var current_level := int(
		business.get(
			"level",
			1
		)
	)

	var max_level := int(
		business_type.get(
			"max_level",
			1
		)
	)

	if current_level >= max_level:
		return false

	var next_level := current_level + 1

	var next_level_definition := get_level_definition(
		business_type_id,
		next_level
	)

	if next_level_definition.is_empty():
		return false

	var upgrade_cost := int(
		next_level_definition.get(
			"cost",
			0
		)
	)

	if upgrade_cost <= 0:
		return false

	if not GameManager.can_afford(
		upgrade_cost
	):
		return false

	var next_slot_ids_value = next_level_definition.get(
		"slot_ids",
		[]
	)

	if typeof(next_slot_ids_value) != TYPE_ARRAY:
		return false

	var current_slots_value = business.get(
		"slots",
		[]
	)

	if typeof(current_slots_value) != TYPE_ARRAY:
		return false

	var current_slots: Array = current_slots_value
	var existing_slot_ids: Array[String] = []

	for slot_value in current_slots:
		if typeof(slot_value) != TYPE_DICTIONARY:
			continue

		var slot: Dictionary = slot_value

		existing_slot_ids.append(
			str(
				slot.get(
					"slot_id",
					""
				)
			)
		)

	if not GameManager.spend_family_money(
		upgrade_cost
	):
		return false

	for slot_id_value in next_slot_ids_value:
		var slot_id := str(slot_id_value)

		if existing_slot_ids.has(
			slot_id
		):
			continue

		current_slots.append(
			{
				"slot_id": slot_id,
				"assigned_character_id": null
			}
		)

	business["slots"] = current_slots
	business["level"] = next_level

	family_business_upgraded.emit(
		business_instance_id,
		next_level,
		upgrade_cost
	)

	print(
		"FAMILY BUSINESS UPGRADED | ID: ",
		business_instance_id,
		" | Level: ",
		next_level,
		" | Cost: ",
		upgrade_cost
	)

	return true


func get_business_slot_gross(
	business_instance_id: String,
	slot_id: String
) -> int:
	var business := get_business_by_instance_id(
		business_instance_id
	)

	if business.is_empty():
		return 0

	var business_type_id := str(
		business.get(
			"business_type_id",
			""
		)
	)

	if business_type_id.is_empty():
		return 0

	var slot := get_slot(
		business_instance_id,
		slot_id
	)

	if slot.is_empty():
		return 0

	var assigned_character_id = slot.get(
		"assigned_character_id",
		null
	)

	if assigned_character_id == null:
		return 0

	var character := CareerManager.get_character_by_id(
		int(assigned_character_id)
	)

	if character.is_empty():
		return 0

	if not bool(
		character.get(
			"is_alive",
			true
		)
	):
		return 0

	if bool(
		character.get(
			"is_retired",
			false
		)
	):
		return 0

	var slot_definition := get_slot_definition(
		business_type_id,
		slot_id
	)

	if slot_definition.is_empty():
		return 0

	return calculate_worker_slot_gross(
		character,
		slot_definition
	)


func get_business_gross_income(
	business_instance_id: String
) -> int:
	var business := get_business_by_instance_id(
		business_instance_id
	)

	if business.is_empty():
		return 0

	var total := 0

	for slot_value in business.get(
		"slots",
		[]
	):
		if typeof(slot_value) != TYPE_DICTIONARY:
			continue

		var slot: Dictionary = slot_value
		var slot_id := str(
			slot.get(
				"slot_id",
				""
			)
		)

		if slot_id.is_empty():
			continue

		total += get_business_slot_gross(
			business_instance_id,
			slot_id
		)

	return total


func get_business_monthly_breakdown(
	business_instance_id: String
) -> Dictionary:
	var business := get_business_by_instance_id(
		business_instance_id
	)

	if business.is_empty():
		return {}

	var business_type_id := str(
		business.get(
			"business_type_id",
			""
		)
	)

	var level := int(
		business.get(
			"level",
			1
		)
	)

	if business_type_id.is_empty():
		return {}

	var gross_income := get_business_gross_income(
		business_instance_id
	)

	var fixed_expense := get_level_fixed_monthly_expense(
		business_type_id,
		level
	)

	return {
		"business_instance_id": business_instance_id,
		"business_type_id": business_type_id,
		"level": level,
		"gross_income": gross_income,
		"fixed_expense": fixed_expense,
		"net_profit": gross_income - fixed_expense
	}


func get_all_business_monthly_breakdowns() -> Array:
	var result: Array = []

	for business_value in businesses:
		if typeof(business_value) != TYPE_DICTIONARY:
			continue

		var business: Dictionary = business_value
		var business_instance_id := str(
			business.get(
				"business_instance_id",
				""
			)
		)

		if business_instance_id.is_empty():
			continue

		var breakdown := get_business_monthly_breakdown(
			business_instance_id
		)

		if breakdown.is_empty():
			continue

		result.append(
			breakdown
		)

	return result


func get_business_by_instance_id(
	business_instance_id: String
) -> Dictionary:
	for business_value in businesses:
		if typeof(business_value) != TYPE_DICTIONARY:
			continue

		var business: Dictionary = business_value

		if str(
			business.get(
				"business_instance_id",
				""
			)
		) == business_instance_id:
			return business

	return {}


func get_slot(
	business_instance_id: String,
	slot_id: String
) -> Dictionary:
	var business := get_business_by_instance_id(
		business_instance_id
	)

	if business.is_empty():
		return {}

	for slot_value in business.get(
		"slots",
		[]
	):
		if typeof(slot_value) != TYPE_DICTIONARY:
			continue

		var slot: Dictionary = slot_value

		if str(
			slot.get(
				"slot_id",
				""
			)
		) == slot_id:
			return slot

	return {}


func get_character_assignment(
	character_id: int
) -> Dictionary:
	for business_value in businesses:
		if typeof(business_value) != TYPE_DICTIONARY:
			continue

		var business: Dictionary = business_value

		var business_instance_id := str(
			business.get(
				"business_instance_id",
				""
			)
		)

		for slot_value in business.get(
			"slots",
			[]
		):
			if typeof(slot_value) != TYPE_DICTIONARY:
				continue

			var slot: Dictionary = slot_value

			var assigned_character_id = slot.get(
				"assigned_character_id",
				null
			)

			if assigned_character_id == null:
				continue

			if int(assigned_character_id) != character_id:
				continue

			return {
				"business_instance_id": business_instance_id,
				"slot_id": str(
					slot.get(
						"slot_id",
						""
					)
				)
			}

	return {}


func is_character_assigned(
	character_id: int
) -> bool:
	return not get_character_assignment(
		character_id
	).is_empty()


func can_assign_character(
	character_id: int
) -> bool:
	var character := CareerManager.get_character_by_id(
		character_id
	)

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

	if bool(
		character.get(
			"is_retired",
			false
		)
	):
		return false

	if is_character_assigned(
		character_id
	):
		return false

	return true


func assign_character_to_slot(
	business_instance_id: String,
	slot_id: String,
	character_id: int
) -> bool:
	var slot := get_slot(
		business_instance_id,
		slot_id
	)

	if slot.is_empty():
		return false

	if slot.get(
		"assigned_character_id",
		null
	) != null:
		return false

	if not can_assign_character(
		character_id
	):
		return false

	var character := CareerManager.get_character_by_id(
		character_id
	)

	if character.is_empty():
		return false

	var business := get_business_by_instance_id(
		business_instance_id
	)

	if not business.is_empty():
		var business_type_id := str(
			business.get(
				"business_type_id",
				""
			)
		)

		if not business_type_id.is_empty():
			var slot_definition := get_slot_definition(
				business_type_id,
				slot_id
			)

			if slot_definition.is_empty():
				return false

			if not worker_meets_slot_requirements(
				character,
				slot_definition
			):
				return false

	# Family-business assignment immediately ends
	# any existing external employment.
	character["job_id"] = null
	character["company_id"] = null
	character["salary"] = 0

	# A pending external offer cannot remain active after
	# the character enters a family-business slot.
	CareerManager.active_job_offers.erase(
		character_id
	)

	character[
		"unemployment_start_date"
	] = null

	character[
		"job_offer_cooldown_until"
	] = null

	slot["assigned_character_id"] = (
		character_id
	)

	family_business_slot_changed.emit(
		business_instance_id,
		slot_id,
		character_id
	)

	print(
		"FAMILY BUSINESS ASSIGNED | Character: ",
		character_id,
		" | Business: ",
		business_instance_id,
		" | Slot: ",
		slot_id
	)

	return true


func remove_character_from_slot(
	business_instance_id: String,
	slot_id: String
) -> bool:
	var slot := get_slot(
		business_instance_id,
		slot_id
	)

	if slot.is_empty():
		return false

	var character_id_value = slot.get(
		"assigned_character_id",
		null
	)

	if character_id_value == null:
		return false

	var character_id := int(
		character_id_value
	)

	slot["assigned_character_id"] = null

	var character := CareerManager.get_character_by_id(
		character_id
	)

	if not character.is_empty():
		character["job_id"] = null
		character["company_id"] = null
		character["salary"] = 0

		character[
			"unemployment_start_date"
		] = TimeManager.get_iso_date_string()

		character[
			"job_offer_cooldown_until"
		] = null

	family_business_slot_changed.emit(
		business_instance_id,
		slot_id,
		0
	)

	print(
		"FAMILY BUSINESS REMOVED | Character: ",
		character_id,
		" | Business: ",
		business_instance_id,
		" | Slot: ",
		slot_id,
		" | External offers enabled again"
	)

	return true


func remove_character_from_any_slot(
	character_id: int
) -> bool:
	var assignment := get_character_assignment(
		character_id
	)

	if assignment.is_empty():
		return false

	return remove_character_from_slot(
		str(
			assignment.get(
				"business_instance_id",
				""
			)
		),
		str(
			assignment.get(
				"slot_id",
				""
			)
		)
	)
