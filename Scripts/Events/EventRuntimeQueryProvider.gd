class_name EventRuntimeQueryProvider
extends RefCounted


var history_provider: EventHistoryQueryProvider
var entitlement_provider: EntitlementQueryProvider
var _flag_definitions: Array = []


func _init(
	p_history_provider: EventHistoryQueryProvider = null,
	p_entitlement_provider: EntitlementQueryProvider = null
) -> void:
	history_provider = p_history_provider if p_history_provider != null else EventHistoryQueryProvider.new()
	entitlement_provider = p_entitlement_provider if p_entitlement_provider != null else EntitlementQueryProvider.new()
	_flag_definitions = _load_json_array("res://Resources/Json/Flag.json", "flags")


func get_current_date() -> String:
	return TimeManager.get_iso_date_string()


func get_character(character_id: int) -> Dictionary:
	return CharacterManager.get_character_by_id(character_id)


func get_family_character_ids(include_dead: bool = false) -> Array[int]:
	var result: Array[int] = []
	for value in CharacterManager.characters:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var character: Dictionary = value
		if not bool(character.get("is_player_family", false)):
			continue
		if not include_dead and not bool(character.get("is_alive", true)):
			continue
		var character_id := int(character.get("character_id", 0))
		if character_id > 0:
			result.append(character_id)
	result.sort()
	return result


func get_relation_ids(character_id: int, relation: String) -> Array[int]:
	var character := get_character(character_id)
	var result: Array[int] = []
	if character.is_empty():
		return result
	match relation:
		"spouse":
			_append_character_id(result, character.get("partner_id", null))
		"child":
			for value in _as_array(character.get("children_ids", [])):
				_append_character_id(result, value)
		"parent":
			for value in _as_array(character.get("parent_ids", [])):
				_append_character_id(result, value)
		"family_member":
			for value in get_family_character_ids():
				if value != character_id:
					result.append(value)
	result.sort()
	return result


func get_relationship_npc_ids(primary_character_id: int = 0) -> Array[int]:
	var result: Array[int] = []
	for value in CharacterManager.characters:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var character: Dictionary = value
		if bool(character.get("is_player_family", false)) or not bool(character.get("is_alive", true)):
			continue
		if primary_character_id > 0:
			var linked = character.get("linked_character_id", null)
			if linked != null and int(linked) != primary_character_id:
				continue
		var character_id := int(character.get("character_id", 0))
		if character_id > 0:
			result.append(character_id)
	result.sort()
	return result


func get_character_house_id(character_id: int) -> String:
	return String(HouseManager.get_character_assignment(character_id).get("house_instance_id", ""))


func get_owned_business_ids() -> Array[String]:
	var result: Array[String] = []
	for value in BusinessManager.businesses:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var business_id := String(value.get("business_instance_id", ""))
		if not business_id.is_empty():
			result.append(business_id)
	result.sort()
	return result


func entity_exists(participant_type: String, value) -> bool:
	match participant_type:
		"character", "relationship_npc":
			var character := get_character(int(value))
			return not character.is_empty() and bool(character.get("is_alive", true))
		"character_group":
			if typeof(value) != TYPE_ARRAY:
				return false
			for character_id in value:
				if not entity_exists("character", character_id):
					return false
			return true
		"house":
			return not HouseManager.get_house_by_instance_id(String(value)).is_empty()
		"business":
			return not BusinessManager.get_business_by_instance_id(String(value)).is_empty()
		"context":
			return value != null
	return false


func can_afford_cost(cost_value) -> bool:
	if cost_value == null:
		return true
	if typeof(cost_value) != TYPE_DICTIONARY:
		return false
	var cost: Dictionary = cost_value
	var amount := float(cost.get("amount", 0.0))
	match String(cost.get("currency", "")):
		"money":
			return float(GameManager.family_money) >= amount
		"diamonds":
			return float(GameManager.diamonds) >= amount
	return false


