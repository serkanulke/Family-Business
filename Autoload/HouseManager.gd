extends Node


signal house_created(
	house_instance_id: String,
	property_id: String,
	purchase_cost: int
)

signal house_state_changed(
	house_instance_id: String,
	reason: String
)

signal house_upgraded(
	house_instance_id: String,
	new_level: int,
	upgrade_cost: int
)

signal unhoused_penalties_applied(
	character_ids: Array,
	processing_date: String
)

const HOUSE_DATA_PATH := "res://Resources/Json/House.json"
const HOUSEHOLD_PERKS_DATA_PATH := "res://Resources/Json/HouseholdPerks.json"
const DEFAULT_HOUSE_DEFINITION_ID := "family_house"
const ROLE_LIFE_STAGES: Array[String] = [
	"young_adult",
	"adult",
	"elder"
]
const UNHOUSED_MONTHLY_HAPPINESS_PENALTY := 2


var house_definitions: Array = []
var household_perk_definitions: Array = []
var houses: Array = []
var next_house_instance_number: int = 1
var last_unhoused_penalty_date: String = ""


func _ready() -> void:
	load_static_data()
	GameManager.new_game_started.connect(_on_new_game_started)
	CharacterManager.character_died.connect(_on_character_died)
	TimeManager.date_changed.connect(_on_date_changed)


func load_static_data() -> void:
	house_definitions = _load_json_array(
		HOUSE_DATA_PATH,
		"house_definitions"
	)
	household_perk_definitions = _load_json_array(
		HOUSEHOLD_PERKS_DATA_PATH,
		"household_perks"
	)


