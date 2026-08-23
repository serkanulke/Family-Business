extends Node


signal catalog_loaded(item_count: int)
signal monthly_stock_changed(month_key: int, stock_by_slot: Dictionary)
signal inventory_changed
signal equipment_changed(character_id: int, slot: String, instance_id: String)
signal item_purchased(instance_id: String, item_id: String)

const CATALOG_PATH := "res://Resources/Json/ItemCatalog.json"
const INITIAL_MONTHLY_STOCK_TARGET := 6
const VALID_SLOTS: Array[String] = ["accessory", "outfit", "vehicle"]
const CANDIDATE_CHANCES := {
	"common": 1.0,
	"uncommon": 0.8,
	"rare": 0.4,
	"epic": 0.1,
	"legendary": 0.05,
}

var catalog: Array = []
var catalog_by_id: Dictionary = {}
var catalog_pricing_status := ""

var family_inventory: Array = []
var equipped_assignments: Dictionary = {}
var monthly_stock_by_slot: Dictionary = {}
var monthly_stock_month_key := -1
var monthly_stock_target_per_slot := INITIAL_MONTHLY_STOCK_TARGET
var next_item_instance_number := 1


func _ready() -> void:
	_load_catalog()
	if not TimeManager.date_changed.is_connected(_on_date_changed):
		TimeManager.date_changed.connect(_on_date_changed)
	if not GameManager.new_game_starting.is_connected(_on_new_game_starting):
		GameManager.new_game_starting.connect(_on_new_game_starting)
	if not GameManager.new_game_started.is_connected(_on_new_game_started):
		GameManager.new_game_started.connect(_on_new_game_started)


func get_catalog_items() -> Array:
	return catalog.duplicate(true)


func get_item_definition(item_id: String) -> Dictionary:
	var definition = catalog_by_id.get(item_id, {})
	return (definition as Dictionary).duplicate(true) if typeof(definition) == TYPE_DICTIONARY else {}


func get_lifestyle_score(character_or_id: Variant) -> int:
	var character_id := _resolve_character_id(character_or_id)
	if character_id <= 0:
		return 0
	var assignments_value = equipped_assignments.get(str(character_id), {})
	if typeof(assignments_value) != TYPE_DICTIONARY:
		return 0
	var score := 0
	for slot in VALID_SLOTS:
		var instance_id := str((assignments_value as Dictionary).get(slot, ""))
		if instance_id.is_empty():
			continue
		var instance := _get_inventory_instance(instance_id)
		if instance.is_empty() or _instance_is_expired(instance):
			continue
		var definition_value = catalog_by_id.get(str(instance.get("item_id", "")), {})
		if typeof(definition_value) == TYPE_DICTIONARY:
			score += clampi(int((definition_value as Dictionary).get("lifestyle_value", 0)), 0, 34)
	return clampi(score, 0, 100)


func get_equipped_item_count(character_or_id: Variant) -> int:
	var character_id := _resolve_character_id(character_or_id)
	if character_id <= 0:
		return 0
	var assignments_value = equipped_assignments.get(str(character_id), {})
	if typeof(assignments_value) != TYPE_DICTIONARY:
		return 0
	var count := 0
	for slot in VALID_SLOTS:
		var instance_id := str((assignments_value as Dictionary).get(slot, ""))
		if not instance_id.is_empty() and not _get_inventory_instance(instance_id).is_empty():
			count += 1
	return count


func get_remaining_durability_percent(instance: Dictionary, current_date: String = "") -> float:
	var definition_value = catalog_by_id.get(str(instance.get("item_id", "")), {})
	if typeof(definition_value) == TYPE_DICTIONARY and bool((definition_value as Dictionary).get("is_heirloom", false)):
		return -1.0
	var purchase_date := str(instance.get("purchase_date", ""))
	var expiration_date := str(instance.get("expiration_date", ""))
	if purchase_date.is_empty() or expiration_date.is_empty():
		return -1.0
	var resolved_date := current_date if not current_date.is_empty() else TimeManager.get_iso_date_string()
	var purchase_day := _iso_date_to_ordinal(purchase_date)
	var expiration_day := _iso_date_to_ordinal(expiration_date)
	var current_day := _iso_date_to_ordinal(resolved_date)
	var lifetime := expiration_day - purchase_day
	if purchase_day < 0 or expiration_day < 0 or current_day < 0 or lifetime <= 0:
		return 0.0
	return clampf(float(expiration_day - current_day) / float(lifetime) * 100.0, 0.0, 100.0)


