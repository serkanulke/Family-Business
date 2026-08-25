extends Node


const BUSINESS_MODAL_SCENE := preload(
	"res://Scenes/UI/Business/BusinessModal.tscn"
)

const BUSINESS_MODAL_DATA_ADAPTER := preload(
	"res://Scripts/UI/Business/business_modal_data_adapter.gd"
)


var saved_businesses: Array = []
var saved_family_money: int = 0
var passed := 0
var failed := 0

var test_business_id: String = ""
var business_modal: Control = null


func _ready() -> void:
	print("")
	print("========================================")
	print("Business Modal integration test starting")
	print("========================================")

	_save_state()

	GameManager.set_family_money(
		500000
	)

	var business: Dictionary = (
		BusinessManager.create_business_instance(
			"hospital",
			"plot_business_modal_test",
			false
		)
	)

	if business.is_empty():
		push_error(
			"TEST SETUP FAILED: Hospital business could not be created."
		)
		_restore_state()
		return

	test_business_id = str(
		business.get(
			"business_instance_id",
			""
		)
	)

	if test_business_id.is_empty():
		push_error(
			"TEST SETUP FAILED: Created business has no business_instance_id."
		)
		_restore_state()
		return

	var presentation_data: Dictionary = (
		BUSINESS_MODAL_DATA_ADAPTER.build(
			test_business_id
		)
	)

	if presentation_data.is_empty():
		push_error(
			"TEST SETUP FAILED: BusinessModalDataAdapter returned empty data."
		)
		_restore_state()
		return

	var hospital_type := BusinessManager.get_business_type_by_id("hospital")
	var modal_path := str(hospital_type.get("modal_visual_path", ""))
	var map_path := str(hospital_type.get("map_visual_path", ""))
	var level_one_image_path := str(presentation_data.get("image_path", ""))
	business["level"] = 5
	var level_five_data: Dictionary = BUSINESS_MODAL_DATA_ADAPTER.build(
		test_business_id
	)
	business["level"] = 1

	_assert_true(
		level_one_image_path == modal_path
		and level_one_image_path != map_path
		and str(level_five_data.get("image_path", "")) == modal_path
		and not level_one_image_path.contains("level_0"),
		"Business Modal adapter uses the level-independent modal_visual_path"
	)

	business_modal = (
		BUSINESS_MODAL_SCENE.instantiate()
	)

	add_child(
		business_modal
	)

	business_modal.configure_from_data(
		presentation_data
	)

	var modal_asset_exists := ResourceLoader.exists(modal_path)
	_assert_true(
		(
			modal_asset_exists
			and business_modal.building_image.texture != null
		)
		or (
			not modal_asset_exists
			and business_modal.building_image.texture == null
		),
		"Missing modal asset is handled safely without a map-image fallback"
	)

	print(
		"[PASS] Real Hospital created: ",
		test_business_id
	)

	print(
		"[PASS] BusinessModal loaded with real BusinessManager data."
	)

	print(
		"Business Modal integration tests: %d passed / %d failed"
		% [passed, failed]
	)
	if failed == 0:
		print("ALL BUSINESS MODAL INTEGRATION TESTS PASSED.")
	else:
		push_error(
			"Business Modal integration has %d failing test(s)."
			% failed
		)

	print(
		"NEXT MANUAL CHECK:"
	)

	print(
		"1. Confirm title shows HOSPITAL and Level 1."
	)

	print(
		"2. Confirm real Hospital slots are listed."
	)

	print(
		"3. Press any Assign button."
	)

	print(
		"4. Worker Type sheet must open with Family Member / NPC Worker."
	)

	print(
		"5. There must be NO 'hospital_preview' warning."
	)

	print("========================================")
	print("Close the test scene when finished.")
	print("========================================")
	print("")


func _save_state() -> void:
	saved_businesses = (
		BusinessManager.businesses.duplicate(
			true
		)
	)

	saved_family_money = (
		GameManager.family_money
	)


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)


func _restore_state() -> void:
	BusinessManager.businesses = (
		saved_businesses.duplicate(
			true
		)
	)

	GameManager.set_family_money(
		saved_family_money
	)


func _exit_tree() -> void:
	_restore_state()