func _load_json_array(path: String, root_key: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("House data file could not be found: " + path)
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("House data file could not be opened: " + path)
		return []
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	if parse_result != OK:
		push_error(
			"House JSON error at line %d: %s"
			% [json.get_error_line(), json.get_error_message()]
		)
		return []
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("House JSON root must be a Dictionary: " + path)
		return []
	var value = json.data.get(root_key, [])
	if typeof(value) != TYPE_ARRAY:
		push_error("House JSON key must be an Array: " + root_key)
		return []
	return value


func get_house_definition(
	house_definition_id: String = DEFAULT_HOUSE_DEFINITION_ID
) -> Dictionary:
	for value in house_definitions:
		if value is Dictionary and str(value.get("house_definition_id", "")) == house_definition_id:
			return value
	return {}


func get_level_definition(
	level: int,
	house_definition_id: String = DEFAULT_HOUSE_DEFINITION_ID
) -> Dictionary:
	var definition := get_house_definition(house_definition_id)
	for value in definition.get("levels", []):
		if value is Dictionary and int(value.get("level", 0)) == level:
			return value
	return {}


func get_role_definitions(
	house_definition_id: String = DEFAULT_HOUSE_DEFINITION_ID
) -> Array:
	var definition := get_house_definition(house_definition_id)
	var value = definition.get("roles", [])
	return value if value is Array else []


func get_role_definition(
	role_id: String,
	house_definition_id: String = DEFAULT_HOUSE_DEFINITION_ID
) -> Dictionary:
	for value in get_role_definitions(house_definition_id):
		if value is Dictionary and str(value.get("role_id", "")) == role_id:
			return value
	return {}


func get_house_by_instance_id(house_instance_id: String) -> Dictionary:
	for value in houses:
		if value is Dictionary and str(value.get("house_instance_id", "")) == house_instance_id:
			return value
	return {}


func get_house_on_property(property_id: String) -> Dictionary:
	if property_id.is_empty():
		return {}
	for value in houses:
		if value is Dictionary and str(value.get("property_id", "")) == property_id:
			return value
	return {}


func is_property_owned(property_id: String) -> bool:
	return not get_house_on_property(property_id).is_empty()


func get_starting_property_id() -> String:
	return str(get_house_definition().get("starting_property_id", ""))


func get_house_capacity(house_instance_id: String) -> int:
	var house := get_house_by_instance_id(house_instance_id)
	if house.is_empty():
		return 0
	return int(get_level_definition(
		int(house.get("level", 1)),
		str(house.get("house_definition_id", DEFAULT_HOUSE_DEFINITION_ID))
	).get("capacity", 0))


func get_house_resident_capacity(house_instance_id: String) -> int:
	var house := get_house_by_instance_id(house_instance_id)
	if house.is_empty():
		return 0
	var house_definition_id := str(
		house.get("house_definition_id", DEFAULT_HOUSE_DEFINITION_ID)
	)
	var role_slot_count := get_role_definitions(house_definition_id).size()
	return maxi(get_house_capacity(house_instance_id) - role_slot_count, 0)


func get_house_resident_count(house_instance_id: String) -> int:
	var house := get_house_by_instance_id(house_instance_id)
	if house.is_empty():
		return 0
	var result: Array[int] = []
	var residents_value = house.get("resident_character_ids", [])
	if residents_value is Array:
		for character_id_value in residents_value:
			var character_id := int(character_id_value)
			if character_id > 0 and not result.has(character_id):
				result.append(character_id)
	return result.size()


func get_house_monthly_expense(house_instance_id: String) -> int:
	var house := get_house_by_instance_id(house_instance_id)
	if house.is_empty():
		return 0
	return int(get_level_definition(
		int(house.get("level", 1)),
		str(house.get("house_definition_id", DEFAULT_HOUSE_DEFINITION_ID))
	).get("fixed_monthly_expense", 0))


func get_total_monthly_expense() -> int:
	var total := 0
	for value in houses:
		if value is Dictionary:
			total += get_house_monthly_expense(str(value.get("house_instance_id", "")))
	return total


func get_house_acquisition_cost(is_new_construction: bool) -> int:
	var base_cost := int(get_level_definition(1).get("ready_made_purchase_price", 0))
	if is_new_construction:
		return EconomyManager.get_new_construction_cost(base_cost)
	return base_cost


func get_house_occupant_ids(house_instance_id: String) -> Array[int]:
	var result: Array[int] = []
	var house := get_house_by_instance_id(house_instance_id)
	if house.is_empty():
		return result
	var roles_value = house.get("role_assignments", {})
	if roles_value is Dictionary:
		for character_id_value in roles_value.values():
			if character_id_value != null:
				var character_id := int(character_id_value)
				if character_id > 0 and not result.has(character_id):
					result.append(character_id)
	var residents_value = house.get("resident_character_ids", [])
	if residents_value is Array:
		for character_id_value in residents_value:
			var character_id := int(character_id_value)
			if character_id > 0 and not result.has(character_id):
				result.append(character_id)
	return result


func get_house_occupancy(house_instance_id: String) -> int:
	return get_house_occupant_ids(house_instance_id).size()


func get_character_assignment(character_id: int) -> Dictionary:
	if character_id <= 0:
		return {}
	for value in houses:
		if not value is Dictionary:
			continue
		var house: Dictionary = value
		var roles_value = house.get("role_assignments", {})
		if roles_value is Dictionary:
			for role_id_value in roles_value.keys():
				var assigned_value = roles_value.get(role_id_value, null)
				if assigned_value != null and int(assigned_value) == character_id:
					return {
						"house_instance_id": str(house.get("house_instance_id", "")),
						"property_id": str(house.get("property_id", "")),
						"assignment_type": "role",
						"role_id": str(role_id_value)
					}
		var residents_value = house.get("resident_character_ids", [])
		if residents_value is Array:
			for resident_value in residents_value:
				if int(resident_value) == character_id:
					return {
						"house_instance_id": str(house.get("house_instance_id", "")),
						"property_id": str(house.get("property_id", "")),
						"assignment_type": "resident",
						"role_id": ""
					}
	return {}


func get_character_house(character_id: int) -> Dictionary:
	var assignment := get_character_assignment(character_id)
	if assignment.is_empty():
		return {}
	return get_house_by_instance_id(str(assignment.get("house_instance_id", "")))


func is_character_unhoused(character_id: int) -> bool:
	var character := CharacterManager.get_character_by_id(character_id)
	return (
		not character.is_empty()
		and bool(character.get("is_alive", true))
		and bool(character.get("is_player_family", false))
		and get_character_assignment(character_id).is_empty()
	)


func get_role_character_id(house_instance_id: String, role_id: String) -> int:
	var house := get_house_by_instance_id(house_instance_id)
	var roles_value = house.get("role_assignments", {})
	if roles_value is Dictionary:
		var value = roles_value.get(role_id, null)
		return 0 if value == null else int(value)
	return 0


func can_character_hold_household_role(character_id: int) -> bool:
	var character := CharacterManager.get_character_by_id(character_id)
	return (
		not character.is_empty()
		and bool(character.get("is_alive", true))
		and bool(character.get("is_player_family", false))
		and ROLE_LIFE_STAGES.has(str(character.get("life_stage", "")))
	)


func assign_character_to_role(
	house_instance_id: String,
	role_id: String,
	character_id: int
) -> bool:
	var house := get_house_by_instance_id(house_instance_id)
	if house.is_empty() or get_role_definition(
		role_id,
		str(house.get("house_definition_id", DEFAULT_HOUSE_DEFINITION_ID))
	).is_empty():
		return false
	if not can_character_hold_household_role(character_id):
		return false
	var candidate_assignment := get_character_assignment(character_id)
	if str(candidate_assignment.get("assignment_type", "")) == "role":
		return (
			str(candidate_assignment.get("house_instance_id", "")) == house_instance_id
			and str(candidate_assignment.get("role_id", "")) == role_id
		)
	var roles: Dictionary = house.get("role_assignments", {})
	var current_value = roles.get(role_id, null)
	var current_character_id := 0 if current_value == null else int(current_value)
	var candidate_already_in_target := (
		str(candidate_assignment.get("house_instance_id", "")) == house_instance_id
	)
	var projected_occupancy := get_house_occupancy(house_instance_id)
	if not candidate_already_in_target:
		projected_occupancy += 1
	if current_character_id > 0 and current_character_id != character_id:
		projected_occupancy -= 1
	if projected_occupancy > get_house_capacity(house_instance_id):
		return false
	var source_house_id := str(candidate_assignment.get("house_instance_id", ""))
	if not candidate_assignment.is_empty():
		_remove_character_assignment_internal(character_id)
	roles = house.get("role_assignments", {})
	roles[role_id] = character_id
	house["role_assignments"] = roles
	if not source_house_id.is_empty() and source_house_id != house_instance_id:
		house_state_changed.emit(source_house_id, "resident_moved")
	house_state_changed.emit(house_instance_id, "role_assignment")
	return true


func assign_character_as_resident(
	house_instance_id: String,
	character_id: int
) -> bool:
	var house := get_house_by_instance_id(house_instance_id)
	var character := CharacterManager.get_character_by_id(character_id)
	if house.is_empty() or character.is_empty():
		return false
	if not bool(character.get("is_alive", true)) or not bool(character.get("is_player_family", false)):
		return false
	var assignment := get_character_assignment(character_id)
	if not assignment.is_empty():
		return (
			str(assignment.get("house_instance_id", "")) == house_instance_id
			and str(assignment.get("assignment_type", "")) == "resident"
		)
	if get_house_resident_count(house_instance_id) >= get_house_resident_capacity(house_instance_id):
		return false
	if get_house_occupancy(house_instance_id) >= get_house_capacity(house_instance_id):
		return false
	var residents: Array = house.get("resident_character_ids", [])
	residents.append(character_id)
	house["resident_character_ids"] = residents
	house_state_changed.emit(house_instance_id, "resident_assignment")
	return true


func remove_character_from_house(character_id: int) -> bool:
	var assignment := get_character_assignment(character_id)
	if assignment.is_empty():
		return false
	var house_instance_id := str(assignment.get("house_instance_id", ""))
	if not _remove_character_assignment_internal(character_id):
		return false
	house_state_changed.emit(house_instance_id, "occupant_removed")
	return true


func _remove_character_assignment_internal(character_id: int) -> bool:
	var assignment := get_character_assignment(character_id)
	if assignment.is_empty():
		return false
	var house := get_house_by_instance_id(str(assignment.get("house_instance_id", "")))
	if house.is_empty():
		return false
	if str(assignment.get("assignment_type", "")) == "role":
		var roles: Dictionary = house.get("role_assignments", {})
		roles[str(assignment.get("role_id", ""))] = null
		house["role_assignments"] = roles
	else:
		var residents: Array = house.get("resident_character_ids", [])
		residents.erase(character_id)
		house["resident_character_ids"] = residents
	return true


func get_role_candidates(house_instance_id: String, role_id: String) -> Array:
	var results: Array = []
	var role_definition := get_role_definition(role_id)
	if role_definition.is_empty():
		return results
	for value in CharacterManager.characters:
		if not value is Dictionary:
			continue
		var character: Dictionary = value
		var character_id := int(character.get("character_id", 0))
		if not can_character_hold_household_role(character_id):
			continue
		var assignment := get_character_assignment(character_id)
		if str(assignment.get("assignment_type", "")) == "role":
			continue
		var candidate := character.duplicate(true)
		candidate["performance_tier"] = get_role_performance_tier(character_id, role_id)
		candidate["performance_score"] = get_role_performance_score(character_id, role_id)
		results.append(candidate)
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("performance_score", 0.0)) > float(b.get("performance_score", 0.0))
	)
	return results