func process_expirations() -> void:
	_remove_expired_items(true)


func get_equipped_item(character_id: int, slot: String) -> Dictionary:
	var normalized_slot := _normalize_slot(slot)
	if character_id <= 0 or normalized_slot.is_empty():
		return {}
	var assignment_value = equipped_assignments.get(str(character_id), {})
	if typeof(assignment_value) != TYPE_DICTIONARY:
		return {}
	var instance_id := str((assignment_value as Dictionary).get(normalized_slot, ""))
	if instance_id.is_empty():
		return {}
	var instance := _get_inventory_instance(instance_id)
	return _instance_for_ui(instance) if not instance.is_empty() else {}


func get_equipped_instance_ids() -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	for character_key in equipped_assignments.keys():
		var assignments_value = equipped_assignments.get(character_key, {})
		if typeof(assignments_value) != TYPE_DICTIONARY:
			continue
		for slot in VALID_SLOTS:
			var instance_id := str((assignments_value as Dictionary).get(slot, ""))
			if instance_id.is_empty() or seen.has(instance_id):
				continue
			seen[instance_id] = true
			result.append(instance_id)
	return result


func get_owned_items(slot: String) -> Array:
	var normalized_slot := _normalize_slot(slot)
	var result: Array = []
	if normalized_slot.is_empty():
		return result
	var equipped_instance_ids := _equipped_instance_id_set()
	for value in family_inventory:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var instance := value as Dictionary
		var instance_id := str(instance.get("instance_id", ""))
		if instance_id.is_empty() or equipped_instance_ids.has(instance_id):
			continue
		var item := _instance_for_ui(instance)
		if str(item.get("slot", "")) == normalized_slot:
			result.append(item)
	return result


func get_monthly_shop_items(slot: String) -> Array:
	_ensure_current_month_stock()
	var normalized_slot := _normalize_slot(slot)
	var result: Array = []
	if normalized_slot.is_empty():
		return result
	var stock_value = monthly_stock_by_slot.get(normalized_slot, [])
	if typeof(stock_value) != TYPE_ARRAY:
		return result
	for value in stock_value as Array:
		var item_id := str(value)
		var definition_value = catalog_by_id.get(item_id, {})
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition := definition_value as Dictionary
		if str(definition.get("slot", "")) != normalized_slot:
			continue
		result.append(_definition_for_ui(definition, true))
	return result


func get_monthly_stock_ids(slot: String = "") -> Array:
	_ensure_current_month_stock()
	var normalized_slot := _normalize_slot(slot)
	if not normalized_slot.is_empty():
		var slot_value = monthly_stock_by_slot.get(normalized_slot, [])
		return (slot_value as Array).duplicate() if typeof(slot_value) == TYPE_ARRAY else []
	var flattened: Array = []
	for valid_slot in VALID_SLOTS:
		var slot_value = monthly_stock_by_slot.get(valid_slot, [])
		if typeof(slot_value) == TYPE_ARRAY:
			flattened.append_array((slot_value as Array).duplicate())
	return flattened


func get_monthly_stock_by_slot() -> Dictionary:
	_ensure_current_month_stock()
	return monthly_stock_by_slot.duplicate(true)


func refresh_monthly_shop(seed: int = -1, emit_change: bool = true) -> void:
	var random := RandomNumberGenerator.new()
	if seed >= 0:
		random.seed = seed
	else:
		random.randomize()
	var candidates_by_slot := _empty_stock_by_slot()
	for value in catalog:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var definition := value as Dictionary
		var rarity := str(definition.get("rarity", "")).to_lower()
		var chance := float(CANDIDATE_CHANCES.get(rarity, 0.0))
		if random.randf() <= chance:
			var slot := _normalize_slot(str(definition.get("slot", "")))
			if not slot.is_empty():
				(candidates_by_slot[slot] as Array).append(str(definition.get("id", "")))
	monthly_stock_by_slot = _empty_stock_by_slot()
	for slot in VALID_SLOTS:
		var candidates: Array = candidates_by_slot[slot]
		_shuffle_untyped_with_rng(candidates, random)
		var selection_count := mini(maxi(monthly_stock_target_per_slot, 0), candidates.size())
		for index in range(selection_count):
			(monthly_stock_by_slot[slot] as Array).append(candidates[index])
	monthly_stock_month_key = _current_month_key()
	if emit_change:
		monthly_stock_changed.emit(monthly_stock_month_key, monthly_stock_by_slot.duplicate(true))


