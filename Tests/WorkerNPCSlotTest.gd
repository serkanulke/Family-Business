extends Node


const NPC_MANAGER_SCRIPT := preload("res://Autoload/NPCManager.gd")

var passed: int = 0
var failed: int = 0

var npc_manager: Node
var created_test_npc_manager: bool = false

var saved_businesses: Array = []
var saved_worker_npcs: Array = []
var saved_generation_config: Dictionary = {}


func _ready() -> void:
	if has_node("/root/NPCManager"):
		npc_manager = get_node("/root/NPCManager")
	else:
		# During _ready(), the root can still be busy adding scene children.
		# Wait one frame before attaching the temporary test singleton.
		await get_tree().process_frame

		npc_manager = NPC_MANAGER_SCRIPT.new()
		npc_manager.name = "NPCManager"
		get_tree().root.add_child(npc_manager)
		created_test_npc_manager = true

	print("")
	print("========================================")
	print("Worker NPC slot assignment tests starting")
	print("========================================")

	_save_state()
	_run_tests()
	_restore_state()

	print("")
	print("========================================")
	print(
		"Worker NPC slot tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print("ALL WORKER NPC SLOT TESTS PASSED.")
	else:
		push_error(
			"Worker NPC slot assignment has %d failing test(s)."
			% failed
		)


func _save_state() -> void:
	saved_businesses = BusinessManager.businesses.duplicate(true)
	saved_worker_npcs = npc_manager.worker_npcs.duplicate(true)
	saved_generation_config = npc_manager.generation_config.duplicate(true)


func _restore_state() -> void:
	BusinessManager.businesses = saved_businesses
	npc_manager.worker_npcs = saved_worker_npcs
	npc_manager.generation_config = saved_generation_config

	if created_test_npc_manager:
		npc_manager.queue_free()


func _run_tests() -> void:
	_test_assign_npc_to_empty_slot()
	_test_same_npc_cannot_be_assigned_twice()
	_test_npc_cannot_enter_family_occupied_slot()
	_test_family_cannot_enter_npc_occupied_slot()
	_test_remove_npc_makes_available_again()
	_test_npc_contributes_to_business_gross()
	_test_low_stat_npc_can_be_assigned()


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


func _make_worker(
	npc_id: String,
	logic: int,
	health: int
) -> Dictionary:
	return {
		"id": npc_id,
		"first_name": "Test",
		"last_name": "Worker",
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
		"is_retired": false
	}


func _make_hospital() -> Dictionary:
	return {
		"business_instance_id": "business_test_001",
		"business_type_id": "hospital",
		"plot_id": "plot_test_001",
		"level": 1,
		"slots": [
			{
				"slot_id": "doctor_01",
				"assigned_character_id": null,
				"assigned_npc_id": null
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
	BusinessManager.businesses = [
		_make_hospital()
	]

	npc_manager.worker_npcs = [
		_make_worker(
			"npc_test_001",
			90,
			90
		),
		_make_worker(
			"npc_test_002",
			70,
			70
		),
		_make_worker(
			"npc_test_low",
			10,
			10
		)
	]


func _test_assign_npc_to_empty_slot() -> void:
	_reset_world()

	var success: bool = BusinessManager.assign_npc_to_slot(
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
		and str(
			slot.get(
				"assigned_npc_id",
				""
			)
		) == "npc_test_001",
		"Worker NPC can be assigned to an empty business slot"
	)


func _test_same_npc_cannot_be_assigned_twice() -> void:
	_reset_world()

	var first_success: bool = BusinessManager.assign_npc_to_slot(
		"business_test_001",
		"doctor_01",
		"npc_test_001"
	)

	var second_success: bool = BusinessManager.assign_npc_to_slot(
		"business_test_001",
		"nurse_01",
		"npc_test_001"
	)

	_assert_true(
		first_success
		and not second_success,
		"The same Worker NPC cannot occupy two slots at once"
	)


func _test_npc_cannot_enter_family_occupied_slot() -> void:
	_reset_world()

	var slot: Dictionary = BusinessManager.get_slot(
		"business_test_001",
		"doctor_01"
	)

	slot["assigned_character_id"] = 999

	var success: bool = BusinessManager.assign_npc_to_slot(
		"business_test_001",
		"doctor_01",
		"npc_test_001"
	)

	_assert_true(
		not success
		and slot.get(
			"assigned_npc_id",
			null
		) == null,
		"Worker NPC cannot be assigned to a family-character occupied slot"
	)


func _test_family_cannot_enter_npc_occupied_slot() -> void:
	_reset_world()

	var npc_success: bool = BusinessManager.assign_npc_to_slot(
		"business_test_001",
		"doctor_01",
		"npc_test_001"
	)

	var slot: Dictionary = BusinessManager.get_slot(
		"business_test_001",
		"doctor_01"
	)

	var occupied_by_npc: bool = (
		slot.get(
			"assigned_npc_id",
			null
		) != null
	)

	_assert_true(
		npc_success
		and occupied_by_npc
		and slot.get(
			"assigned_character_id",
			null
		) == null,
		"NPC occupation remains separate from family-character occupation"
	)


func _test_remove_npc_makes_available_again() -> void:
	_reset_world()

	var assign_success: bool = BusinessManager.assign_npc_to_slot(
		"business_test_001",
		"doctor_01",
		"npc_test_001"
	)

	var unavailable_while_assigned: bool = not npc_manager.is_worker_available(
		npc_manager.get_worker_npc_by_id(
			"npc_test_001"
		)
	)

	var remove_success: bool = BusinessManager.remove_npc_from_slot(
		"business_test_001",
		"doctor_01"
	)

	var available_after_removal: bool = npc_manager.is_worker_available(
		npc_manager.get_worker_npc_by_id(
			"npc_test_001"
		)
	)

	_assert_true(
		assign_success
		and unavailable_while_assigned
		and remove_success
		and available_after_removal,
		"Removed Worker NPC is not deleted and becomes available again"
	)


func _test_npc_contributes_to_business_gross() -> void:
	_reset_world()

	var assign_success: bool = BusinessManager.assign_npc_to_slot(
		"business_test_001",
		"doctor_01",
		"npc_test_001"
	)

	var gross: int = BusinessManager.get_business_slot_gross(
		"business_test_001",
		"doctor_01"
	)

	_assert_true(
		assign_success
		and gross == 8000,
		"S-tier Worker NPC contributes full slot gross income"
	)


func _test_low_stat_npc_can_be_assigned() -> void:
	_reset_world()

	var assign_success: bool = BusinessManager.assign_npc_to_slot(
		"business_test_001",
		"doctor_01",
		"npc_test_low"
	)

	var gross: int = BusinessManager.get_business_slot_gross(
		"business_test_001",
		"doctor_01"
	)

	_assert_true(
		assign_success
		and gross == 3200,
		"Low-stat Worker NPC can be assigned and contributes D-tier gross"
	)
