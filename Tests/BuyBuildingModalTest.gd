extends Node

const BUY_MODAL_SCENE := preload("res://Scenes/UI/Business/BuyBuildingModal.tscn")

var passed := 0
var failed := 0


func _ready() -> void:
	var original_businesses := BusinessManager.businesses.duplicate(true)
	var original_money := GameManager.family_money
	var original_next_id := BusinessManager.next_business_instance_number
	var modal := BUY_MODAL_SCENE.instantiate() as BuyBuildingModal
	add_child(modal)
	await get_tree().process_frame

	_test_scene_contract(modal)
	_test_all_business_type_bindings(modal)
	_test_insufficient_funds(modal)
	_test_close_without_purchase(modal)
	_test_purchase_and_duplicate_guard(modal)

	BusinessManager.businesses = original_businesses
	BusinessManager.next_business_instance_number = original_next_id
	GameManager.set_family_money(original_money)
	modal.queue_free()

	print("Buy Building Modal tests: %d passed / %d failed" % [passed, failed])
	if failed == 0:
		print("ALL BUY BUILDING MODAL TESTS PASSED.")
	else:
		push_error("Buy Building Modal has %d failing test(s)." % failed)
	get_tree().quit(failed)


func _test_scene_contract(modal: BuyBuildingModal) -> void:
	_assert_true(
		modal.mouse_filter == Control.MOUSE_FILTER_STOP
		and modal.get_node("Dimmer").mouse_filter == Control.MOUSE_FILTER_STOP,
		"Full-screen modal and dim layer block Map input"
	)
	var card := modal.get_node("SafeArea/Center/ModalCard") as PanelContainer
	_assert_true(
		card != null and card.custom_minimum_size.x == 780.0,
		"Responsive container hierarchy owns one centered purchase card"
	)
	_assert_true(
		modal.get_node_or_null("SafeArea/Center/ModalCard/CardMargin/Content/Header/CloseButton") != null
		and modal.get_node_or_null("SafeArea/Center/ModalCard/CardMargin/Content/BuyButton") != null,
		"Purchase modal exposes one X close action and one primary CTA"
	)


func _test_all_business_type_bindings(modal: BuyBuildingModal) -> void:
	BusinessManager.businesses = []
	GameManager.set_family_money(2_000_000)
	for business_type_value in BusinessManager.business_types:
		if not business_type_value is Dictionary:
			continue
		var business_type: Dictionary = business_type_value
		var type_id := str(business_type.get("business_type_id", ""))
		var plot_id := "buy_modal_binding_" + type_id
		var opened := modal.open_for_property(plot_id, type_id)
		var expected_cost := BusinessManager.get_business_acquisition_cost(type_id, false)
		var expected_slots := BusinessManager.get_level_slot_definitions(type_id, 1).size()
		var expected_visual := BusinessManager.get_business_modal_visual_path(type_id)
		var bound_visual := ""
		if modal.building_image.texture != null:
			bound_visual = modal.building_image.texture.resource_path
		_assert_true(
			opened
			and modal.property_id == plot_id
			and modal.business_type_id == type_id
			and modal.acquisition_cost == expected_cost
			and modal.business_title.text == str(business_type.get("display_name", "")).to_upper()
			and modal.business_level.text == "Level 1"
			and modal.buy_button_amount.text == _group_digits(expected_cost)
			and modal.employee_slots_detail.text.begins_with(str(expected_slots) + " employee slot")
			and bound_visual == expected_visual,
			"%s binds authoritative Level 1 data and modal visual" % type_id
		)

	var opened_hospital := modal.open_for_property("buy_modal_hospital", "hospital")
	_assert_true(
		opened_hospital
		and modal.potential_income_value.text == "+17,000"
		and modal.monthly_expense_value.text == "-6,800"
		and modal.employee_slots_detail.text == "3 employee slots available after purchase."
		and modal.buy_button_amount.text == "120,000",
		"Hospital uses repository Level 1 income, expense, slots, and ready-made cost"
	)