func get_resident_candidates(house_instance_id: String) -> Array:
	var results: Array = []
	if get_house_resident_count(house_instance_id) >= get_house_resident_capacity(house_instance_id):
		return results
	for value in CharacterManager.characters:
		if not value is Dictionary:
			continue
		var character: Dictionary = value
		var character_id := int(character.get("character_id", 0))
		if (
			character_id > 0
			and bool(character.get("is_alive", true))
			and bool(character.get("is_player_family", false))
			and get_character_assignment(character_id).is_empty()
		):
			results.append(character.duplicate(true))
	return results


func get_role_performance_score(character_id: int, role_id: String) -> float:
	var character := CharacterManager.get_character_by_id(character_id)
	var role := get_role_definition(role_id)
	if character.is_empty() or role.is_empty():
		return 0.0
	var required_value = role.get("required_stats", [])
	if not required_value is Array or required_value.is_empty():
		return 0.0
	var total := 0.0
	for stat_name_value in required_value:
		total += float(character.get(str(stat_name_value), 0))
	return total / float(required_value.size())


func get_role_performance_tier(character_id: int, role_id: String) -> String:
	var score := get_role_performance_score(character_id, role_id)
	var model: Dictionary = get_house_definition().get("performance_model", {})
	for value in model.get("tiers", []):
		if not value is Dictionary:
			continue
		if score >= float(value.get("min_score", 0)) and score <= float(value.get("max_score", 100)):
			return str(value.get("tier", "D"))
	return "D"


