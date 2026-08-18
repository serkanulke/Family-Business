extends Node

const CHARACTER_CARD_SCENE := preload("res://UI/CharacterCard/CharacterCard.tscn")
const FAMILY_TREE_SCENE := preload("res://Scenes/FamilyTree/FamilyTreeScreen.tscn")

var passed: int = 0
var failed: int = 0
var requested_slot: String = ""
var requested_character_id: int = 0


func _ready() -> void:
	var original_day: int = TimeManager.current_day
	var original_month: int = TimeManager.current_month
	var original_year: int = TimeManager.current_year
	TimeManager.current_day = 10
	TimeManager.current_month = 12
	TimeManager.current_year = 2020
	var partner := {
		"character_id": 405,
		"first_name": "Michael",
		"gender": "male",
		"birth_date": "1991-05-17"
	}
	CharacterManager.characters.append(partner)
	var card := CHARACTER_CARD_SCENE.instantiate()
	add_child(card)
	await get_tree().process_frame
	var character := {
		"character_id": 404,
		"first_name": "Emma",
		"gender": "female",
		"birth_date": "1993-12-10",
		"life_stage": "young_adult",
		"is_player_family": true,
		"partner_id": 405,
		"school_id": 4003,
		"major_id": 5001,
		"education_status": "graduated",
		"is_retired": false,
		"job_id": 3003,
		"company_id": "johnson_hospital",
		"salary": 25000,
		"health": 80,
		"happiness": 80,
		"logic": 80,
		"attractiveness": 80,
		"social": 80,
		"confidence": 80,
		"discipline": 80,
		"creativity": 80,
		"event_log": [
			{"event_type": "education_started", "date": "2012-09-01", "school_id": 4003, "major_id": 5001},
			{"event_type": "education_graduated", "date": "2016-06-15", "school_id": 4003, "major_id": 5001},
			{"event_type": "career_started", "date": "2016-07-01", "company_id": "johnson_hospital", "job_id": 3003, "description": "Started working at Johnson Hospital"}
		]
	}
	CharacterManager.characters.append(character)
	card.set_character_data(character)
	card.visible = true
	await get_tree().process_frame
	var snapshot: Dictionary = card.get_display_snapshot()
	_assert_true(card is CanvasLayer, "Character Card uses a foreground CanvasLayer above the Family Tree HUD")
	_assert_true(card.modal_root is Control, "CharacterCardModal is a viewport-sized Control overlay")
	_assert_true(card.dim_background != null, "Modal contains a full-rect dim background")
	_assert_true(card.character_card_panel != null, "Modal contains a separate Character Card panel")
	_assert_true(card.scroll_container.get_parent() == card.viewport_root, "Only modal content owns the ScrollContainer")
	_assert_equal(card.modal_root.mouse_filter, Control.MOUSE_FILTER_STOP, "Modal root blocks background pointer input")
	_assert_equal(card.dim_background.mouse_filter, Control.MOUSE_FILTER_STOP, "Dim layer blocks background pointer input")
	_assert_approx(card.dim_background.color.a, 0.76, 0.001, "Dim opacity matches the modal reference")
	_assert_true(card.modal_container.scale.x < 1.0, "Character Card panel is inset instead of Full Rect")
	_assert_equal(snapshot.get("character_id"), 404, "Character ID binds")
	_assert_equal(snapshot.get("name"), "Emma", "First name binds without an invented surname field")
	_assert_equal(snapshot.get("spouse"), "Married to Michael", "Existing partner relationship binds")
	_assert_equal(snapshot.get("job"), "General Practitioner (Doctor)", "Career backend binds")
	_assert_equal(snapshot.get("company"), "Johnson Hospital", "Company backend binds")
	_assert_equal(snapshot.get("birth_date"), "10 Dec 1993", "Birth date follows the reference format")
	_assert_equal(snapshot.get("lifestyle_stars"), 0, "Missing canonical Lifestyle data stays at zero")
	_assert_equal(snapshot.get("lifestyle_class"), "", "Missing canonical class label stays hidden")
	_assert_equal(snapshot.get("item_count"), "0/3", "Item slots stay empty")
	var thresholds := {0: 0, 1: 1, 34: 1, 35: 2, 59: 2, 60: 3, 79: 3, 80: 4, 94: 4, 95: 5, 100: 5}
	for score in thresholds:
		_assert_equal(card.get_lifestyle_star_count(score), thresholds[score], "Lifestyle threshold %d" % score)
	card.item_slot_requested.connect(_on_item_slot_requested)
	card.request_item_slot("accessory")
	_assert_equal(requested_slot, "accessory", "Accessory entry point emits")
	_assert_equal(requested_character_id, 404, "Entry point keeps character ID")
	card._block_background_input(InputEventMouseButton.new())
	_assert_true(card.visible, "Dim-background input does not close the modal")
	var close_button := card.get_node(
		"CharacterCardModal/ModalContainer/CharacterCardPanel/ViewportRoot/ContentScroll/PageMargin/Content/ProfileCard/ProfileContent/CloseButton"
	) as Button
	close_button.pressed.emit()
	_assert_true(not card.visible, "Close button hides the overlay")
	_assert_true(card.is_inside_tree(), "Close button does not reload or free the Family Tree scene")
	card.visible = true
	if "--capture" in OS.get_cmdline_user_args():
		var capture_viewport := SubViewport.new()
		capture_viewport.size = Vector2i(1080, 1920)
		capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		capture_viewport.transparent_bg = false
		add_child(capture_viewport)
		var capture_family_tree := FAMILY_TREE_SCENE.instantiate()
		capture_viewport.add_child(capture_family_tree)
		await get_tree().process_frame
		var capture_card := capture_family_tree.get_node("CharacterCard")
		capture_card.set_character_data(character)
		capture_card.visible = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var capture_path := "user://character_card_reference_recreation.png"
		var image := capture_viewport.get_texture().get_image()
		var save_error := image.save_png(capture_path)
		_assert_equal(save_error, OK, "Visual capture saves")
		print("Character Card capture: ", ProjectSettings.globalize_path(capture_path))
	var family_tree_screen: Node = FAMILY_TREE_SCENE.instantiate()
	add_child(family_tree_screen)
	await get_tree().process_frame
	_assert_true(family_tree_screen.get_node_or_null("CharacterCard") != null, "Family Tree includes Character Card overlay")
	var integrated_card := family_tree_screen.get_node("CharacterCard")
	var family_tree_instance_id := family_tree_screen.get_instance_id()
	_assert_true(integrated_card.open_for_character(404), "Family Tree overlay opens with manager-backed character data")
	_assert_true(integrated_card.visible, "Family Tree remains behind a visible Character Card overlay")
	integrated_card.close_card()
	_assert_equal(family_tree_screen.get_instance_id(), family_tree_instance_id, "Closing the modal preserves the Family Tree instance")
	_assert_true(family_tree_screen.is_inside_tree(), "Family Tree state owner remains in the scene tree")
	print("")
	print("========================================")
	print("Character Card tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	if failed == 0:
		print("ALL CHARACTER CARD TESTS PASSED.")
	else:
		push_error("Character Card has %d failing test(s)." % failed)
	CharacterManager.characters.erase(partner)
	CharacterManager.characters.erase(character)
	TimeManager.current_day = original_day
	TimeManager.current_month = original_month
	TimeManager.current_year = original_year


func _on_item_slot_requested(slot_type: String, selected_character_id: int) -> void:
	requested_slot = slot_type
	requested_character_id = selected_character_id


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)


func _assert_equal(actual: Variant, expected: Variant, test_name: String) -> void:
	_assert_true(actual == expected, "%s (expected %s, got %s)" % [test_name, str(expected), str(actual)])


func _assert_approx(actual: float, expected: float, tolerance: float, test_name: String) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s (expected %s, got %s)" % [test_name, str(expected), str(actual)])
