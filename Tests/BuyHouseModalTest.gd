extends Node

const BUY_HOUSE_SCENE := preload("res://Scenes/UI/House/BuyHouseModal.tscn")

var passed := 0
var failed := 0


func _ready() -> void:
	var original_houses := HouseManager.houses.duplicate(true)
	var original_next_id := HouseManager.next_house_instance_number
	var original_money := GameManager.family_money
	HouseManager.houses = []
	HouseManager.next_house_instance_number = 1
	var modal := BUY_HOUSE_SCENE.instantiate() as BuyHouseModal
	add_child(modal)
	await get_tree().process_frame

	GameManager.set_family_money(0)
	var opened := modal.open_for_property("house_buy_modal_test")
	var disabled_style := modal.buy_button.get_theme_stylebox("disabled") as StyleBoxFlat
	_assert_true(
		opened
		and modal.buy_button.disabled
		and modal.buy_button_amount.text == "25,000"
		and modal.capacity_value.text == "5"
		and modal.monthly_expense_value.text == "-1,000"
		and disabled_style != null
		and modal.close_button != null,
		"Buy House binds canonical Level 1 data to the approved disabled purchase card"
	)

	GameManager.set_family_money(30_000)
	_assert_true(not modal.buy_button.disabled, "Buy House enables immediately when funds become sufficient")
	var completion := {"count": 0, "house_id": "", "property_id": ""}
	modal.purchase_completed.connect(func(house_id: String, property_id: String) -> void:
		completion["count"] = int(completion["count"]) + 1
		completion["house_id"] = house_id
		completion["property_id"] = property_id
	)
	modal.buy_button.pressed.emit()
	var purchased := HouseManager.get_house_on_property("house_buy_modal_test")
	_assert_true(
		not purchased.is_empty()
		and GameManager.family_money == 5_000
		and not modal.visible
		and int(completion["count"]) == 1
		and str(completion["house_id"]) == str(purchased.get("house_instance_id", ""))
		and str(completion["property_id"]) == "house_buy_modal_test",
		"Buy House preserves purchase behavior, deducts once, and emits stable IDs"
	)

	HouseManager.houses = original_houses
	HouseManager.next_house_instance_number = original_next_id
	GameManager.set_family_money(original_money)
	modal.queue_free()
	print("Buy House Modal tests: %d passed / %d failed" % [passed, failed])
	if failed == 0:
		print("ALL BUY HOUSE MODAL TESTS PASSED.")
	else:
		push_error("Buy House Modal has %d failing test(s)." % failed)
	get_tree().quit(failed)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", message)
	else:
		failed += 1
		push_error("[FAIL] " + message)
