extends Node

const HOUSE_MODAL_SCENE := preload("res://Scenes/UI/House/HouseModal.tscn")

var passed := 0
var failed := 0
var original_characters: Array
var original_houses: Array
var original_money := 0


func _ready() -> void:
	original_characters = CharacterManager.characters.duplicate(true)
	original_houses = HouseManager.houses.duplicate(true)
	original_money = GameManager.family_money
	_prepare_state()
	var modal := HOUSE_MODAL_SCENE.instantiate() as HouseModal
	add_child(modal)
	await get_tree().process_frame
	_assert(modal.open_for_house("house_0001"), "House Modal opens a real selected House instance")
	await get_tree().process_frame
	_assert(modal.visible and modal.mouse_filter == Control.MOUSE_FILTER_STOP, "House Modal blocks input to the Map")
	_assert(modal.title_label.text == "HOUSE" and modal.level_label.text == "Level 1", "Header binds House identity and level")
	_assert(modal.capacity_label.text == "Capacity 1 / 5", "Capacity binds role plus resident occupancy")
	_assert(modal.status_label.text == "Stable", "Household Status binds backend state")
	_assert(modal.expense_label.text == "-1,000", "Monthly expense binds House level data")
	_assert(_has_text(modal.perks_container, "Artistic"), "House Perks render as readable text-only tags")
	_assert(modal.household_list.get_child_count() == 5, "Four role cards and one available resident row render")
	var house_card := modal.find_child("HouseCard", true, false) as PanelContainer
	_assert(house_card != null and house_card.offset_top == 182.0 and house_card.offset_bottom == -177.0, "House Modal keeps the authoritative 1080x1920 outer geometry")
	var head_card := modal.find_child("RoleCard_head_of_household", true, false) as PanelContainer
	_assert(head_card != null and head_card.custom_minimum_size.y == 162.0 and _has_text(head_card, "+2"), "Role card keeps reference height and compact overflow pill treatment")
	var replace_action := modal.find_child("ReplaceAction", true, false) as Button
	var replace_style := replace_action.get_theme_stylebox("normal") as StyleBoxFlat if replace_action != null else null
	_assert(replace_style != null and replace_style.corner_radius_top_left == 0 and replace_style.corner_radius_top_right == 22, "Role action uses the reference square-left rounded-right segment geometry")
	var building_icon := modal.find_child("BuildingIcon", true, false) as TextureRect
	_assert(building_icon != null and building_icon.texture != null and building_icon.custom_minimum_size == Vector2(66, 66), "Next Upgrade uses the existing 66px building icon")
	_assert(not modal.upgrade_button.disabled and modal.upgrade_amount_label.text == "35,000", "Upgrade action binds next-level price")
	var head_job := int(CharacterManager.get_character_by_id(1).job_id)
	HouseManager.assign_character_to_role("house_0001", "cook", 2)
	await get_tree().process_frame
	_assert(modal.capacity_label.text == "Capacity 2 / 5", "Modal refreshes immediately after assignment")
	_assert(int(CharacterManager.get_character_by_id(1).job_id) == head_job, "Modal-backed House operations preserve career state")
	modal.call("_open_info_modal")
	await get_tree().process_frame
	var info_modals := modal.find_children("*", "HouseInfoModal", true, false)
	_assert(info_modals.size() == 1 and modal.visible, "Info icon opens one blocking explanation layer")
	var info_modal := info_modals[0] as HouseInfoModal
	var info_buttons := info_modal.find_children("*", "Button", true, false)
	var readable_copy := true
	for label_value in info_modal.find_children("*", "Label", true, false):
		var info_label := label_value as Label
		readable_copy = readable_copy and info_label.get_theme_font_size("font_size") >= 20
	_assert(info_buttons.size() == 1, "House explanation uses exactly one approved X close action")
	_assert(readable_copy, "House explanation text remains at least 20 px for mobile readability")
	info_modal.call("_close")
	await get_tree().process_frame
	_assert(modal.visible, "Closing House info does not close House Modal")
	GameManager.family_money = 0
	modal.refresh_from_manager()
	_assert(modal.upgrade_button.disabled, "Unaffordable upgrade uses disabled-button state")
	modal.close_modal()
	_assert(not modal.visible, "House Modal close action hides only the modal")
	modal.queue_free()
	CharacterManager.characters = original_characters
	HouseManager.houses = original_houses
	GameManager.family_money = original_money
	print("House Modal tests: %d passed / %d failed" % [passed, failed])
	if failed > 0:
		push_error("House Modal has %d failing test(s)." % failed)


func _prepare_state() -> void:
	CharacterManager.characters = [
		{"character_id": 1, "first_name": "Emma", "is_alive": true, "is_player_family": true, "life_stage": "adult", "logic": 80, "health": 80, "social": 80, "confidence": 80, "discipline": 80, "creativity": 80, "happiness": 50, "flag_ids": [1002], "job_id": 2001, "company_id": "company", "salary": 5000},
		{"character_id": 2, "first_name": "Alex", "is_alive": true, "is_player_family": true, "life_stage": "adult", "logic": 70, "health": 70, "social": 70, "confidence": 70, "discipline": 70, "creativity": 70, "happiness": 50, "flag_ids": [], "job_id": null, "company_id": null, "salary": 0}
	]
	HouseManager.restore_save_state({"houses": [{"house_instance_id": "house_0001", "house_definition_id": "family_house", "property_id": "house_01", "level": 1, "role_assignments": {"head_of_household": 1, "cook": null, "housekeeper": null, "caregiver": null}, "resident_character_ids": []}], "next_house_instance_number": 2})
	GameManager.family_money = 100000


func _has_text(root: Node, text_value: String) -> bool:
	for child in root.find_children("*", "Label", true, false):
		if child is Label and (child as Label).text.contains(text_value):
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", message)
	else:
		failed += 1
		push_error("[FAIL] " + message)