func is_role_important(house_instance_id: String, role_id: String) -> bool:
	var role := get_role_definition(role_id)
	if role.is_empty():
		return false
	var rule_value = role.get("importance_rule", {})
	if not rule_value is Dictionary:
		return false
	var rule: Dictionary = rule_value
	if bool(rule.get("always_important", false)):
		return true
	var occupant_ids := get_house_occupant_ids(house_instance_id)
	var total_occupants := occupant_ids.size()
	var full_population_trigger := int(rule.get("important_from_total_occupants", 0))
	if full_population_trigger > 0 and total_occupants >= full_population_trigger:
		return true
	var required_stages_value = rule.get("required_life_stages", [])
	if required_stages_value is Array and not required_stages_value.is_empty():
		var has_required_stage := false
		for character_id in occupant_ids:
			var character := CharacterManager.get_character_by_id(character_id)
			if required_stages_value.has(str(character.get("life_stage", ""))):
				has_required_stage = true
				break
		if not has_required_stage:
			return false
	var min_total := int(rule.get("min_total_occupants", 0))
	if min_total > 0 and total_occupants < min_total:
		return false
	var min_adults := int(rule.get("min_adult_occupants", 0))
	if min_adults > 0:
		var adult_count := 0
		for character_id in occupant_ids:
			var character := CharacterManager.get_character_by_id(character_id)
			if ROLE_LIFE_STAGES.has(str(character.get("life_stage", ""))):
				adult_count += 1
		if adult_count < min_adults:
			return false
	return (
		min_total > 0
		or min_adults > 0
		or (
			required_stages_value is Array
			and not required_stages_value.is_empty()
		)
	)


