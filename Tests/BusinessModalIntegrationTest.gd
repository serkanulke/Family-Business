extends Node


const BUSINESS_MODAL_SCENE := preload(
	"res://Scenes/UI/Business/BusinessModal.tscn"
)

const BUSINESS_MODAL_DATA_ADAPTER := preload(
	"res://Scripts/UI/Business/business_modal_data_adapter.gd"
)


var saved_businesses: Array = []
var saved_family_money: int = 0

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

	business_modal = (
		BUSINESS_MODAL_SCENE.instantiate()
	)

	add_child(
		business_modal
	)

	business_modal.configure_from_data(
		presentation_data
	)

	print(
		"[PASS] Real Hospital created: ",
		test_business_id
	)

	print(
		"[PASS] BusinessModal loaded with real BusinessManager data."
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
