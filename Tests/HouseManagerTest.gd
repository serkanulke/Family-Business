extends Node

var passed := 0
var failed := 0
var saved_characters: Array
var saved_houses: Array
var saved_businesses: Array
var saved_money := 0
var saved_date := Vector3i.ZERO
var saved_penalty_date := ""
var saved_house_payment_date := ""


func _ready() -> void:
	_save_state()
	_run_tests()
	_restore_state()
	print("House tests: %d passed / %d failed" % [passed, failed])
	if failed > 0:
		push_error("House system has %d failing test(s)." % failed)


func _run_tests() -> void:
	_test_static_data()
	_test_new_game_house()
	_test_slot_and_age_rules()
	_test_employment_independence()
	_test_performance_and_importance()
	_test_score_status_and_perks()
	_test_unhoused_penalty()
	_test_removal_upgrade_death_and_save()
	_test_purchase_and_monthly_expense()


func _save_state() -> void:
	saved_characters = CharacterManager.characters.duplicate(true)
	saved_houses = HouseManager.houses.duplicate(true)
	saved_businesses = BusinessManager.businesses.duplicate(true)
	saved_money = GameManager.family_money
	saved_date = Vector3i(TimeManager.current_day, TimeManager.current_month, TimeManager.current_year)
	saved_penalty_date = HouseManager.last_unhoused_penalty_date
	saved_house_payment_date = EconomyManager.last_house_payment_date


func _restore_state() -> void:
	CharacterManager.characters = saved_characters
	HouseManager.houses = saved_houses
	BusinessManager.businesses = saved_businesses
	GameManager.family_money = saved_money
	TimeManager.current_day = saved_date.x
	TimeManager.current_month = saved_date.y
	TimeManager.current_year = saved_date.z
	HouseManager.last_unhoused_penalty_date = saved_penalty_date
	EconomyManager.last_house_payment_date = saved_house_payment_date


func _reset() -> void:
	CharacterManager.characters = []
	HouseManager.houses = []
	HouseManager.next_house_instance_number = 1
	HouseManager.last_unhoused_penalty_date = ""
	BusinessManager.businesses = []
	GameManager.family_money = 1000000
	TimeManager.current_day = 15
	TimeManager.current_month = 3
	TimeManager.current_year = 1985
	EconomyManager.last_house_payment_date = ""


func _character(id: int, stage: String = "adult", score: int = 50, flags: Array = []) -> Dictionary:
	var result := {
		"character_id": id, "first_name": "Person %d" % id,
		"is_alive": true, "is_player_family": true, "life_stage": stage,
		"logic": score, "health": score, "social": score, "confidence": score,
		"discipline": score, "creativity": score, "attractiveness": score,
		"happiness": 50, "flag_ids": flags.duplicate(),
		"job_id": 2001, "company_id": "company", "salary": 5000
	}
	CharacterManager.characters.append(result)
	return result


func _house_with_head(head_id: int = 1) -> Dictionary:
	var roles := {"head_of_household": head_id, "cook": null, "housekeeper": null, "caregiver": null}
	var state := {"houses": [{
		"house_instance_id": "house_0001", "house_definition_id": "family_house",
		"property_id": "house_01", "level": 1,
		"role_assignments": roles, "resident_character_ids": []
	}], "next_house_instance_number": 2}
	HouseManager.restore_save_state(state)
	return HouseManager.get_house_by_instance_id("house_0001")


func _test_static_data() -> void:
	_reset()
	_assert(HouseManager.house_definitions.size() == 1, "House definition loads")
	var capacities: Array[int] = []
	var upgrades: Array[int] = []
	var expenses: Array[int] = []
	for level in range(1, 6):
		var data := HouseManager.get_level_definition(level)
		capacities.append(int(data.get("capacity", 0)))
		expenses.append(int(data.get("fixed_monthly_expense", 0)))
		if level > 1: upgrades.append(int(data.get("upgrade_price", 0)))
	_assert(capacities == [5, 10, 15, 20, 25], "Capacities are 5/10/15/20/25")
	_assert(upgrades == [35000, 50000, 70000, 100000], "Upgrade prices are canonical")
	_assert(expenses == [1000, 2000, 3000, 4000, 5000], "Monthly expenses are canonical")
	_assert(int(HouseManager.get_level_definition(1).get("ready_made_purchase_price", 0)) == 25000, "Ready-made L1 price is 25,000")
	_assert(HouseManager.get_house_acquisition_cost(true) == 35000, "New House construction uses the shared 1.40 multiplier")


