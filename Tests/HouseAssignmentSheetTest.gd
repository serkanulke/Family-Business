extends Node

const ASSIGNMENT_SCENE := preload("res://Scenes/UI/House/HouseAssignmentSheet.tscn")

var passed := 0
var failed := 0
var original_characters: Array
var original_houses: Array


func _ready() -> void:
	original_characters = CharacterManager.characters.duplicate(true)
	original_houses = HouseManager.houses.duplicate(true)
	await _test_reference_layout_and_assets()
	await _test_assignment_and_removal()
	await _test_empty_state()
	CharacterManager.characters = original_characters
	HouseManager.houses = original_houses
	print("House Assignment Sheet tests: %d passed / %d failed" % [passed, failed])
	if failed > 0:
		push_error("House Assignment Sheet has %d failing test(s)." % failed)


func _test_reference_layout_and_assets() -> void:
	_prepare_role_state()
	var sheet := ASSIGNMENT_SCENE.instantiate() as HouseAssignmentSheet
	sheet.setup_role("house_sheet_test", "head_of_household")
	add_child(sheet)
	await get_tree().process_frame
	_assert(is_equal_approx(sheet.sheet_panel.position.x, 40.0) and is_equal_approx(sheet.sheet_panel.position.y, 502.0), "Bottom sheet uses the approved 40px inset and 502px top edge")
	_assert(is_equal_approx(sheet.sheet_panel.offset_left, 40.0) and is_equal_approx(sheet.sheet_panel.offset_right, -40.0), "Bottom sheet keeps the approved 40px side insets (1000px at 1080 reference width)")
	_assert(sheet.drag_handle.custom_minimum_size == Vector2(201, 9), "Drag handle matches the approved geometry")
	_assert(sheet.title_label.text == "HEAD OF HOUSEHOLD" and sheet.subtitle_label.text == "Select the best family member for this role", "Role heading and subtitle match the approved copy")
	_assert(sheet.candidate_grid.columns == 2 and sheet.candidate_grid.get_child_count() == 2, "Eligible family members render in the approved two-column grid")
	var current_card := sheet.find_child("CandidateCard_1", true, false) as PanelContainer
	var candidate_card := sheet.find_child("CandidateCard_2", true, false) as PanelContainer
	_assert(current_card != null and current_card.custom_minimum_size.y == 658.0 and current_card.find_child("RemoveButton", true, false) != null, "Current role holder renders as a 658px candidate card with Remove from House")
	_assert(candidate_card != null and candidate_card.find_child("AssignButton", true, false) != null, "Eligible replacement renders with the approved Assign action")
	var tier_icon := candidate_card.find_child("TierIcon_S", true, false) as TextureRect
	_assert(tier_icon != null and tier_icon.texture != null and tier_icon.texture.resource_path == "res://Resources/Icons/performance-tier/S.svg", "Candidate uses the existing S performance-tier asset")
	var stats_grid := candidate_card.find_child("StatsGrid", true, false) as GridContainer
	_assert(stats_grid != null and stats_grid.get_child_count() == 8, "Candidate card renders all eight core stats")
	var all_icons_loaded := true
	for stat_name in HouseAssignmentSheet.STAT_ORDER:
		var icon := candidate_card.find_child("Icon_" + stat_name, true, false) as TextureRect
		if icon == null or icon.texture == null:
			all_icons_loaded = false
	_assert(all_icons_loaded, "Candidate stats use the existing Resources stat icons")
	var logic_value := candidate_card.find_child("Value_logic", true, false) as Label
	var health_value := candidate_card.find_child("Value_health", true, false) as Label
	_assert(logic_value.get_theme_color("font_color") == HouseAssignmentSheet.COLOR_RED and health_value.get_theme_color("font_color") == HouseAssignmentSheet.COLOR_TEXT, "Only role-required stats receive the approved red emphasis")
	sheet.queue_free()
	await get_tree().process_frame


func _test_assignment_and_removal() -> void:
	_prepare_role_state()
	var assign_sheet := ASSIGNMENT_SCENE.instantiate() as HouseAssignmentSheet
	assign_sheet.setup_role("house_sheet_test", "head_of_household")
	add_child(assign_sheet)
	await get_tree().process_frame
	assign_sheet.call("_assign_candidate", 2)
	await get_tree().process_frame
	_assert(HouseManager.get_role_character_id("house_sheet_test", "head_of_household") == 2, "Assign replaces the current role holder immediately")
	_assert(HouseManager.get_character_assignment(1).is_empty(), "Replaced role holder becomes Unhoused rather than a duplicate resident")
	_prepare_role_state()
	var remove_sheet := ASSIGNMENT_SCENE.instantiate() as HouseAssignmentSheet
	remove_sheet.setup_role("house_sheet_test", "head_of_household")
	add_child(remove_sheet)
	await get_tree().process_frame
	remove_sheet.call("_remove_current")
	await get_tree().process_frame
	_assert(HouseManager.get_role_character_id("house_sheet_test", "head_of_household") == 0 and HouseManager.get_character_assignment(1).is_empty(), "Remove from House clears the role and leaves the character Unhoused")


func _test_empty_state() -> void:
	CharacterManager.characters = [{
		"character_id": 3, "first_name": "Child", "is_alive": true,
		"is_player_family": true, "life_stage": "child", "birth_date": "1975-01-26"
	}]
	HouseManager.restore_save_state({"houses": [{
		"house_instance_id": "house_sheet_test", "house_definition_id": "family_house",
		"property_id": "house_01", "level": 1,
		"role_assignments": {"head_of_household": null, "cook": null, "housekeeper": null, "caregiver": null},
		"resident_character_ids": [3]
	}]})
	var sheet := ASSIGNMENT_SCENE.instantiate() as HouseAssignmentSheet
	sheet.setup_role("house_sheet_test", "head_of_household")
	add_child(sheet)
	await get_tree().process_frame
	_assert(not sheet.candidate_scroll.visible and sheet.empty_center.visible, "No eligible role candidate switches to the approved empty-state layout")
	_assert(sheet.empty_label.text == "No eligible family member is available.", "Empty-state copy matches the approved reference exactly")
	_assert(sheet.find_child("CloseButton", true, false) == null, "Bottom sheet does not invent an unreferenced close button")
	sheet.queue_free()
	await get_tree().process_frame


func _prepare_role_state() -> void:
	CharacterManager.characters = [
		_character(1, "George", "1960-01-26", 80),
		_character(2, "Emma", "1963-01-26", 88)
	]
	HouseManager.restore_save_state({"houses": [{
		"house_instance_id": "house_sheet_test", "house_definition_id": "family_house",
		"property_id": "house_01", "level": 1,
		"role_assignments": {"head_of_household": 1, "cook": null, "housekeeper": null, "caregiver": null},
		"resident_character_ids": []
	}]})


func _character(character_id: int, first_name: String, birth_date: String, stat_value: int) -> Dictionary:
	return {
		"character_id": character_id, "first_name": first_name, "last_name": "",
		"gender": "female", "genetics": {"skin_tone": "light"},
		"portrait_variant_id": "character_001", "is_alive": true,
		"is_player_family": true, "life_stage": "young_adult", "birth_date": birth_date,
		"logic": stat_value, "health": stat_value, "social": stat_value,
		"confidence": stat_value, "discipline": stat_value, "creativity": stat_value,
		"attractiveness": stat_value, "happiness": stat_value,
		"flag_ids": [], "job_id": null, "company_id": null, "salary": 0
	}


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", message)
	else:
		failed += 1
		push_error("[FAIL] " + message)