func get_requirement_value(
	requirement: Dictionary,
	participants: Dictionary,
	context: Dictionary
) -> Dictionary:
	var requirement_type := String(requirement.get("type", ""))
	var expected = requirement.get("value", null)
	var target_name := String(requirement.get("target", ""))
	var target_value = participants.get(target_name, null)
	var character := _character_from_value(target_value)
	var actual = null
	var match_mode := "normal"

	match requirement_type:
		"stat":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = character.get(String(requirement.get("stat", "")), null)
		"flag":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = _character_flag_values(character)
			match_mode = "membership"
		"age":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = CharacterManager.get_character_age(character)
		"life_stage", "gender", "is_alive":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = character.get(requirement_type, null)
		"is_family_member":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = character.get("is_player_family", null)
		"has_child":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = not get_relation_ids(int(character.get("character_id", 0)), "child").is_empty()
		"has_parent":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = not get_relation_ids(int(character.get("character_id", 0)), "parent").is_empty()
		"has_spouse":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = not get_relation_ids(int(character.get("character_id", 0)), "spouse").is_empty()
		"family_member_count":
			actual = get_family_character_ids().size()
		"employment_status":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = _employment_status(character)
		"job":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = character.get("job_id", null)
		"job_tag":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = _job_tags(character)
			match_mode = "membership"
		"education_stage":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = _education_stage(character)
		"school":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = character.get("school_id", null)
		"school_type":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = _school_for_character(character).get("school_type", "")
		"major":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = character.get("major_id", null)
		"lifestyle_score":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = ItemManager.get_lifestyle_score(int(character.get("character_id", 0)))
		"equipped_item", "item_type", "item_rarity", "item_flag":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = _equipped_item_values(int(character.get("character_id", 0)), requirement_type)
			match_mode = "membership"
		"money":
			actual = GameManager.family_money
		"diamonds":
			actual = GameManager.diamonds
		"house_assignment":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = not HouseManager.get_character_assignment(int(character.get("character_id", 0))).is_empty()
		"house_level":
			var house := _resolve_house(requirement, participants, context)
			if house.is_empty(): return _invalid("House context is unavailable.")
			actual = house.get("level", null)
		"household_status":
			var house := _resolve_house(requirement, participants, context)
			if house.is_empty(): return _invalid("House context is unavailable.")
			actual = HouseManager.get_household_status(String(house.get("house_instance_id", ""))).get("status_id", "")
		"household_perk":
			var house := _resolve_house(requirement, participants, context)
			if house.is_empty(): return _invalid("House context is unavailable.")
			actual = HouseManager.get_active_household_perk_ids(String(house.get("house_instance_id", "")))
			match_mode = "membership"
		"business_owned":
			actual = not get_owned_business_ids().is_empty()
		"business_type", "business_level":
			var business := _resolve_business(requirement, participants, context)
			if business.is_empty(): return _invalid("Business context is unavailable.")
			actual = business.get("business_type_id" if requirement_type == "business_type" else "level", null)
		"business_role":
			if character.is_empty(): return _invalid("Character target is unavailable.")
			actual = BusinessManager.get_character_assignment(int(character.get("character_id", 0))).get("slot_id", "")
		"event_seen", "event_completed", "event_not_completed":
			var event_id := String(expected)
			if requirement_type == "event_seen": actual = history_provider.has_seen(event_id, participants, context)
			elif requirement_type == "event_completed": actual = history_provider.has_completed(event_id, participants, context)
			else: actual = not history_provider.has_completed(event_id, participants, context)
			expected = true
		"choice_made", "outcome_reached":
			if typeof(expected) != TYPE_DICTIONARY: return _invalid("Story-history reference is invalid.")
			var reference: Dictionary = expected
			if requirement_type == "choice_made":
				actual = history_provider.has_choice(String(reference.get("event_id", "")), String(reference.get("choice_id", "")), participants, context)
			else:
				actual = history_provider.has_outcome(String(reference.get("event_id", "")), String(reference.get("outcome_id", "")), participants, context)
			expected = true
		"entitlement":
			actual = entitlement_provider.owns_entitlement(String(expected))
			expected = true
		"date":
			actual = get_current_date()
		"year":
			actual = TimeManager.current_year
		"month":
			actual = TimeManager.current_month
		_:
			return _invalid("Unsupported runtime requirement type '%s'." % requirement_type)

	if actual == null:
		return _invalid("Authoritative runtime value is unavailable.")
	return {
		"valid": true,
		"actual": actual,
		"expected": expected,
		"match_mode": match_mode,
		"label": get_requirement_label(requirement),
		"expected_label": get_value_label(requirement, requirement.get("value", null))
	}


