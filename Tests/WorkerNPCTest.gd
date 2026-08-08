extends Node

var passed: int = 0
var failed: int = 0

const NPC_MANAGER_SCRIPT := preload("res://Autoload/NPCManager.gd")

var npc_manager: Node

var saved_worker_npcs: Array = []
var saved_next_worker_npc_number: int = 1
var saved_generation_config: Dictionary = {}
var saved_day: int
var saved_month: int
var saved_year: int


func _ready() -> void:
	if has_node("/root/NPCManager"):
		npc_manager = get_node("/root/NPCManager")
	else:
		npc_manager = NPC_MANAGER_SCRIPT.new()
		npc_manager.name = "NPCManagerTestInstance"
		add_child(npc_manager)

	print("")
	print("========================================")
	print("Worker NPC backend tests starting")
	print("========================================")

	_save_state()
	_run_tests()
	_restore_state()

	print("")
	print("========================================")
	print("Worker NPC tests: ", passed, " passed / ", failed, " failed")
	print("========================================")

	if failed == 0:
		print("ALL WORKER NPC TESTS PASSED.")
	else:
		push_error("Worker NPC backend has %d failing test(s)." % failed)


func _save_state() -> void:
	saved_worker_npcs = npc_manager.worker_npcs.duplicate(true)
	saved_next_worker_npc_number = npc_manager.next_worker_npc_number
	saved_generation_config = npc_manager.generation_config.duplicate(true)
	saved_day = TimeManager.current_day
	saved_month = TimeManager.current_month
	saved_year = TimeManager.current_year


func _restore_state() -> void:
	npc_manager.worker_npcs = saved_worker_npcs
	npc_manager.next_worker_npc_number = saved_next_worker_npc_number
	npc_manager.generation_config = saved_generation_config
	TimeManager.current_day = saved_day
	TimeManager.current_month = saved_month
	TimeManager.current_year = saved_year


func _reset_world() -> void:
	npc_manager.worker_npcs = []
	npc_manager.next_worker_npc_number = 1
	TimeManager.current_day = 26
	TimeManager.current_month = 1
	TimeManager.current_year = 1985


func _run_tests() -> void:
	_test_config()
	_test_generation()
	_test_age_range()
	_test_filters()
	_test_sorting()
	_test_d_tier()
	_test_retirement()


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)


func _make_worker(npc_id: String, age: int, logic: int, health: int) -> Dictionary:
	return {
		"id": npc_id,
		"first_name": "Test",
		"last_name": "Worker",
		"gender": "male",
		"birth_date": "%04d-01-01" % (TimeManager.current_year - age),
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


func _test_config() -> void:
	_reset_world()
	_assert_true(
		int(npc_manager.generation_config.get("minimum_entry_age", -1)) == 24
		and int(npc_manager.generation_config.get("maximum_entry_age", -1)) == 50
		and int(npc_manager.generation_config.get("retirement_age", -1)) == 65,
		"Generation config loads ages 24-50 and retirement age 65"
	)


func _test_generation() -> void:
	_reset_world()
	var generated: Array = npc_manager.generate_worker_npcs(10)
	var ids: Dictionary = {}
	var valid: bool = generated.size() == 10

	for worker_value in generated:
		if typeof(worker_value) != TYPE_DICTIONARY:
			valid = false
			break

		var worker: Dictionary = worker_value
		var npc_id: String = str(worker.get("id", ""))
		var stats_value = worker.get("stats", {})

		if npc_id.is_empty() or ids.has(npc_id):
			valid = false
			break

		if typeof(stats_value) != TYPE_DICTIONARY:
			valid = false
			break

		ids[npc_id] = true

	_assert_true(
		valid and ids.size() == 10,
		"Generated Worker NPCs have valid runtime data and unique IDs"
	)


func _test_age_range() -> void:
	_reset_world()
	var generated: Array = npc_manager.generate_worker_npcs(40)
	var valid: bool = true

	for worker_value in generated:
		var worker: Dictionary = worker_value
		var age: int = npc_manager.get_worker_age(worker)

		if age < 24 or age > 50:
			valid = false
			break

	_assert_true(
		valid,
		"Generated Worker NPC ages remain within 24-50"
	)


func _test_filters() -> void:
	_reset_world()
	npc_manager.worker_npcs = [
		_make_worker("npc_ya", 30, 50, 50),
		_make_worker("npc_adult", 45, 50, 50),
		_make_worker("npc_elder", 62, 50, 50)
	]

	_assert_true(
		npc_manager.get_available_worker_npcs("all").size() == 3
		and npc_manager.get_available_worker_npcs("young_adult").size() == 1
		and npc_manager.get_available_worker_npcs("adult").size() == 1
		and npc_manager.get_available_worker_npcs("elder").size() == 1,
		"All / Young Adult / Adult / Elder filters work correctly"
	)


func _test_sorting() -> void:
	_reset_world()
	npc_manager.worker_npcs = [
		_make_worker("npc_low", 30, 40, 40),
		_make_worker("npc_high", 30, 90, 90),
		_make_worker("npc_mid", 30, 70, 70)
	]

	var candidates: Array = npc_manager.get_candidates_for_slot(
		"hospital",
		"doctor_01"
	)

	var valid: bool = candidates.size() == 3

	if valid:
		valid = (
			str(candidates[0].get("npc_id", "")) == "npc_high"
			and str(candidates[1].get("npc_id", "")) == "npc_mid"
			and str(candidates[2].get("npc_id", "")) == "npc_low"
		)

	_assert_true(
		valid,
		"Candidates are sorted from highest to lowest slot performance"
	)


func _test_d_tier() -> void:
	_reset_world()
	npc_manager.worker_npcs = [
		_make_worker("npc_low", 30, 10, 10)
	]

	var candidates: Array = npc_manager.get_candidates_for_slot(
		"hospital",
		"doctor_01"
	)

	var valid: bool = candidates.size() == 1

	if valid:
		valid = (
			str(candidates[0].get("performance_tier", "")) == "D"
			and int(candidates[0].get("business_income", 0)) == 3200
		)

	_assert_true(
		valid,
		"Low-stat worker remains hireable and evaluates as D tier"
	)


func _test_retirement() -> void:
	_reset_world()
	var worker: Dictionary = _make_worker("npc_retire", 64, 70, 70)
	npc_manager.worker_npcs = [worker]

	var before_count: int = npc_manager.get_available_worker_npcs().size()
	TimeManager.current_year += 1
	npc_manager._process_retirements()
	var after_count: int = npc_manager.get_available_worker_npcs().size()

	_assert_true(
		before_count == 1
		and after_count == 0
		and bool(worker.get("is_retired", false)),
		"Worker retires at 65 and leaves the available pool"
	)
