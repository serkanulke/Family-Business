extends Node


const NPC_MANAGER_SCRIPT := preload("res://Autoload/NPCManager.gd")

var passed: int = 0
var failed: int = 0

var npc_manager: Node
var created_test_npc_manager: bool = false

var saved_businesses: Array = []
var saved_characters: Array = []
var saved_worker_npcs: Array = []
var saved_generation_config: Dictionary = {}

var saved_day: int
var saved_month: int
var saved_year: int


func _ready() -> void:
	if has_node("/root/NPCManager"):
		npc_manager = get_node("/root/NPCManager")
	else:
		await get_tree().process_frame

		npc_manager = NPC_MANAGER_SCRIPT.new()
		npc_manager.name = "NPCManager"
		get_tree().root.add_child(npc_manager)
		created_test_npc_manager = true

	print("")
	print("========================================")
	print("Worker assignment flow tests starting")
	print("========================================")

	_save_state()
	_run_tests()
	_restore_state()

	print("")
	print("========================================")
	print(
		"Worker assignment flow tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print("ALL WORKER ASSIGNMENT FLOW TESTS PASSED.")
	else:
		push_error(
			"Worker assignment flow has %d failing test(s)."
			% failed
		)


func _save_state() -> void:
	saved_businesses = BusinessManager.businesses.duplicate(true)
	saved_characters = CharacterManager.characters.duplicate(true)
	saved_worker_npcs = npc_manager.worker_npcs.duplicate(true)
	saved_generation_config = npc_manager.generation_config.duplicate(true)

	saved_day = TimeManager.current_day
	saved_month = TimeManager.current_month
	saved_year = TimeManager.current_year


func _restore_state() -> void:
	BusinessManager.businesses = saved_businesses
	CharacterManager.characters = saved_characters
	npc_manager.worker_npcs = saved_worker_npcs
	npc_manager.generation_config = saved_generation_config

	TimeManager.current_day = saved_day
	TimeManager.current_month = saved_month
	TimeManager.current_year = saved_year

	if created_test_npc_manager:
		npc_manager.queue_free()


func _run_tests() -> void:
	_test_assign_family_to_empty_slot()
	_test_assign_npc_to_empty_slot()
	_test_replace_family_with_npc()
	_test_replace_npc_with_family()
	_test_invalid_npc_does_not_remove_current_family_worker()
	_test_invalid_family_member_does_not_remove_current_npc_worker()
	_test_external_job_is_only_cleared_after_real_family_assignment()


func _assert_true(
	condition: bool,
	test_name: String
) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)


func _make_character(
	character_id: int,
	logic: int = 90,
	health: int = 90,
	is_alive: bool = true,
	is_retired: bool = false,
	job_id_value = null
) -> Dictionary:
	var character: Dictionary = {
		"character_id": character_id,
		"first_name": "Family",
		"last_name": "Member%d" % character_id,
		"gender": "male",
		"birth_date": "1955-01-01",
		"life_stage": "young_adult",
		"is_alive": is_alive,
		"is_retired": is_retired,
		"is_player_family": true,
		"job_id": job_id_value,
		"company_id": null,
		"salary": 0,
		"avatar_theme": "",
		"genetics": {
			"hair_color": "brown",
			"skin_tone": "light",
			"eye_color": "blue"
		},
		"health": health,
		"happiness": 50,
		"logic": logic,
		"attractiveness": 50,
		"social": 50,
		"confidence": 50,
		"discipline": 50,
		"creativity": 50,
		"unemployment_start_date": null,
		"job_offer_cooldown_until": null
	}

	if job_id_value != null:
		character["company_id"] = 1001
		character["salary"] = 5000

	return character


func _make_worker(
	npc_id: String,
	logic: int = 90,
	health: int = 90,
	is_retired: bool = false
) -> Dictionary:
	return {
		"id": npc_id,
		"first_name": "NPC",
		"last_name": npc_id,
		"gender": "male",
		"birth_date": "1955-01-01",
		"portrait_path": "",
		"stats": {
			"health": health,
			"logic": logic,
			"discipline": 50,
			"creativity": 50,
			"social": 50,
			"confidence": 50,
			"attractiveness": 50,
			"happiness": 50
		},
		"is_retired": is_retired
	}


func _make_hospital(
	assigned_character_id_value = null,
	assigned_npc_id_value = null
) -> Dictionary:
	return {
		"business_instance_id": "business_test_001",
		"business_type_id": "hospital",
		"visual_variant_id": "",
		"plot_id": "plot_test_001",
		"level": 1,
		"slots": [
			{
				"slot_id": "doctor_01",
				"assigned_character_id": assigned_character_id_value,
				"assigned_npc_id": assigned_npc_id_value
			},
			{
				"slot_id": "nurse_01",
				"assigned_character_id": null,
				"assigned_npc_id": null
			},
			{
				"slot_id": "cleaner_01",
				"assigned_character_id": null,
				"assigned_npc_id": null
			}
		]
	}


func _reset_world() -> void:
	TimeManager.current_day = 1
	TimeManager.current_month = 1
	TimeManager.current_year = 1985

	BusinessManager.businesses = [
		_make_hospital()
	]

	CharacterManager.characters = [
		_make_character(1),
		_make_character(2)
	]

	npc_manager.worker_npcs = [
		_make_worker("npc_test_001"),
		_make_worker("npc_test_002")
	]

	npc_manager.generation_config["retirement_age"] = 65