func purchase_item(item_id: String) -> Dictionary:
	_ensure_current_month_stock()
	var definition_value = catalog_by_id.get(item_id, {})
	if typeof(definition_value) != TYPE_DICTIONARY:
		return {}
	var definition := definition_value as Dictionary
	var slot := _normalize_slot(str(definition.get("slot", "")))
	var slot_stock_value = monthly_stock_by_slot.get(slot, [])
	if typeof(slot_stock_value) != TYPE_ARRAY or item_id not in (slot_stock_value as Array):
		return {}
	if not _is_price_configured(definition):
		push_error("Item catalog contains an invalid production price: " + item_id)
		return {}
	var money_price := int(definition.get("money_price", 0))
	var diamond_price := int(definition.get("diamond_price", 0))
	if GameManager.family_money < money_price or GameManager.diamonds < diamond_price:
		return {}
	GameManager.set_family_money(GameManager.family_money - money_price)
	GameManager.set_diamonds(GameManager.diamonds - diamond_price)
	var instance_id := "item_%06d" % next_item_instance_number
	next_item_instance_number += 1
	var purchase_date := TimeManager.get_iso_date_string()
	var instance := {
		"instance_id": instance_id,
		"item_id": item_id,
		"purchase_date": purchase_date,
	}
	if not bool(definition.get("is_heirloom", false)):
		instance["expiration_date"] = _add_months_to_date(
			purchase_date,
			int(definition.get("durability_months", 0))
		)
	family_inventory.append(instance)
	(monthly_stock_by_slot[slot] as Array).erase(item_id)
	inventory_changed.emit()
	monthly_stock_changed.emit(monthly_stock_month_key, monthly_stock_by_slot.duplicate(true))
	item_purchased.emit(instance_id, item_id)
	return instance.duplicate(true)


func equip_item(character_id: int, instance_id: String, slot: String) -> bool:
	var normalized_slot := _normalize_slot(slot)
	if character_id <= 0 or normalized_slot.is_empty():
		return false
	if CharacterManager.get_character_by_id(character_id).is_empty():
		return false
	var instance := _get_inventory_instance(instance_id)
	if instance.is_empty():
		return false
	var definition := get_item_definition(str(instance.get("item_id", "")))
	if str(definition.get("slot", "")) != normalized_slot:
		return false
	if _instance_is_expired(instance):
		return false
	var equipped_owner := _find_equipped_owner(instance_id)
	if equipped_owner > 0 and equipped_owner != character_id:
		return false
	var character_key := str(character_id)
	var assignments_value = equipped_assignments.get(character_key, {})
	var assignments: Dictionary = (
		(assignments_value as Dictionary).duplicate(true)
		if typeof(assignments_value) == TYPE_DICTIONARY
		else {}
	)
	assignments[normalized_slot] = instance_id
	equipped_assignments[character_key] = assignments
	equipment_changed.emit(character_id, normalized_slot, instance_id)
	return true


func unequip_item(character_id: int, slot: String, expected_instance_id: String = "") -> bool:
	var normalized_slot := _normalize_slot(slot)
	var character_key := str(character_id)
	var assignments_value = equipped_assignments.get(character_key, {})
	if normalized_slot.is_empty() or typeof(assignments_value) != TYPE_DICTIONARY:
		return false
	var assignments := (assignments_value as Dictionary).duplicate(true)
	var current_instance_id := str(assignments.get(normalized_slot, ""))
	if current_instance_id.is_empty():
		return false
	if not expected_instance_id.is_empty() and current_instance_id != expected_instance_id:
		return false
	assignments.erase(normalized_slot)
	if assignments.is_empty():
		equipped_assignments.erase(character_key)
	else:
		equipped_assignments[character_key] = assignments
	equipment_changed.emit(character_id, normalized_slot, "")
	return true


