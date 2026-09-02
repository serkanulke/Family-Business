extends Node


var passed := 0
var failed := 0
var original_snapshot: Dictionary = {}
var original_save_id := -1


func _ready() -> void:
	original_snapshot = SaveManager.create_save_snapshot()
	original_save_id = SaveManager.current_save_id
	SaveManager.current_save_id = -1

	_test_assigned_character_retires_and_leaves_slot()
	_test_unassigned_character_retires_normally()
	_test_underage_character_is_unchanged()
	_test_repeated_normalization_is_idempotent()
	_test_load_normalization_restores_canonical_retirement()

	SaveManager.apply_save_snapshot(original_snapshot)
	SaveManager.current_save_id = original_save_id

	print("========================================")
	print("Character retirement Business cleanup tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_assigned_character_retires_and_leaves_slot() -> void:
	var retiree := _character(1, "1920-01-26", 12000)
	var colleague := _character(2, "1940-01-26", 0)
	_setup_world([retiree, colleague], _businesses_with_assignments())

	CharacterManager.update_all_retirements()

	_assert(bool(retiree.is_retired) and int(retiree.last_salary) == 12000 and int(retiree.pension) == 1200 and int(retiree.salary) == 0, "Age-65 assigned Character receives the canonical retirement state")
	_assert(BusinessManager.get_character_assignment(1).is_empty(), "Retirement removes the Character from the Family Business slot")
	var colleague_assignment := BusinessManager.get_character_assignment(2)
	_assert(String(colleague_assignment.get("slot_id", "")) == "slot_2", "Retirement preserves every unrelated Family Business slot")
	_assert(retiree.job_id == null and retiree.company_id == null and retiree.unemployment_start_date == "1985-01-26", "Existing Business removal API applies its canonical employment cleanup")


func _test_unassigned_character_retires_normally() -> void:
	var retiree := _character(3, "1920-01-26", 30000)
	_setup_world([retiree], [])

	CharacterManager.update_all_retirements()

	_assert(bool(retiree.is_retired) and int(retiree.last_salary) == 30000 and int(retiree.pension) == 2500 and int(retiree.salary) == 0, "Unassigned Character retirement preserves the salary cap and pension calculation")


func _test_underage_character_is_unchanged() -> void:
	var character := _character(1, "1920-01-27", 9000)
	_setup_world([character], _businesses_with_assignments())

	CharacterManager.update_all_retirements()

	_assert(not bool(character.is_retired) and int(character.salary) == 9000 and int(character.pension) == 0, "Character below age 65 does not retire")
	_assert(not BusinessManager.get_character_assignment(1).is_empty(), "Character below age 65 keeps the Family Business slot")


func _test_repeated_normalization_is_idempotent() -> void:
	var retiree := _character(1, "1920-01-26", 12000)
	_setup_world([retiree], _businesses_with_assignments())
	CharacterManager.update_all_retirements()
	var character_after_first := retiree.duplicate(true)
	var businesses_after_first := BusinessManager.businesses.duplicate(true)

	CharacterManager.update_all_retirements()

	_assert(retiree == character_after_first and BusinessManager.businesses == businesses_after_first, "Repeated retirement normalization performs no second mutation")


func _test_load_normalization_restores_canonical_retirement() -> void:
	var retiree := _character(1, "1920-01-26", 15000)
	_setup_world([retiree], _businesses_with_assignments())
	var snapshot = JSON.parse_string(JSON.stringify(SaveManager.create_save_snapshot()))

	CharacterManager.characters = []
	BusinessManager.businesses = []
	var loaded := SaveManager.apply_save_snapshot(snapshot)
	var restored := CharacterManager.get_character_by_id(1)

	_assert(loaded and bool(restored.get("is_retired", false)) and int(restored.get("last_salary", 0)) == 15000 and int(restored.get("pension", 0)) == 1500, "Load normalization applies canonical retirement to an eligible legacy state")
	_assert(BusinessManager.get_character_assignment(1).is_empty(), "Load normalization removes the restored retiree from the restored Business slot")
	var colleague_assignment := BusinessManager.get_character_assignment(2)
	_assert(String(colleague_assignment.get("slot_id", "")) == "slot_2", "Load normalization preserves unrelated restored Business assignments")


func _setup_world(characters: Array, businesses: Array) -> void:
	SaveManager.current_save_id = -1
	CharacterManager.characters = characters
	CharacterManager.next_character_id = 10
	BusinessManager.businesses = businesses
	CareerManager.active_job_offers.clear()
	TimeManager.current_year = 1985
	TimeManager.current_month = 1
	TimeManager.current_day = 26
	TimeManager.is_paused = true


func _businesses_with_assignments() -> Array:
	return [{
		"business_instance_id":"retirement_test_business",
		"slots":[
			{"slot_id":"slot_1","assigned_character_id":1,"assigned_npc_id":null},
			{"slot_id":"slot_2","assigned_character_id":2,"assigned_npc_id":null}
		]
	}]


func _character(character_id: int, birth_date: String, salary: int) -> Dictionary:
	return {
		"character_id":character_id,
		"character_type":"family",
		"linked_character_id":null,
		"first_name":"Retirement",
		"last_name":"Test",
		"gender":"female",
		"birth_date":birth_date,
		"life_stage":"elder" if character_id == 1 else "adult",
		"is_alive":true,
		"is_player_family":true,
		"parent_ids":[],
		"children_ids":[],
		"partner_id":null,
		"relationship_cooldown_until":null,
		"flag_ids":[],
		"health":100,
		"happiness":100,
		"logic":100,
		"attractiveness":100,
		"social":100,
		"confidence":100,
		"discipline":100,
		"creativity":100,
		"job_id":2076,
		"company_id":"retirement_test_company",
		"salary":salary,
		"school_id":null,
		"major_id":null,
		"education_status":"graduated",
		"education_start_date":null,
		"major_selection_date":null,
		"expected_graduation_date":null,
		"graduation_date":null,
		"unemployment_start_date":null,
		"job_offer_cooldown_until":null,
		"event_log":[],
		"is_retired":false,
		"last_salary":0,
		"pension":0,
		"avatar_theme":"default",
		"genetics":{"skin_tone":"light"},
		"portrait_variant_id":"",
		"portrait_path":"res://Resources/Characters/default_avatar.png"
	}


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", message)
	else:
		failed += 1
		push_error("[FAIL] " + message)