func _test_insufficient_funds(modal: BuyBuildingModal) -> void:
	BusinessManager.businesses = []
	GameManager.set_family_money(0)
	var opened := modal.open_for_property("hospital_insufficient_test", "hospital")
	var disabled_style := modal.buy_button.get_theme_stylebox("disabled") as StyleBoxFlat
	var normal_style := modal.buy_button.get_theme_stylebox("normal") as StyleBoxFlat
	_assert_true(
		opened and modal.buy_button.disabled
		and modal.buy_button_amount.text == "120,000"
		and modal.feedback_label.text.is_empty()
		and not modal.feedback_label.visible
		and disabled_style != null and normal_style != null
		and disabled_style.bg_color != normal_style.bg_color,
		"Insufficient funds show price on a visibly disabled CTA without helper text"
	)
	modal.call("_on_buy_pressed")
	_assert_true(
		BusinessManager.get_business_on_plot("hospital_insufficient_test").is_empty()
		and GameManager.family_money == 0
		and modal.visible
		and modal.feedback_label.text.is_empty()
		and not modal.feedback_label.visible,
		"Insufficient-funds request creates no business and deducts no money"
	)


func _test_close_without_purchase(modal: BuyBuildingModal) -> void:
	BusinessManager.businesses = []
	GameManager.set_family_money(500_000)
	var state := {"closed_count": 0}
	var on_closed := func() -> void: state["closed_count"] = int(state["closed_count"]) + 1
	modal.closed.connect(on_closed)
	modal.open_for_property("factory_close_test", "factory")
	modal.close_button.pressed.emit()
	_assert_true(
		not modal.visible and int(state["closed_count"]) == 1
		and BusinessManager.get_business_on_plot("factory_close_test").is_empty()
		and GameManager.family_money == 500_000,
		"X closes without purchase, mutation, or navigation"
	)
	modal.closed.disconnect(on_closed)


func _test_purchase_and_duplicate_guard(modal: BuyBuildingModal) -> void:
	BusinessManager.businesses = []
	BusinessManager.next_business_instance_number = 1
	var cost := BusinessManager.get_business_acquisition_cost("cafe", false)
	GameManager.set_family_money(cost + 5_000)
	var state := {
		"completion_count": 0,
		"completed_instance_id": "",
		"completed_plot_id": "",
	}
	var on_completed := func(instance_id: String, plot_id: String) -> void:
		state["completion_count"] = int(state["completion_count"]) + 1
		state["completed_instance_id"] = instance_id
		state["completed_plot_id"] = plot_id
	modal.purchase_completed.connect(on_completed)
	var opened := modal.open_for_property("cafe_purchase_test", "cafe")
	modal.call("_on_buy_pressed")
	modal.call("_on_buy_pressed")
	var created := BusinessManager.get_business_on_plot("cafe_purchase_test")
	_assert_true(
		opened and not created.is_empty()
		and str(created.get("business_type_id", "")) == "cafe"
		and str(created.get("plot_id", "")) == "cafe_purchase_test"
		and int(created.get("level", 0)) == 1
		and (created.get("slots", []) as Array).size() == 3,
		"Purchase creates the correct Level 1 family business on the stable plot"
	)
	_assert_true(
		GameManager.family_money == 5_000
		and BusinessManager.businesses.size() == 1
		and int(state["completion_count"]) == 1
		and str(state["completed_instance_id"]) == str(created.get("business_instance_id", ""))
		and str(state["completed_plot_id"]) == "cafe_purchase_test",
		"Purchase deducts once and duplicate requests cannot create or signal twice"
	)
	_assert_true(not modal.visible, "Successful purchase closes only the Buy Building Modal")
	modal.purchase_completed.disconnect(on_completed)


func _group_digits(value: int) -> String:
	var raw := str(absi(value))
	var result := ""
	while raw.length() > 3:
		result = "," + raw.right(3) + result
		raw = raw.left(raw.length() - 3)
	return raw + result


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)