func _test_new_game_house() -> void:
	_reset()
	var head := _character(1, "young_adult")
	GameManager.family_name = ""
	GameManager.new_game_started.emit(head)
	_assert(HouseManager.houses.size() == 1, "New game grants exactly one House")
	var house := HouseManager.houses[0] as Dictionary
	_assert(str(house.get("property_id", "")) == "house_01" and int(house.get("level", 0)) == 1, "Starting House is house_01 at Level 1")
	_assert(HouseManager.get_role_character_id(str(house.get("house_instance_id", "")), "head_of_household") == 1, "Starting Character is Head of Household")
	_assert(HouseManager.get_house_occupancy(str(house.get("house_instance_id", ""))) == 1, "Starting Character occupies exactly one slot")


func _test_slot_and_age_rules() -> void:
	_reset(); _character(1); _house_with_head()
	var baby := _character(2, "baby")
	var child := _character(3, "child")
	var teen := _character(4, "teen")
	var young := _character(5, "young_adult")
	var adult := _character(6, "adult")
	var elder := _character(7, "elder")
	_assert(not HouseManager.assign_character_to_role("house_0001", "cook", int(baby.character_id)), "Baby cannot hold a role")
	_assert(not HouseManager.assign_character_to_role("house_0001", "cook", int(child.character_id)), "Child cannot hold a role")
	_assert(not HouseManager.assign_character_to_role("house_0001", "cook", int(teen.character_id)), "Teen cannot hold a role")
	_assert(HouseManager.assign_character_to_role("house_0001", "cook", int(young.character_id)), "Young Adult can hold a role")
	_assert(HouseManager.assign_character_to_role("house_0001", "housekeeper", int(adult.character_id)), "Adult can hold a role")
	_assert(HouseManager.assign_character_to_role("house_0001", "caregiver", int(elder.character_id)), "Elder can hold a role")
	_assert(not HouseManager.assign_character_as_resident("house_0001", 5), "Role occupant cannot also become resident")
	_assert(not HouseManager.assign_character_to_role("house_0001", "head_of_household", 5), "One Character cannot hold multiple roles")


func _test_employment_independence() -> void:
	_reset(); _character(1); var worker := _character(2); _house_with_head()
	BusinessManager.businesses = [{"business_instance_id": "business_test", "business_type_id": "cafe", "plot_id": "cafe_test", "level": 1, "slots": [{"slot_id": "manager_01", "assigned_character_id": 2, "assigned_npc_id": null}]}]
	_assert(HouseManager.assign_character_to_role("house_0001", "cook", 2), "Business worker can also take a House role")
	_assert(int(worker.get("job_id", 0)) == 2001 and str(worker.get("company_id", "")) == "company" and int(worker.get("salary", 0)) == 5000, "House role preserves external employment")
	_assert(int(BusinessManager.businesses[0].slots[0].assigned_character_id) == 2, "House role preserves family-business employment")


func _test_performance_and_importance() -> void:
	_reset(); var head := _character(1, "adult", 80); _house_with_head()
	head.health = 40; head.creativity = 40
	_assert(HouseManager.get_role_performance_tier(1, "head_of_household") == "A" and HouseManager.get_role_performance_tier(1, "cook") == "C", "Performance tier is role-relative")
	_assert(HouseManager.is_role_important("house_0001", "head_of_household"), "Head is always score-important")
	_assert(not HouseManager.is_role_important("house_0001", "cook"), "Cook is not important at one occupant")
	var cook := _character(2, "adult", 90); HouseManager.assign_character_to_role("house_0001", "cook", 2)
	_assert(HouseManager.is_role_important("house_0001", "cook"), "Cook becomes important at two occupants")
	_assert(not HouseManager.is_role_important("house_0001", "housekeeper"), "Housekeeper is not important at two occupants")
	var housekeeper := _character(3, "adult", 90); HouseManager.assign_character_to_role("house_0001", "housekeeper", 3)
	_assert(HouseManager.is_role_important("house_0001", "housekeeper"), "Housekeeper becomes important at three occupants")
	var fourth := _character(4, "adult"); HouseManager.assign_character_as_resident("house_0001", 4)
	_assert(not HouseManager.is_role_important("house_0001", "caregiver"), "Caregiver stays inactive without Baby or Child")
	var baby := _character(5, "baby"); HouseManager.assign_character_as_resident("house_0001", 5)
	_assert(HouseManager.is_role_important("house_0001", "caregiver"), "Caregiver follows adult-count plus Baby/Child rule")
	_reset(); _character(1, "adult", 50); _house_with_head(); _character(2, "adult", 100); HouseManager.assign_character_to_role("house_0001", "cook", 2)
	_assert(is_equal_approx(HouseManager.get_household_score("house_0001"), 56.0), "Secondary important role uses 50 percent before five occupants")
	for id in range(3, 6): _character(id, "adult", 50); HouseManager.assign_character_as_resident("house_0001", id)
	_assert(is_equal_approx(HouseManager.get_household_score("house_0001"), 52.0), "Full role contribution applies from five occupants")