func get_requirement_label(requirement: Dictionary) -> String:
	var requirement_type := String(requirement.get("type", ""))
	if requirement_type == "stat":
		return String(requirement.get("stat", "Stat")).replace("_", " ").capitalize()
	var labels := {
		"lifestyle_score": "Lifestyle", "family_member_count": "Family members",
		"employment_status": "Employment", "education_stage": "Education stage",
		"money": "Money", "diamonds": "Diamonds",
		"house_assignment": "House assignment", "house_level": "House level",
		"household_status": "Household Status", "household_perk": "Household Perk",
		"business_owned": "Business ownership", "business_type": "Business type",
		"business_level": "Business level", "business_role": "Business role",
		"entitlement": "Access", "date": "Date", "year": "Year", "month": "Month"
	}
	return String(labels.get(requirement_type, requirement_type.replace("_", " ").capitalize()))


func get_value_label(requirement: Dictionary, value) -> String:
	var requirement_type := String(requirement.get("type", ""))
	match requirement_type:
		"job":
			return String(CareerManager.get_job_by_id(int(value)).get("job_name", value))
		"school":
			return String(EducationManager.get_school_by_id(int(value)).get("school_name", value))
		"major":
			return String(EducationManager.get_major_by_id(int(value)).get("major_name", value))
		"flag", "item_flag":
			return _flag_display_name(value)
		"equipped_item":
			return String(ItemManager.get_item_definition(String(value)).get("display_name", value))
		"business_type":
			return String(BusinessManager.get_business_type_by_id(String(value)).get("display_name", value))
		"household_status":
			for definition in HouseManager.get_house_definition().get("status_thresholds", []):
				if typeof(definition) == TYPE_DICTIONARY and String(definition.get("status_id", "")) == String(value):
					return String(definition.get("display_name", value))
		"household_perk":
			for definition in HouseManager.household_perk_definitions:
				if typeof(definition) == TYPE_DICTIONARY and String(definition.get("perk_id", "")) == String(value):
					return String(definition.get("display_name", value))
	return str(value)


func _resolve_house(requirement: Dictionary, participants: Dictionary, context: Dictionary) -> Dictionary:
	var target = participants.get(String(requirement.get("target", "")), null)
	if typeof(target) == TYPE_STRING:
		var direct := HouseManager.get_house_by_instance_id(String(target))
		if not direct.is_empty(): return direct
	var character := _character_from_value(target)
	if not character.is_empty():
		var assigned := HouseManager.get_character_house(int(character.get("character_id", 0)))
		if not assigned.is_empty(): return assigned
	var context_id := String(context.get("house_instance_id", ""))
	if not context_id.is_empty(): return HouseManager.get_house_by_instance_id(context_id)
	var primary := _character_from_value(participants.get("primary", null))
	if not primary.is_empty():
		var primary_house := HouseManager.get_character_house(int(primary.get("character_id", 0)))
		if not primary_house.is_empty(): return primary_house
	return HouseManager.houses[0] if HouseManager.houses.size() == 1 and typeof(HouseManager.houses[0]) == TYPE_DICTIONARY else {}


