extends Node


const GENERATOR := preload("res://Scripts/Items/ItemCatalogGenerator.gd")
const SHEET_SCENE := preload("res://UI/ItemListShop/ItemListBottomSheet.tscn")

var passed := 0
var failed := 0


func _ready() -> void:
	var original_money: int = GameManager.family_money
	var original_diamonds: int = GameManager.diamonds
	var original_day: int = TimeManager.current_day
	var original_month: int = TimeManager.current_month
	var original_year: int = TimeManager.current_year
	var original_characters := CharacterManager.characters.duplicate(true)
	var original_item_state := ItemManager.create_save_state()
	CharacterManager.characters.append(_test_character(9901, "Item Test A"))
	CharacterManager.characters.append(_test_character(9902, "Item Test B"))
	TimeManager.current_day = 26
	TimeManager.current_month = 1
	TimeManager.current_year = 1985
	ItemManager.reset_runtime_state()

	_test_catalog()
	_test_pricing()
	await _test_monthly_shop_and_purchase()
	_test_inventory_equipment_lifestyle_and_expiration()

	GameManager.family_money = original_money
	GameManager.diamonds = original_diamonds
	TimeManager.current_day = original_day
	TimeManager.current_month = original_month
	TimeManager.current_year = original_year
	CharacterManager.characters = original_characters
	ItemManager.reset_runtime_state()
	if int(original_item_state.get("monthly_stock_month_key", -1)) >= 0:
		ItemManager.restore_save_state(original_item_state)

	print("")
	print("========================================")
	print("ItemManager tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	if failed == 0:
		print("ALL ITEM MANAGER TESTS PASSED.")
	else:
		push_error("ItemManager has %d failing test(s)." % failed)
	get_tree().quit(failed)


func _test_catalog() -> void:
	_assert_equal(ItemManager.catalog.size(), 261, "All PNG sources produce stable catalog definitions")
	_assert_equal(ItemManager.catalog_pricing_status, "configured_gdd_v3_4", "Production catalog pricing is configured")
	var regenerated := GENERATOR.generate_catalog()
	var regenerated_by_id: Dictionary = {}
	for value in regenerated.get("items", []) as Array:
		var generated_item := value as Dictionary
		regenerated_by_id[str(generated_item.get("id", ""))] = generated_item
	var seen: Dictionary = {}
	var heirloom_count := 0
	var all_valid := true
	var all_stable := true
	for value in ItemManager.catalog:
		var item := value as Dictionary
		var item_id := str(item.get("id", ""))
		var slot := str(item.get("slot", ""))
		var rarity := str(item.get("rarity", ""))
		var lifestyle := int(item.get("lifestyle_value", 0))
		var is_heirloom := bool(item.get("is_heirloom", false))
		var lifestyle_band: Vector2i = GENERATOR.LIFESTYLE_BANDS[rarity]
		all_valid = all_valid and (
			not item_id.is_empty()
			and not seen.has(item_id)
			and slot in ItemManager.VALID_SLOTS
			and ItemManager.CANDIDATE_CHANCES.has(rarity)
			and ResourceLoader.exists(str(item.get("image_path", "")))
			and lifestyle >= lifestyle_band.x
			and lifestyle <= lifestyle_band.y
			and is_heirloom == ("_heirloom_" in ("_" + item_id + "_"))
			and ItemManager._is_price_configured(item)
		)
		seen[item_id] = true
		if is_heirloom:
			heirloom_count += 1
			all_valid = all_valid and int(item.get("durability_months", -1)) == 0 and int(item.get("money_price", -1)) == 0
		else:
			var duration_band: Vector2i = GENERATOR.DURABILITY_BANDS[rarity][slot]
			var duration := int(item.get("durability_months", 0))
			all_valid = all_valid and duration >= duration_band.x and duration <= duration_band.y
		var regenerated_value = regenerated_by_id.get(item_id, {})
		if typeof(regenerated_value) != TYPE_DICTIONARY:
			all_stable = false
		else:
			var generated_item := regenerated_value as Dictionary
			for field in ["id", "display_name", "slot", "rarity", "image_path", "is_heirloom", "lifestyle_value", "durability_months", "money_price", "diamond_price"]:
				all_stable = all_stable and generated_item.get(field) == item.get(field)
	_assert_true(all_valid, "Definitions have stable IDs, valid source metadata, ranges, images, and production prices")
	_assert_true(all_stable, "Intentional regeneration reproduces every generated definition exactly")
	_assert_true(heirloom_count > 0, "Filename markers produce Family Heirloom definitions")
	var center_hits := 0
	var edge_hits := 0
	for index in range(1000):
		var generated_value := GENERATOR._stable_centered_int("distribution:%d" % index, 1, 9, 3)
		if generated_value in [4, 5, 6]:
			center_hits += 1
		if generated_value in [1, 9]:
			edge_hits += 1
	_assert_true(center_hits > edge_hits, "Lifestyle generation is center-weighted")


func _test_pricing() -> void:
	_assert_price_case("Common Accessory minimum", "accessory", "common", 1, 18, false, 4000.0, 4000, 0)
	_assert_price_case("Rare Accessory midpoint", "accessory", "rare", 17, 48, false, 10642.5, 10650, 0)
	_assert_price_case("Epic Outfit midpoint", "outfit", "epic", 24, 48, false, 33110.0, 33100, 0)
	_assert_price_case("Legendary Accessory minimum", "accessory", "legendary", 27, 72, false, 22000.0, 22000, 2)
	_assert_price_case("Legendary Accessory maximum", "accessory", "legendary", 34, 120, false, 30360.0, 30350, 4)
	_assert_price_case("Legendary Vehicle maximum", "vehicle", "legendary", 34, 300, false, 303600.0, 303500, 8)
	_assert_price_case("Heirloom Accessory Lifestyle 1", "accessory", "rare", 1, 0, true, 0.0, 0, 12)
	_assert_price_case("Heirloom Accessory Lifestyle 34", "accessory", "legendary", 34, 0, true, 0.0, 0, 18)
	_assert_price_case("Heirloom Vehicle Lifestyle 1", "vehicle", "rare", 1, 0, true, 0.0, 0, 30)
	_assert_price_case("Heirloom Vehicle Lifestyle 34", "vehicle", "legendary", 34, 0, true, 0.0, 0, 45)


func _assert_price_case(
	case_name: String,
	slot: String,
	rarity: String,
	lifestyle: int,
	duration: int,
	heirloom: bool,
	expected_raw: float,
	expected_money: int,
	expected_diamonds: int
) -> void:
	var result := GENERATOR.calculate_price_components(slot, rarity, lifestyle, duration, heirloom)
	_assert_equal(int(result.get("base_price", 0)), int(GENERATOR.SLOT_BASE_PRICES[slot]), case_name + " base")
	_assert_approx(float(result.get("rarity_multiplier", 0.0)), float(GENERATOR.RARITY_MULTIPLIERS[rarity]), 0.0001, case_name + " rarity multiplier")
	_assert_true(float(result.get("lifestyle_multiplier", 0.0)) >= 1.0, case_name + " Lifestyle premium never discounts")
	_assert_true(float(result.get("lifespan_multiplier", 0.0)) >= 1.0, case_name + " lifespan premium never discounts")
	_assert_approx(float(result.get("raw_money", -1.0)), expected_raw, 0.01, case_name + " raw Money")
	_assert_equal(int(result.get("rounded_money", -1)), expected_money, case_name + " rounded Money")
	_assert_equal(int(result.get("money_price", -1)), expected_money, case_name + " Money price")
	_assert_equal(int(result.get("diamond_price", -1)), expected_diamonds, case_name + " Diamond price")


func _test_monthly_shop_and_purchase() -> void:
	ItemManager.refresh_monthly_shop(4242)
	var initial_stock := ItemManager.get_monthly_stock_by_slot()
	var total_stock := 0
	for slot in ItemManager.VALID_SLOTS:
		var slot_stock := initial_stock.get(slot, []) as Array
		total_stock += slot_stock.size()
		_assert_true(slot_stock.size() <= 6, "%s stock respects its own maximum of six" % slot.capitalize())
		_assert_equal(_unique_count(slot_stock), slot_stock.size(), "%s stock has no duplicates" % slot.capitalize())
		for item_id in slot_stock:
			_assert_equal(str(ItemManager.get_item_definition(str(item_id)).get("slot", "")), slot, "%s stock contains only its slot" % slot.capitalize())
	_assert_true(total_stock > 6, "Accessory, Outfit, and Vehicle do not share one global six-item stock")
	_assert_equal(ItemManager.get_monthly_stock_by_slot(), initial_stock, "Shop reopen/read does not reroll any slot stock")
	_assert_true(TimeManager.date_changed.is_connected(ItemManager._on_date_changed), "Monthly refresh uses TimeManager.date_changed")

	for slot in ItemManager.VALID_SLOTS:
		await _test_real_sheet_binding(_test_character(9901, "Item Test A"), slot)

	var save_snapshot := SaveManager.create_save_snapshot()
	_assert_equal(int(save_snapshot.get("save_version", 0)), 6, "Save snapshot uses Event persistence schema version 6")
	_assert_true(typeof(save_snapshot.get("item_manager", null)) == TYPE_DICTIONARY, "Save contains ItemManager state")
	ItemManager.monthly_stock_by_slot = {}
	ItemManager.monthly_stock_month_key = -1
	_assert_true(SaveManager.apply_save_snapshot(save_snapshot), "Save snapshot reloads")
	_assert_equal(ItemManager.get_monthly_stock_by_slot(), initial_stock, "Save/load preserves all three monthly stocks exactly")
	var legacy_snapshot := save_snapshot.duplicate(true)
	legacy_snapshot["save_version"] = 3
	var legacy_ids := ItemManager.get_monthly_stock_ids().slice(0, 6)
	legacy_snapshot["item_manager"] = {
		"family_inventory": [],
		"equipped_assignments": {},
		"monthly_stock_ids": legacy_ids,
		"monthly_stock_month_key": 198501,
		"monthly_stock_target": 6,
		"next_item_instance_number": 1,
	}
	_assert_true(SaveManager.apply_save_snapshot(legacy_snapshot), "Version 3 global-stock save migrates")
	_assert_equal(_unique_count(ItemManager.get_monthly_stock_ids()), legacy_ids.size(), "Version 3 migration preserves distinct surviving stock IDs")
	_assert_true(SaveManager.apply_save_snapshot(save_snapshot), "Version 5 state restores after migration validation")

	var purchase_slot := "accessory"
	var purchase_stock := ItemManager.get_monthly_stock_ids(purchase_slot)
	var item_id := str(purchase_stock[0])
	var definition := ItemManager.get_item_definition(item_id)
	var money_before := 1000000000
	var diamonds_before := 1000000
	GameManager.set_family_money(money_before)
	GameManager.set_diamonds(diamonds_before)
	var other_slot_stock := ItemManager.get_monthly_stock_ids("outfit")
	GameManager.set_family_money(maxi(int(definition.get("money_price", 0)) - 1, 0))
	GameManager.set_diamonds(maxi(int(definition.get("diamond_price", 0)) - 1, 0))
	var rejected_money := GameManager.family_money
	var rejected_diamonds := GameManager.diamonds
	_assert_true(ItemManager.purchase_item(item_id).is_empty(), "Buy rejects insufficient Money/Diamond balance")
	_assert_equal(GameManager.family_money, rejected_money, "Rejected Buy does not partially deduct Money")
	_assert_equal(GameManager.diamonds, rejected_diamonds, "Rejected Buy does not partially deduct Diamonds")
	_assert_true(item_id in ItemManager.get_monthly_stock_ids(purchase_slot), "Rejected Buy leaves monthly stock unchanged")
	GameManager.set_family_money(money_before)
	GameManager.set_diamonds(diamonds_before)
	var purchased := ItemManager.purchase_item(item_id)
	_assert_true(not purchased.is_empty(), "Buy creates a real ItemInstance")
	_assert_equal(GameManager.family_money, money_before - int(definition.get("money_price", 0)), "Buy deducts exact Money price")
	_assert_equal(GameManager.diamonds, diamonds_before - int(definition.get("diamond_price", 0)), "Buy deducts exact Diamond price")
	_assert_equal(str(purchased.get("purchase_date", "")), "1985-01-26", "Purchase uses current game date")
	_assert_true(str(purchased.get("expiration_date", "")).length() > 0, "Normal purchase stores expiration_date")
	_assert_approx(ItemManager.get_remaining_durability_percent(purchased), 100.0, 0.001, "Purchased normal item starts at 100/100")
	_assert_equal(ItemManager.get_monthly_stock_ids(purchase_slot).size(), purchase_stock.size() - 1, "Purchase leaves an empty position in its slot stock")
	_assert_equal(ItemManager.get_monthly_stock_ids("outfit"), other_slot_stock, "Accessory purchase does not alter Outfit stock")
	_assert_true(ItemManager.purchase_item(item_id).is_empty(), "Repeated Buy signal cannot purchase the removed stock item twice")

	var purchased_state := ItemManager.create_save_state()
	ItemManager.reset_runtime_state()
	ItemManager.restore_save_state(purchased_state)
	var restored := ItemManager._get_inventory_instance(str(purchased.get("instance_id", "")))
	_assert_equal(str(restored.get("expiration_date", "")), str(purchased.get("expiration_date", "")), "Save/load preserves expiration_date")
	TimeManager.current_day = 1
	TimeManager.current_month = 2
	ItemManager._on_date_changed(TimeManager.get_date_string())
	for slot in ItemManager.VALID_SLOTS:
		_assert_true(ItemManager.get_monthly_stock_ids(slot).size() <= 6, "Next month refresh rebuilds %s stock independently" % slot)
	_assert_equal(ItemManager.monthly_stock_month_key, 198502, "First day of next month advances stock identity")

	var heirloom := _first_definition("accessory", true, "")
	var heirloom_id := str(heirloom.get("id", ""))
	ItemManager.monthly_stock_by_slot["accessory"] = [heirloom_id]
	GameManager.set_family_money(123456)
	GameManager.set_diamonds(1000)
	var heirloom_money_before := GameManager.family_money
	var heirloom_diamond_before := GameManager.diamonds
	var purchased_heirloom := ItemManager.purchase_item(heirloom_id)
	_assert_true(not purchased_heirloom.is_empty(), "Heirloom Buy creates an ItemInstance")
	_assert_equal(GameManager.family_money, heirloom_money_before, "Heirloom Buy never deducts Money")
	_assert_equal(GameManager.diamonds, heirloom_diamond_before - int(heirloom.get("diamond_price", 0)), "Heirloom Buy deducts only its generated Diamond price")
	_assert_true(not purchased_heirloom.has("expiration_date"), "Purchased Heirloom has no expiration_date")


func _test_inventory_equipment_lifestyle_and_expiration() -> void:
	TimeManager.current_day = 1
	TimeManager.current_month = 1
	TimeManager.current_year = 2000
	ItemManager.reset_runtime_state()
	var accessory_a := _first_definition("accessory", false, "")
	var accessory_b := _second_definition("accessory", str(accessory_a.get("id", "")))
	var outfit := _first_definition("outfit", false, "")
	var vehicle := _first_definition("vehicle", false, "")
	var heirloom := _first_definition("accessory", true, "")
	var instances := [
		_make_instance("instance_accessory_a", accessory_a, "2000-01-01", "2001-01-01"),
		_make_instance("instance_accessory_b", accessory_b, "2000-01-01", "2002-01-01"),
		_make_instance("instance_outfit", outfit, "2000-01-01", "2003-01-01"),
		_make_instance("instance_outfit_copy", outfit, "2000-02-01", "2003-02-01"),
		_make_instance("instance_vehicle", vehicle, "2000-01-01", "2010-01-01"),
		_make_instance("instance_heirloom", heirloom, "2000-01-01", ""),
	]
	ItemManager.family_inventory = instances.duplicate(true)
	_assert_true(ItemManager.equip_item(9901, "instance_accessory_a", "accessory"), "Wear equips Accessory to the target character")
	_assert_true("instance_accessory_a" not in _ui_instance_ids(ItemManager.get_owned_items("accessory")), "Equipped instance is excluded from the available Owned projection")
	_assert_true(ItemManager.equip_item(9901, "instance_accessory_b", "accessory"), "A second Accessory replaces the first assignment")
	_assert_equal(str(ItemManager.get_equipped_item(9901, "accessory").get("instance_id", "")), "instance_accessory_b", "Single Accessory rule keeps only the replacement equipped")
	_assert_true(not ItemManager._get_inventory_instance("instance_accessory_a").is_empty(), "Replaced Accessory remains in family inventory")
	_assert_true("instance_accessory_a" in _ui_instance_ids(ItemManager.get_owned_items("accessory")), "Replaced instance returns to available Owned without leaving family inventory")
	_assert_true("instance_accessory_b" not in _ui_instance_ids(ItemManager.get_owned_items("accessory")), "Replacement instance leaves available Owned by instance_id")
	_assert_true(ItemManager.equip_item(9901, "instance_outfit", "outfit"), "Outfit equips independently")
	var owned_outfit_ids := _ui_instance_ids(ItemManager.get_owned_items("outfit"))
	_assert_true("instance_outfit" not in owned_outfit_ids, "Equipped Outfit is not duplicated under Owned")
	_assert_true("instance_outfit_copy" in owned_outfit_ids, "Second instance of the same Outfit definition remains available")
	_assert_true(ItemManager.equip_item(9901, "instance_outfit_copy", "outfit"), "Wear replaces an Outfit with another instance of the same definition")
	owned_outfit_ids = _ui_instance_ids(ItemManager.get_owned_items("outfit"))
	_assert_true("instance_outfit" in owned_outfit_ids and "instance_outfit_copy" not in owned_outfit_ids, "Replace swaps Equipped and Owned projections by instance_id")
	_assert_true(ItemManager.equip_item(9901, "instance_outfit", "outfit"), "Original Outfit can be worn again for Unequip validation")
	_assert_true(ItemManager.equip_item(9901, "instance_vehicle", "vehicle"), "Vehicle equips independently")
	_assert_equal(str(ItemManager.get_equipped_item(9901, "accessory").get("instance_id", "")), "instance_accessory_b", "Outfit/Vehicle do not overwrite Accessory")
	_assert_true(not ItemManager.equip_item(9902, "instance_vehicle", "vehicle"), "One ItemInstance cannot be equipped by two characters")

	var expected_lifestyle := mini(
		int(accessory_b.get("lifestyle_value", 0))
		+ int(outfit.get("lifestyle_value", 0))
		+ int(vehicle.get("lifestyle_value", 0)),
		100
	)
	_assert_equal(ItemManager.get_lifestyle_score(9901), expected_lifestyle, "Lifestyle sums only equipped slot definitions")
	_assert_equal(ItemManager.get_lifestyle_score(9902), 0, "Unequipped family inventory gives no Lifestyle")
	_assert_equal(ItemManager.get_equipped_item_count(9901), 3, "Character equipment count is backend-derived")
	var lifestyle_overrides: Dictionary = {}
	for definition in [accessory_b, outfit, vehicle]:
		var definition_id := str((definition as Dictionary).get("id", ""))
		lifestyle_overrides[definition_id] = (ItemManager.catalog_by_id[definition_id] as Dictionary).duplicate(true)
		var maximum_definition := (ItemManager.catalog_by_id[definition_id] as Dictionary).duplicate(true)
		maximum_definition["lifestyle_value"] = 34
		ItemManager.catalog_by_id[definition_id] = maximum_definition
	_assert_equal(ItemManager.get_lifestyle_score(9901), 100, "Character Lifestyle is capped at 100 when three slots total 102")
	for definition_id in lifestyle_overrides:
		ItemManager.catalog_by_id[definition_id] = lifestyle_overrides[definition_id]
	_assert_true(ItemManager.equip_item(9902, "instance_heirloom", "accessory"), "Another family character can equip a different family-owned instance")
	_assert_true("instance_heirloom" in ItemManager.get_equipped_instance_ids(), "Family-wide equipped instance IDs include other characters")
	_assert_true("instance_heirloom" not in _ui_instance_ids(ItemManager.get_owned_items("accessory")), "Another character's equipped instance is unavailable in Owned")

	var before_unequip := ItemManager._get_inventory_instance("instance_outfit").duplicate(true)
	_assert_true(ItemManager.unequip_item(9901, "outfit", "instance_outfit"), "Unequip clears only the requested assignment")
	_assert_true(ItemManager.get_equipped_item(9901, "outfit").is_empty(), "Unequipped slot is empty")
	_assert_equal(ItemManager._get_inventory_instance("instance_outfit"), before_unequip, "Unequip preserves inventory and dates")
	_assert_true("instance_outfit" in _ui_instance_ids(ItemManager.get_owned_items("outfit")), "Unequip immediately returns the same instance to available Owned")

	var calendar_instance := ItemManager._get_inventory_instance("instance_accessory_a")
	_assert_approx(ItemManager.get_remaining_durability_percent(calendar_instance, "2000-01-01"), 100.0, 0.001, "Normal item is 100/100 at purchase")
	_assert_approx(ItemManager.get_remaining_durability_percent(calendar_instance, "2000-07-02"), 50.0, 0.6, "Unequipped item ages with the calendar")
	_assert_true(ItemManager.equip_item(9901, "instance_accessory_a", "accessory"), "Aging item can be equipped before expiration")
	_assert_approx(ItemManager.get_remaining_durability_percent(calendar_instance, "2000-10-01"), 25.0, 0.6, "Equipped item uses the same calendar aging")

	_assert_equal(ItemManager.get_remaining_durability_percent(ItemManager._get_inventory_instance("instance_heirloom"), "2999-01-01"), -1.0, "Heirloom never receives normal durability")
	TimeManager.current_day = 1
	TimeManager.current_month = 1
	TimeManager.current_year = 2001
	ItemManager.process_expirations()
	_assert_true(ItemManager._get_inventory_instance("instance_accessory_a").is_empty(), "Expired item is removed from family inventory")
	_assert_true(ItemManager.get_equipped_item(9901, "accessory").is_empty(), "Expired equipped item clears its character slot")
	_assert_true(not ItemManager._get_inventory_instance("instance_heirloom").is_empty(), "Heirloom remains in inventory across future dates")


func _test_real_sheet_binding(character: Dictionary, slot: String) -> void:
	var sheet := SHEET_SCENE.instantiate() as ItemListBottomSheet
	add_child(sheet)
	await get_tree().process_frame
	sheet.set_data_provider(ItemManager)
	_assert_true(sheet.open_for_character(int(character["character_id"]), slot), "%s production sheet opens" % slot.capitalize())
	_assert_true(int(sheet.get_display_snapshot().get("shop_count", 0)) > 0, "%s More Items renders real monthly stock" % slot.capitalize())
	var first_card := sheet.shop_grid.get_child(0) as ItemListShopCard
	_assert_true(first_card != null and not first_card.action_button.disabled, "%s production Buy is enabled with generated prices" % slot.capitalize())
	_assert_approx(float(first_card.get_display_snapshot().get("durability_percent", -1.0)), 100.0, 0.001, "%s normal shop card is 100/100" % slot.capitalize())
	sheet.close_sheet()
	sheet.queue_free()
	await get_tree().process_frame


func _test_character(character_id: int, first_name: String) -> Dictionary:
	return {
		"character_id": character_id,
		"first_name": first_name,
		"birth_date": "1990-01-01",
		"is_player_family": true,
		"is_alive": true,
	}


func _first_definition(slot: String, heirloom: bool, rarity: String) -> Dictionary:
	for value in ItemManager.catalog:
		var item := value as Dictionary
		if (
			str(item.get("slot", "")) == slot
			and bool(item.get("is_heirloom", false)) == heirloom
			and (rarity.is_empty() or str(item.get("rarity", "")) == rarity)
		):
			return item
	return {}


func _second_definition(slot: String, excluded_id: String) -> Dictionary:
	for value in ItemManager.catalog:
		var item := value as Dictionary
		if str(item.get("slot", "")) == slot and str(item.get("id", "")) != excluded_id:
			return item
	return {}


func _make_instance(instance_id: String, definition: Dictionary, purchase_date: String, expiration_date: String) -> Dictionary:
	var result := {
		"instance_id": instance_id,
		"item_id": str(definition.get("id", "")),
		"purchase_date": purchase_date,
	}
	if not expiration_date.is_empty():
		result["expiration_date"] = expiration_date
	return result


func _unique_count(values: Array) -> int:
	var unique: Dictionary = {}
	for value in values:
		unique[value] = true
	return unique.size()


func _ui_instance_ids(items: Array) -> Array[String]:
	var result: Array[String] = []
	for value in items:
		if typeof(value) == TYPE_DICTIONARY:
			result.append(str((value as Dictionary).get("instance_id", "")))
	return result


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)


func _assert_equal(actual: Variant, expected: Variant, test_name: String) -> void:
	_assert_true(actual == expected, "%s (expected %s, got %s)" % [test_name, str(expected), str(actual)])


func _assert_approx(actual: float, expected: float, tolerance: float, test_name: String) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s (expected %.4f, got %.4f)" % [test_name, expected, actual])