func get_household_score(house_instance_id: String) -> float:
	var house := get_house_by_instance_id(house_instance_id)
	if house.is_empty():
		return 0.0
	var definition := get_house_definition(str(house.get("house_definition_id", DEFAULT_HOUSE_DEFINITION_ID)))
	var score_config: Dictionary = definition.get("household_score", {})
	var score := float(score_config.get("baseline", 50))
	var occupancy := get_house_occupancy(house_instance_id)
	var full_from := int(score_config.get("full_contribution_from_occupants", 5))
	var roles: Dictionary = house.get("role_assignments", {})
	for role_value in definition.get("roles", []):
		if not role_value is Dictionary:
			continue
		var role_id := str(role_value.get("role_id", ""))
		if not is_role_important(house_instance_id, role_id):
			continue
		var assigned_value = roles.get(role_id, null)
		var contribution := float(score_config.get("important_empty_role_contribution", -10))
		if assigned_value != null:
			var tier := get_role_performance_tier(int(assigned_value), role_id)
			var model: Dictionary = definition.get("performance_model", {})
			for tier_value in model.get("tiers", []):
				if tier_value is Dictionary and str(tier_value.get("tier", "")) == tier:
					contribution = float(tier_value.get("score_contribution", 0))
					break
		if role_id != "head_of_household" and occupancy < full_from:
			contribution *= float(score_config.get("secondary_partial_weight", 0.5))
		score += contribution
	return clampf(
		score,
		float(score_config.get("minimum", 0)),
		float(score_config.get("maximum", 100))
	)


func get_household_status(house_instance_id: String) -> Dictionary:
	var score := get_household_score(house_instance_id)
	for value in get_house_definition().get("status_thresholds", []):
		if value is Dictionary and score >= float(value.get("min_score", 0)) and score <= float(value.get("max_score", 100)):
			return value
	return {}


func get_active_household_perks(house_instance_id: String) -> Array:
	var results: Array = []
	var head_id := get_role_character_id(house_instance_id, "head_of_household")
	var head := CharacterManager.get_character_by_id(head_id)
	if head.is_empty():
		return results
	var flags_value = head.get("flag_ids", [])
	var flags: Array = flags_value if flags_value is Array else []
	for value in household_perk_definitions:
		if not value is Dictionary:
			continue
		var perk: Dictionary = value
		var triggers_value = perk.get("trigger_flag_ids", [])
		var triggers: Array = triggers_value if triggers_value is Array else []
		var matches := 0
		for trigger in triggers:
			for flag in flags:
				if int(flag) == int(trigger):
					matches += 1
					break
		var rule := str(perk.get("match_rule", "any"))
		if (rule == "all" and matches == triggers.size() and not triggers.is_empty()) or (rule != "all" and matches > 0):
			results.append(perk.duplicate(true))
	return results


func get_active_household_perk_ids(house_instance_id: String) -> Array[String]:
	var result: Array[String] = []
	for value in get_active_household_perks(house_instance_id):
		if value is Dictionary:
			result.append(str(value.get("perk_id", "")))
	return result