func reset_runtime_state() -> void:
	family_inventory.clear()
	equipped_assignments.clear()
	monthly_stock_by_slot = _empty_stock_by_slot()
	monthly_stock_month_key = -1
	monthly_stock_target_per_slot = INITIAL_MONTHLY_STOCK_TARGET
	next_item_instance_number = 1


func create_save_state() -> Dictionary:
	return {
		"family_inventory": family_inventory.duplicate(true),
		"equipped_assignments": equipped_assignments.duplicate(true),
		"monthly_stock_by_slot": monthly_stock_by_slot.duplicate(true),
		"monthly_stock_month_key": monthly_stock_month_key,
		"monthly_stock_target_per_slot": monthly_stock_target_per_slot,
		"next_item_instance_number": next_item_instance_number,
	}


func restore_save_state(state: Dictionary) -> void:
	reset_runtime_state()
	var inventory_value = state.get("family_inventory", [])
	if typeof(inventory_value) == TYPE_ARRAY:
		for value in inventory_value as Array:
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var instance := value as Dictionary
			if catalog_by_id.has(str(instance.get("item_id", ""))):
				family_inventory.append(instance.duplicate(true))
	var equipped_value = state.get("equipped_assignments", {})
	if typeof(equipped_value) == TYPE_DICTIONARY:
		equipped_assignments = (equipped_value as Dictionary).duplicate(true)
	monthly_stock_target_per_slot = maxi(int(state.get(
		"monthly_stock_target_per_slot",
		state.get("monthly_stock_target", INITIAL_MONTHLY_STOCK_TARGET)
	)), 0)
	var stock_by_slot_value = state.get("monthly_stock_by_slot", {})
	if state.has("monthly_stock_by_slot") and typeof(stock_by_slot_value) == TYPE_DICTIONARY:
		_restore_stock_by_slot(stock_by_slot_value as Dictionary)
	else:
		# Version 3 used one global array. Preserve its surviving items and
		# distribute them into their canonical slot while migrating the save.
		var legacy_stock_value = state.get("monthly_stock_ids", [])
		if typeof(legacy_stock_value) == TYPE_ARRAY:
			_restore_legacy_global_stock(legacy_stock_value as Array)
	monthly_stock_month_key = int(state.get("monthly_stock_month_key", -1))
	next_item_instance_number = maxi(int(state.get("next_item_instance_number", 1)), 1)
	_remove_expired_items(false)
	_normalize_equipped_assignments()
	_ensure_current_month_stock(false)


func _load_catalog() -> void:
	catalog.clear()
	catalog_by_id.clear()
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("Stable Item Catalog is missing: " + CATALOG_PATH)
		return
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Stable Item Catalog could not be opened: " + CATALOG_PATH)
		return
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("Stable Item Catalog is invalid JSON: " + CATALOG_PATH)
		return
	var root := json.data as Dictionary
	catalog_pricing_status = str(root.get("pricing_status", ""))
	var items_value = root.get("items", [])
	if typeof(items_value) != TYPE_ARRAY:
		push_error("Stable Item Catalog items must be an Array.")
		return
	for value in items_value as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var definition := value as Dictionary
		var item_id := str(definition.get("id", ""))
		if item_id.is_empty() or catalog_by_id.has(item_id):
			continue
		catalog.append(definition.duplicate(true))
		catalog_by_id[item_id] = catalog.back()
	catalog_loaded.emit(catalog.size())
	print("Items loaded: ", catalog.size())


func _definition_for_ui(definition: Dictionary, shop_item: bool) -> Dictionary:
	var result := definition.duplicate(true)
	result["item_id"] = str(definition.get("id", ""))
	if shop_item:
		result["purchase_available"] = _is_price_configured(definition)
		if not bool(definition.get("is_heirloom", false)):
			result["durability_percent"] = 100.0
	return result