func _test_assign_family_to_empty_slot() -> void:
	_reset_world()

	var success: bool = BusinessManager.replace_slot_with_character(
		"business_test_001",
		"doctor_01",
		1
	)

	var slot: Dictionary = BusinessManager.get_slot(
		"business_test_001",
		"doctor_01"
	)

	_assert_true(
		success
		and int(slot.get("assigned_character_id", 0)) == 1
		and slot.get("assigned_npc_id", null) == null,
		"Family Member can be assigned through the shared flow to an empty slot"
	)


func _test_assign_npc_to_empty_slot() -> void:
	_reset_world()

	var success: bool = BusinessManager.replace_slot_with_npc(
		"business_test_001",
		"doctor_01",
		"npc_test_001"
	)

	var slot: Dictionary = BusinessManager.get_slot(
		"business_test_001",
		"doctor_01"
	)

	_assert_true(
		success
		and str(slot.get("assigned_npc_id", "")) == "npc_test_001"
		and slot.get("assigned_character_id", null) == null,
		"Worker NPC can be assigned through the shared flow to an empty slot"
	)


func _test_replace_family_with_npc() -> void:
	_reset_world()

	BusinessManager.businesses = [
		_make_hospital(
			1,
			null
		)
	]

	var success: bool = BusinessManager.replace_slot_with_npc(
		"business_test_001",
		"doctor_01",
		"npc_test_001"
	)

	var slot: Dictionary = BusinessManager.get_slot(
		"business_test_001",
		"doctor_01"
	)

	var old_character: Dictionary = CareerManager.get_character_by_id(
		1
	)

	_assert_true(
		success
		and slot.get("assigned_character_id", null) == null
		and str(slot.get("assigned_npc_id", "")) == "npc_test_001"
		and old_character.get("unemployment_start_date", null) != null,
		"Replace safely changes Family Member to Worker NPC"
	)


func _test_replace_npc_with_family() -> void:
	_reset_world()

	BusinessManager.businesses = [
		_make_hospital(
			null,
			"npc_test_001"
		)
	]

	var success: bool = BusinessManager.replace_slot_with_character(
		"business_test_001",
		"doctor_01",
		1
	)

	var slot: Dictionary = BusinessManager.get_slot(
		"business_test_001",
		"doctor_01"
	)

	_assert_true(
		success
		and int(slot.get("assigned_character_id", 0)) == 1
		and slot.get("assigned_npc_id", null) == null
		and npc_manager.is_worker_available(
			npc_manager.get_worker_npc_by_id(
				"npc_test_001"
			)
		),
		"Replace safely changes Worker NPC to Family Member"
	)


func _test_invalid_npc_does_not_remove_current_family_worker() -> void:
	_reset_world()

	BusinessManager.businesses = [
		_make_hospital(
			1,
			null
		)
	]

	var success: bool = BusinessManager.replace_slot_with_npc(
		"business_test_001",
		"doctor_01",
		"npc_missing"
	)

	var slot: Dictionary = BusinessManager.get_slot(
		"business_test_001",
		"doctor_01"
	)

	_assert_true(
		not success
		and int(slot.get("assigned_character_id", 0)) == 1
		and slot.get("assigned_npc_id", null) == null,
		"Invalid NPC candidate does not remove the current Family Member"
	)


func _test_invalid_family_member_does_not_remove_current_npc_worker() -> void:
	_reset_world()

	BusinessManager.businesses = [
		_make_hospital(
			null,
			"npc_test_001"
		)
	]

	var success: bool = BusinessManager.replace_slot_with_character(
		"business_test_001",
		"doctor_01",
		999999
	)

	var slot: Dictionary = BusinessManager.get_slot(
		"business_test_001",
		"doctor_01"
	)

	_assert_true(
		not success
		and slot.get("assigned_character_id", null) == null
		and str(slot.get("assigned_npc_id", "")) == "npc_test_001",
		"Invalid Family Member candidate does not remove the current Worker NPC"
	)


func _test_external_job_is_only_cleared_after_real_family_assignment() -> void:
	_reset_world()

	var external_character: Dictionary = _make_character(
		3,
		90,
		90,
		true,
		false,
		2001
	)

	CharacterManager.characters.append(
		external_character
	)

	var candidates: Array = BusinessManager.get_family_candidates_for_slot(
		"hospital",
		"doctor_01"
	)

	var still_employed_before_assignment: bool = (
		external_character.get("job_id", null) == 2001
		and external_character.get("company_id", null) == 1001
		and int(external_character.get("salary", 0)) == 5000
	)

	var appears_in_list: bool = false

	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = candidate_value

		if int(candidate.get("character_id", 0)) == 3:
			appears_in_list = true
			break

	var success: bool = BusinessManager.assign_character_to_slot(
		"business_test_001",
		"doctor_01",
		3
	)

	var cleared_after_assignment: bool = (
		external_character.get("job_id", null) == null
		and external_character.get("company_id", null) == null
		and int(external_character.get("salary", -1)) == 0
	)

	_assert_true(
		still_employed_before_assignment
		and appears_in_list
		and success
		and cleared_after_assignment,
		"Opening/listing Family candidates keeps external job until actual assignment"
	)