func purchase_ready_made_house(property_id: String) -> Dictionary:
	return create_house_instance(property_id, false)


func create_house_instance(
	property_id: String,
	is_new_construction: bool
) -> Dictionary:
	if property_id.is_empty() or is_property_owned(property_id):
		return {}
	var purchase_cost := get_house_acquisition_cost(is_new_construction)
	if purchase_cost <= 0 or not GameManager.can_afford(purchase_cost):
		return {}
	if not GameManager.spend_family_money(purchase_cost):
		return {}
	return _create_house(property_id, purchase_cost, 0, true)


func upgrade_house(house_instance_id: String) -> bool:
	var house := get_house_by_instance_id(house_instance_id)
	if house.is_empty():
		return false
	var current_level := int(house.get("level", 1))
	var definition := get_house_definition(str(house.get("house_definition_id", DEFAULT_HOUSE_DEFINITION_ID)))
	if current_level >= int(definition.get("max_level", 5)):
		return false
	var next_level_definition := get_level_definition(current_level + 1)
	var cost := int(next_level_definition.get("upgrade_price", 0))
	if cost <= 0 or not GameManager.spend_family_money(cost):
		return false
	house["level"] = current_level + 1
	house_upgraded.emit(house_instance_id, current_level + 1, cost)
	house_state_changed.emit(house_instance_id, "upgrade")
	return true


func create_save_state() -> Dictionary:
	return {
		"houses": houses.duplicate(true),
		"next_house_instance_number": next_house_instance_number,
		"last_unhoused_penalty_date": last_unhoused_penalty_date
	}


func restore_save_state(state: Dictionary) -> void:
	houses = []
	next_house_instance_number = 1
	last_unhoused_penalty_date = str(state.get("last_unhoused_penalty_date", ""))
	var source_value = state.get("houses", [])
	var source: Array = source_value if source_value is Array else []
	var occupied_characters: Dictionary = {}
	var occupied_properties: Dictionary = {}
	for value in source:
		if not value is Dictionary:
			continue
		var property_id := str(value.get("property_id", ""))
		var instance_id := str(value.get("house_instance_id", ""))
		if property_id.is_empty() or instance_id.is_empty() or occupied_properties.has(property_id):
			continue
		var level := clampi(int(value.get("level", 1)), 1, int(get_house_definition().get("max_level", 5)))
		var restored := _new_house_record(instance_id, property_id, level)
		var restored_roles: Dictionary = restored.get("role_assignments", {})
		var source_roles_value = value.get("role_assignments", {})
		var source_roles: Dictionary = source_roles_value if source_roles_value is Dictionary else {}
		for role_id_value in restored_roles.keys():
			var assigned_value = source_roles.get(role_id_value, null)
			if assigned_value == null:
				continue
			var character_id := int(assigned_value)
			if occupied_characters.has(character_id) or not can_character_hold_household_role(character_id):
				continue
			restored_roles[role_id_value] = character_id
			occupied_characters[character_id] = true
		restored["role_assignments"] = restored_roles
		var residents: Array = []
		var total_capacity := int(get_level_definition(level).get("capacity", 0))
		var resident_capacity := maxi(total_capacity - restored_roles.size(), 0)
		var source_residents_value = value.get("resident_character_ids", [])
		if source_residents_value is Array:
			for resident_value in source_residents_value:
				var character_id := int(resident_value)
				var character := CharacterManager.get_character_by_id(character_id)
				if (
					character_id <= 0
					or occupied_characters.has(character_id)
					or character.is_empty()
					or not bool(character.get("is_alive", true))
					or not bool(character.get("is_player_family", false))
				):
					continue
				if residents.size() >= resident_capacity:
					break
				if restored_roles.values().filter(func(item): return item != null).size() + residents.size() >= total_capacity:
					break
				residents.append(character_id)
				occupied_characters[character_id] = true
		restored["resident_character_ids"] = residents
		houses.append(restored)
		occupied_properties[property_id] = true
	_initialize_next_house_instance_number()
	next_house_instance_number = maxi(next_house_instance_number, int(state.get("next_house_instance_number", 1)))
	if houses.is_empty():
		_migrate_legacy_save_to_starting_house()