func _instance_for_ui(instance: Dictionary) -> Dictionary:
	var item_id := str(instance.get("item_id", ""))
	var definition_value = catalog_by_id.get(item_id, {})
	if typeof(definition_value) != TYPE_DICTIONARY:
		return {}
	var result := _definition_for_ui(definition_value as Dictionary, false)
	for key in instance:
		result[key] = instance[key]
	if not bool(result.get("is_heirloom", false)):
		result["durability_percent"] = get_remaining_durability_percent(instance)
	return result


func _is_price_configured(definition: Dictionary) -> bool:
	var rarity := str(definition.get("rarity", "")).to_lower()
	var is_heirloom := bool(definition.get("is_heirloom", false))
	var money_price := int(definition.get("money_price", 0))
	var diamond_price := int(definition.get("diamond_price", 0))
	if is_heirloom:
		return money_price == 0 and diamond_price > 0
	if rarity == "legendary":
		return money_price > 0 and diamond_price > 0
	return money_price > 0 and diamond_price == 0


func _ensure_current_month_stock(emit_change: bool = true) -> void:
	if monthly_stock_month_key != _current_month_key():
		refresh_monthly_shop(-1, emit_change)


func _on_new_game_starting() -> void:
	reset_runtime_state()


func _on_new_game_started(_starting_character: Dictionary) -> void:
	refresh_monthly_shop()


func _on_date_changed(_date_text: String) -> void:
	_remove_expired_items(true)
	if TimeManager.current_day == 1 and monthly_stock_month_key != _current_month_key():
		refresh_monthly_shop()


func _remove_expired_items(emit_changes: bool) -> void:
	var removed_instance_ids: Array[String] = []
	for index in range(family_inventory.size() - 1, -1, -1):
		var value = family_inventory[index]
		if typeof(value) != TYPE_DICTIONARY:
			family_inventory.remove_at(index)
			continue
		var instance := value as Dictionary
		if _instance_is_expired(instance):
			removed_instance_ids.append(str(instance.get("instance_id", "")))
			family_inventory.remove_at(index)
	if removed_instance_ids.is_empty():
		return
	var cleared_assignments: Array[Dictionary] = []
	for character_key in equipped_assignments.keys():
		var assignments_value = equipped_assignments[character_key]
		if typeof(assignments_value) != TYPE_DICTIONARY:
			continue
		var assignments := assignments_value as Dictionary
		for slot in assignments.keys():
			if str(assignments[slot]) in removed_instance_ids:
				assignments.erase(slot)
				cleared_assignments.append({"character_id": int(character_key), "slot": str(slot)})
		if assignments.is_empty():
			equipped_assignments.erase(character_key)
	if emit_changes:
		inventory_changed.emit()
		for cleared in cleared_assignments:
			equipment_changed.emit(int(cleared["character_id"]), str(cleared["slot"]), "")


func _normalize_equipped_assignments() -> void:
	var valid_instances: Dictionary = {}
	for value in family_inventory:
		if typeof(value) == TYPE_DICTIONARY:
			valid_instances[str((value as Dictionary).get("instance_id", ""))] = true
	var claimed_instances: Dictionary = {}
	for character_key in equipped_assignments.keys():
		var assignments_value = equipped_assignments[character_key]
		if typeof(assignments_value) != TYPE_DICTIONARY:
			equipped_assignments.erase(character_key)
			continue
		var normalized_assignments: Dictionary = {}
		for slot in (assignments_value as Dictionary).keys():
			var normalized_slot := _normalize_slot(str(slot))
			var instance_id := str((assignments_value as Dictionary)[slot])
			var instance := _get_inventory_instance(instance_id)
			var definition := get_item_definition(str(instance.get("item_id", "")))
			if (
				not normalized_slot.is_empty()
				and valid_instances.has(instance_id)
				and not claimed_instances.has(instance_id)
				and str(definition.get("slot", "")) == normalized_slot
			):
				normalized_assignments[normalized_slot] = instance_id
				claimed_instances[instance_id] = true
		if normalized_assignments.is_empty():
			equipped_assignments.erase(character_key)
		else:
			equipped_assignments[character_key] = normalized_assignments


func _get_inventory_instance(instance_id: String) -> Dictionary:
	for value in family_inventory:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("instance_id", "")) == instance_id:
			return value as Dictionary
	return {}