func _test_score_status_and_perks() -> void:
	_reset(); var head := _character(1, "adult", 50, [1002]); _house_with_head()
	_assert(is_equal_approx(HouseManager.get_household_score("house_0001"), 50.0), "Non-important empty roles contribute zero")
	var perks := HouseManager.get_active_household_perks("house_0001")
	_assert(perks.size() == 1 and str(perks[0].perk_id) == "artistic", "Head flags resolve Artistic perk")
	_assert(HouseManager.get_active_household_perk_ids("house_0001") == ["artistic"], "Future event code can query active perk IDs")
	var replacement := _character(2, "adult", 50, [])
	HouseManager.assign_character_to_role("house_0001", "head_of_household", 2)
	_assert(HouseManager.get_active_household_perks("house_0001").is_empty(), "Changing Head recalculates perks")
	var config: Dictionary = HouseManager.get_house_definition().household_score
	var original_baseline = config.baseline
	for pair in [[95, "orderly"], [80, "harmonious"], [65, "stable"], [45, "neutral"], [20, "chaotic"]]:
		config.baseline = pair[0]
		_assert(str(HouseManager.get_household_status("house_0001").status_id) == pair[1], "Status threshold returns %s" % pair[1])
	config.baseline = -100
	_assert(is_equal_approx(HouseManager.get_household_score("house_0001"), 0.0), "Household Score clamps at zero")
	config.baseline = 200
	_assert(is_equal_approx(HouseManager.get_household_score("house_0001"), 100.0), "Household Score clamps at one hundred")
	config.baseline = original_baseline


func _test_unhoused_penalty() -> void:
	_reset(); _character(1); _house_with_head(); var unhoused := _character(2)
	TimeManager.current_day = 1
	_assert(HouseManager.apply_monthly_unhoused_penalties() and int(unhoused.happiness) == 48, "Unhoused Character loses exactly 2 Happiness")
	HouseManager.apply_monthly_unhoused_penalties()
	_assert(int(unhoused.happiness) == 48, "Unhoused penalty cannot duplicate on the same date")
	HouseManager.assign_character_as_resident("house_0001", 2)
	TimeManager.current_month = 4; HouseManager.apply_monthly_unhoused_penalties()
	_assert(int(unhoused.happiness) == 48, "Housed Character stops future penalty")
	_assert(int(unhoused.happiness) != 50, "Rehousing does not restore lost Happiness")


func _test_removal_upgrade_death_and_save() -> void:
	_reset(); _character(1); _character(2); _house_with_head(); HouseManager.assign_character_to_role("house_0001", "cook", 2)
	HouseManager.remove_character_from_house(2)
	_assert(HouseManager.get_character_assignment(2).is_empty() and HouseManager.get_house_by_instance_id("house_0001").resident_character_ids.is_empty(), "Role removal does not auto-create resident assignment")
	_assert(HouseManager.is_character_unhoused(2), "Remove from House creates Unhoused state")
	HouseManager.assign_character_as_resident("house_0001", 2)
	var before := HouseManager.get_house_occupancy("house_0001")
	GameManager.family_money = 100000
	_assert(HouseManager.upgrade_house("house_0001") and HouseManager.get_house_capacity("house_0001") == 10 and HouseManager.get_house_occupancy("house_0001") == before, "Upgrade preserves occupants and adds capacity")
	CharacterManager.kill_character(CharacterManager.get_character_by_id(2))
	_assert(HouseManager.get_character_assignment(2).is_empty(), "Death removes Character from House slot")
	var save_state := HouseManager.create_save_state()
	HouseManager.houses = []
	HouseManager.restore_save_state(save_state)
	_assert(HouseManager.get_house_on_property("house_01").level == 2 and HouseManager.get_role_character_id("house_0001", "head_of_household") == 1, "Save/load preserves ownership, level, and assignments")


func _test_purchase_and_monthly_expense() -> void:
	_reset(); _character(1); _house_with_head()
	GameManager.family_money = 100000
	var purchased := HouseManager.purchase_ready_made_house("house_02")
	_assert(not purchased.is_empty() and GameManager.family_money == 75000, "Ready-made House purchase deducts 25,000 once")
	_assert(HouseManager.purchase_ready_made_house("house_02").is_empty() and GameManager.family_money == 75000, "Owned House property cannot be purchased twice")
	TimeManager.current_day = 1
	EconomyManager.last_house_payment_date = ""
	_assert(EconomyManager.settle_houses() and GameManager.family_money == 73000, "Owned House expenses settle in monthly economy cycle")
	_assert(not EconomyManager.settle_houses() and GameManager.family_money == 73000, "House expense cannot duplicate on the same date")


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", message)
	else:
		failed += 1
		push_error("[FAIL] " + message)