func _on_new_game_started(starting_character: Dictionary) -> void:
	houses.clear()
	next_house_instance_number = 1
	last_unhoused_penalty_date = ""
	_create_house(
		get_starting_property_id(),
		0,
		int(starting_character.get("character_id", 0)),
		true
	)


func _create_house(
	property_id: String,
	purchase_cost: int,
	head_character_id: int,
	emit_signals: bool
) -> Dictionary:
	if property_id.is_empty() or is_property_owned(property_id):
		return {}
	var instance_id := "house_%04d" % next_house_instance_number
	next_house_instance_number += 1
	var house := _new_house_record(instance_id, property_id, 1)
	if head_character_id > 0 and can_character_hold_household_role(head_character_id):
		var roles: Dictionary = house.get("role_assignments", {})
		roles["head_of_household"] = head_character_id
		house["role_assignments"] = roles
	houses.append(house)
	if emit_signals:
		house_created.emit(instance_id, property_id, purchase_cost)
		house_state_changed.emit(instance_id, "created")
	return house


func _new_house_record(instance_id: String, property_id: String, level: int) -> Dictionary:
	var roles: Dictionary = {}
	for value in get_role_definitions():
		if value is Dictionary:
			roles[str(value.get("role_id", ""))] = null
	return {
		"house_instance_id": instance_id,
		"house_definition_id": DEFAULT_HOUSE_DEFINITION_ID,
		"property_id": property_id,
		"level": level,
		"role_assignments": roles,
		"resident_character_ids": []
	}


func _migrate_legacy_save_to_starting_house() -> void:
	var candidate_id := 0
	for value in CharacterManager.characters:
		if value is Dictionary and bool(value.get("is_alive", true)) and bool(value.get("is_player_family", false)):
			var character_id := int(value.get("character_id", 0))
			if candidate_id == 0 or character_id < candidate_id:
				candidate_id = character_id
	_create_house(get_starting_property_id(), 0, candidate_id, false)


func _initialize_next_house_instance_number() -> void:
	next_house_instance_number = 1
	for value in houses:
		if not value is Dictionary:
			continue
		var instance_id := str(value.get("house_instance_id", ""))
		if not instance_id.begins_with("house_"):
			continue
		var number_text := instance_id.trim_prefix("house_")
		if number_text.is_valid_int():
			next_house_instance_number = maxi(next_house_instance_number, int(number_text) + 1)


func _on_character_died(character_id: int, _death_date: String) -> void:
	var assignment := get_character_assignment(character_id)
	if assignment.is_empty():
		return
	var house_instance_id := str(assignment.get("house_instance_id", ""))
	_remove_character_assignment_internal(character_id)
	house_state_changed.emit(house_instance_id, "character_death")


func _on_date_changed(_date_text: String) -> void:
	if TimeManager.current_day == 1:
		apply_monthly_unhoused_penalties()


func apply_monthly_unhoused_penalties() -> bool:
	if TimeManager.current_day != 1:
		return false
	var current_date := TimeManager.get_iso_date_string()
	if last_unhoused_penalty_date == current_date:
		return false
	last_unhoused_penalty_date = current_date
	var affected: Array = []
	for value in CharacterManager.characters:
		if not value is Dictionary:
			continue
		var character: Dictionary = value
		var character_id := int(character.get("character_id", 0))
		if not is_character_unhoused(character_id):
			continue
		character["happiness"] = clampi(
			int(character.get("happiness", 0)) - UNHOUSED_MONTHLY_HAPPINESS_PENALTY,
			0,
			CharacterManager.MAX_STAT_VALUE
		)
		affected.append(character_id)
	unhoused_penalties_applied.emit(affected, current_date)
	return not affected.is_empty()