func _find_equipped_owner(instance_id: String) -> int:
	for character_key in equipped_assignments.keys():
		var assignments_value = equipped_assignments[character_key]
		if typeof(assignments_value) != TYPE_DICTIONARY:
			continue
		for slot in VALID_SLOTS:
			if str((assignments_value as Dictionary).get(slot, "")) == instance_id:
				return int(character_key)
	return 0


func _equipped_instance_id_set() -> Dictionary:
	var result: Dictionary = {}
	for instance_id in get_equipped_instance_ids():
		result[instance_id] = true
	return result


func _resolve_character_id(character_or_id: Variant) -> int:
	if typeof(character_or_id) == TYPE_DICTIONARY:
		return int((character_or_id as Dictionary).get("character_id", 0))
	if typeof(character_or_id) == TYPE_INT or typeof(character_or_id) == TYPE_FLOAT:
		return int(character_or_id)
	return 0


func _instance_is_expired(instance: Dictionary) -> bool:
	var expiration_date := str(instance.get("expiration_date", ""))
	return not expiration_date.is_empty() and TimeManager.get_iso_date_string() >= expiration_date


func _normalize_slot(slot: String) -> String:
	var normalized := slot.strip_edges().to_lower()
	return normalized if normalized in VALID_SLOTS else ""


func _current_month_key() -> int:
	return TimeManager.current_year * 100 + TimeManager.current_month


func _empty_stock_by_slot() -> Dictionary:
	return {
		"accessory": [],
		"outfit": [],
		"vehicle": [],
	}


func _restore_stock_by_slot(saved_stock: Dictionary) -> void:
	monthly_stock_by_slot = _empty_stock_by_slot()
	var seen: Dictionary = {}
	for slot in VALID_SLOTS:
		var stock_value = saved_stock.get(slot, [])
		if typeof(stock_value) != TYPE_ARRAY:
			continue
		for value in stock_value as Array:
			var item_id := str(value)
			var definition := get_item_definition(item_id)
			if (
				not seen.has(item_id)
				and str(definition.get("slot", "")) == slot
				and (monthly_stock_by_slot[slot] as Array).size() < monthly_stock_target_per_slot
			):
				seen[item_id] = true
				(monthly_stock_by_slot[slot] as Array).append(item_id)


func _restore_legacy_global_stock(saved_stock: Array) -> void:
	monthly_stock_by_slot = _empty_stock_by_slot()
	var seen: Dictionary = {}
	for value in saved_stock:
		var item_id := str(value)
		var definition := get_item_definition(item_id)
		var slot := _normalize_slot(str(definition.get("slot", "")))
		if slot.is_empty() or seen.has(item_id):
			continue
		seen[item_id] = true
		(monthly_stock_by_slot[slot] as Array).append(item_id)


func _shuffle_untyped_with_rng(values: Array, random: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var temporary: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


func _iso_date_to_ordinal(date_text: String) -> int:
	var parts := date_text.split("-")
	if parts.size() != 3:
		return -1
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	if year < 1 or month < 1 or month > 12 or day < 1 or day > _days_in_month(year, month):
		return -1
	var previous_year := year - 1
	var ordinal := (
		365 * previous_year
		+ floori(float(previous_year) / 4.0)
		- floori(float(previous_year) / 100.0)
		+ floori(float(previous_year) / 400.0)
		+ day
	)
	for month_index in range(1, month):
		ordinal += _days_in_month(year, month_index)
	return ordinal


func _add_months_to_date(date_text: String, month_count: int) -> String:
	var parts := date_text.split("-")
	if parts.size() != 3:
		return date_text
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	var absolute_month := year * 12 + (month - 1) + maxi(month_count, 0)
	var result_year := floori(float(absolute_month) / 12.0)
	var result_month := absolute_month % 12 + 1
	var result_day := mini(day, _days_in_month(result_year, result_month))
	return "%04d-%02d-%02d" % [result_year, result_month, result_day]


func _days_in_month(year: int, month: int) -> int:
	var lengths: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
		lengths[1] = 29
	return lengths[clampi(month, 1, 12) - 1]