func _resolve_business(requirement: Dictionary, participants: Dictionary, context: Dictionary) -> Dictionary:
	var target = participants.get(String(requirement.get("target", "")), null)
	if typeof(target) == TYPE_STRING:
		var direct := BusinessManager.get_business_by_instance_id(String(target))
		if not direct.is_empty(): return direct
	var character := _character_from_value(target)
	if not character.is_empty():
		var assignment := BusinessManager.get_character_assignment(int(character.get("character_id", 0)))
		var assigned := BusinessManager.get_business_by_instance_id(String(assignment.get("business_instance_id", "")))
		if not assigned.is_empty(): return assigned
	var context_id := String(context.get("business_instance_id", ""))
	if not context_id.is_empty(): return BusinessManager.get_business_by_instance_id(context_id)
	return BusinessManager.businesses[0] if BusinessManager.businesses.size() == 1 and typeof(BusinessManager.businesses[0]) == TYPE_DICTIONARY else {}


func _character_from_value(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return get_character(int(value))
	return {}


func _employment_status(character: Dictionary) -> String:
	if bool(character.get("is_retired", false)):
		return "retired"
	return "employed" if character.get("job_id", null) != null else "unemployed"


func _job_for_character(character: Dictionary) -> Dictionary:
	var job_value = character.get("job_id", null)
	return {} if job_value == null else CareerManager.get_job_by_id(int(job_value))


func _job_tags(character: Dictionary) -> Array:
	var value = _job_for_character(character).get("event_tags", [])
	return value.duplicate() if typeof(value) == TYPE_ARRAY else []


func _school_for_character(character: Dictionary) -> Dictionary:
	var school_value = character.get("school_id", null)
	return {} if school_value == null else EducationManager.get_school_by_id(int(school_value))


func _education_stage(character: Dictionary) -> String:
	var direct := String(character.get("education_stage", ""))
	if not direct.is_empty(): return direct
	return String(_school_for_character(character).get("education_stage", ""))


func _equipped_item_values(character_id: int, requirement_type: String) -> Array:
	var result: Array = []
	for slot in ItemManager.VALID_SLOTS:
		var item := ItemManager.get_equipped_item(character_id, slot)
		if item.is_empty(): continue
		match requirement_type:
			"equipped_item": result.append(String(item.get("item_id", "")))
			"item_type": result.append(String(item.get("slot", "")))
			"item_rarity": result.append(String(item.get("rarity", "")))
			"item_flag":
				for key in ["flag_ids", "item_flags", "flags"]:
					for value in _as_array(item.get(key, [])):
						if not result.has(value): result.append(value)
	return result


func _character_flag_values(character: Dictionary) -> Array:
	var result: Array = _as_array(character.get("flag_ids", [])).duplicate()
	for value in result.duplicate():
		var name := _flag_display_name(value).to_lower()
		if not name.is_empty() and not result.has(name): result.append(name)
	return result


func _flag_display_name(value) -> String:
	for definition in _flag_definitions:
		if typeof(definition) != TYPE_DICTIONARY: continue
		if str(definition.get("flag_id", "")) == str(value) or str(definition.get("flag_name", "")).to_lower() == str(value).to_lower():
			return str(definition.get("display_name", definition.get("flag_name", value))).replace("_", " ").capitalize()
	return str(value)


func _invalid(message: String) -> Dictionary:
	return {"valid": false, "message": message}


func _append_character_id(result: Array[int], value) -> void:
	if value == null: return
	var character_id := int(value)
	if character_id > 0 and not get_character(character_id).is_empty() and not result.has(character_id):
		result.append(character_id)


func _as_array(value) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


func _load_json_array(path: String, root_key: String) -> Array:
	if not FileAccess.file_exists(path): return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return []
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY: return []
	var values = data.get(root_key, [])
	return values if typeof(values) == TYPE_ARRAY else []
