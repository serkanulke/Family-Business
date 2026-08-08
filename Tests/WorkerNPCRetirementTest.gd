extends Node


const NPC_MANAGER_SCRIPT := preload("res://Autoload/NPCManager.gd")

var passed: int = 0
var failed: int = 0

var npc_manager: Node
var created_test_npc_manager: bool = false

var saved_businesses: Array = []
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
	print("Worker NPC retirement cleanup tests starting")
	print("========================================")

	_save_state()
	_run_tests()
	_restore_state()

	print("")
	print("========================================")
	print(
		"Worker NPC retirement cleanup tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print("ALL WORKER NPC RETIREMENT CLEANUP TESTS PASSED.")
	else:
		push_error(
			"Worker NPC retirement cleanup has %d failing test(s)."
			% failed
		)


func _save_state() -> void:
	saved_businesses = BusinessManager.businesses.duplicate(true)
	saved_worker_npcs = npc_manager.worker_npcs.duplicate(true)
	saved_generation_config = npc_manager.generation_config.duplicate(true)

	saved_day = TimeManager.current_day
	saved_month = TimeManager.current_month
	saved_year = TimeManager.current_year


func _restore_state() -> void:
	BusinessManager.businesses = saved_businesses
	npc_manager.worker_npcs = saved_worker_npcs
	npc_manager.generation_config = saved_generation_config

	TimeManager.current_day = saved_day
	TimeManager.current_month = saved_month
	TimeManager.current_year = saved_year

	if created_test_npc_manager:
		npc_manager.queue_free()


func _run_tests() -> void:
	_test_64_year_old_worker_stays_assigned()
	_test_65_year_old_worker_is_removed_from_slot()
	_test_retired_worker_record_is_preserved()
	_test_retired_worker_is_not_available()
	_test_retired_worker_cannot_be_reassigned()
	_test_retirement_frees_slot_for_another_worker()
	_test_retirement_stops_business_income_from_retired_worker()


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
	age: int,
	logic: int = 90,
	health: int = 90
) -> Dictionary:
	var birth_year: int = (
		TimeManager.current_year - age
	)

	return {
		"id": npc_id,
		"first_name": "Test",
		"last_name": "Worker",
		"gender": "male",
		"birth_date": "%04d-01-01" % birth_year,
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


func _make_hospital(
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
				"assigned_character_id": null,
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

	npc_manager.generation_config["retirement_age"] = 65

	BusinessManager.businesses = [
		_make_hospital()
	]

	npc_manager.worker_npcs = []


func _test_64_year_old_worker_stays_assigned() -> void:
	_reset_world()

	var worker: Dictionary = _make_worker(
		"npc_64",
		64
	)

	npc_manager.worker_npcs = [worker]

	var assign_success: bool = BusinessManager.assign_npc_to_slot(
		"business_test_001",
		"doctor_01",
		"npc_64"
	)

	npc_manager._process_retirements()

	var slot: Dictionary = BusinessManager.get_slot(
		"business_test_001",
		"doctor_01"
	)

	_assert_true(
		assign_success
		and str(
			slot.get(
				"assigned_npc_id",
				""
			)
		) == "npc_64"
		and not bool(
			worker.get(
				"is_retired",
				false
			)
		),
		"64-year-old Worker NPC remains assigned and active"
	)


func _test_65_year_old_worker_is_removed_from_slot() -> void:
	_reset_world()

	var worker: Dictionary = _make_worker(
		"npc_65",
		65
	)

	npc_manager.worker_npcs = [worker]

	BusinessManager.businesses = [
		_make_hospital(
			"npc_65"
		)
	]

	npc_manager._process_retirements()

	var slot: Dictionary = BusinessManager.get_slot(
		"business_test_001",
		"doctor_01"
	)

	_assert_true(
		slot.get(
			"assigned_npc_id",
			null
		) == null
		and bool(
			worker.get(
				"is_retired",
				false
			)
		),
		"65-year-old Worker NPC is removed from active business slot"
	)


func _test_retired_worker_record_is_preserved() -> void:
	_reset_world()

	var worker: Dictionary = _make_worker(
		"npc_preserved",
		65
	)

	npc_manager.worker_npcs = [worker]

	BusinessManager.businesses = [
		_make_hospital(
			"npc_preserved"
		)
	]

	npc_manager._process_retirements()

	var stored_worker: Dictionary = (
		npc_manager.get_worker_npc_by_id(
			"npc_preserved"
		)
	)

	_assert_true(
		not stored_worker.is_empty()
		and bool(
			stored_worker.get(
				"is_retired",
				false
			)
		),
		"Retired Worker NPC record is preserved instead of deleted"
	)


func _test_retired_worker_is_not_available() -> void:
	_reset_world()

	var worker: Dictionary = _make_worker(
		"npc_unavailable",
		65
	)

	npc_manager.worker_npcs = [worker]

	npc_manager._process_retirements()

	_assert_true(
		not npc_manager.is_worker_available(
			worker
		)
		and npc_manager.get_available_worker_npcs().is_empty(),
		"Retired Worker NPC does not return to the available candidate pool"
	)


func _test_retired_worker_cannot_be_reassigned() -> void:
	_reset_world()

	var worker: Dictionary = _make_worker(
		"npc_no_reassign",
		65
	)

	npc_manager.worker_npcs = [worker]

	npc_manager._process_retirements()

	var assign_success: bool = BusinessManager.assign_npc_to_slot(
		"business_test_001",
		"doctor_01",
		"npc_no_reassign"
	)

	_assert_true(
		not assign_success,
		"Retired Worker NPC cannot be assigned to a business slot again"
	)


func _test_retirement_frees_slot_for_another_worker() -> void:
	_reset_world()

	var retiring_worker: Dictionary = _make_worker(
		"npc_retiring",
		65
	)

	var replacement_worker: Dictionary = _make_worker(
		"npc_replacement",
		40
	)

	npc_manager.worker_npcs = [
		retiring_worker,
		replacement_worker
	]

	BusinessManager.businesses = [
		_make_hospital(
			"npc_retiring"
		)
	]

	npc_manager._process_retirements()

	var replacement_success: bool = BusinessManager.assign_npc_to_slot(
		"business_test_001",
		"doctor_01",
		"npc_replacement"
	)

	var slot: Dictionary = BusinessManager.get_slot(
		"business_test_001",
		"doctor_01"
	)

	_assert_true(
		replacement_success
		and str(
			slot.get(
				"assigned_npc_id",
				""
			)
		) == "npc_replacement",
		"Retirement frees the business slot for another Worker NPC"
	)


func _test_retirement_stops_business_income_from_retired_worker() -> void:
	_reset_world()

	var worker: Dictionary = _make_worker(
		"npc_income",
		65
	)

	npc_manager.worker_npcs = [worker]

	BusinessManager.businesses = [
		_make_hospital(
			"npc_income"
		)
	]

	var gross_before_cleanup: int = BusinessManager.get_business_slot_gross(
		"business_test_001",
		"doctor_01"
	)

	npc_manager._process_retirements()

	var gross_after_cleanup: int = BusinessManager.get_business_slot_gross(
		"business_test_001",
		"doctor_01"
	)

	_assert_true(
		gross_before_cleanup == 8000
		and gross_after_cleanup == 0,
		"Retirement cleanup removes the retired Worker NPC's business income"
	)
