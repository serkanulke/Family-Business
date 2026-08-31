extends Node

const MAIN_SCENE := preload("res://Scenes/Main/Main.tscn")

var passed := 0
var failed := 0


func _ready() -> void:
	var main_instance := MAIN_SCENE.instantiate()
	add_child(main_instance)
	await get_tree().process_frame
	await get_tree().process_frame
	var family_tree := main_instance.get_node("World/FamilyTreeScreen") as FamilyTreeScreen
	var shared_hud := main_instance.get_node("SharedUI/MainHUD") as MainHUD
	_assert_true(family_tree != null and shared_hud != null, "Main owns the production Family Tree and one shared HUD")
	_assert_true(
		shared_hud.get_node_or_null("DatePill") != null
		and shared_hud.get_node_or_null("CoinPill") != null
		and shared_hud.get_node_or_null("DiamondPill") != null
		and shared_hud.get_node_or_null("BottomNavigation") != null,
		"Date, balances, and the reference navigation exist only in Main shared UI"
	)
	_assert_true(
		family_tree.get_node_or_null("HUDLayer/FixedUIRoot/TimeControls") != null
		and family_tree.get_node_or_null("HUDLayer/FixedUIRoot/BottomNavigation") == null,
		"Family Tree retains only its screen-specific time controls"
	)

	main_instance.call("show_screen", "map")
	await get_tree().process_frame
	await get_tree().process_frame
	var map_screen := main_instance.get_node("World/MapScreen") as MapScreen
	var business_modal := main_instance.get_node("ModalLayer/BusinessModal") as BusinessModal
	var buy_building_modal := main_instance.get_node("ModalLayer/BuyBuildingModal") as BuyBuildingModal
	var house_modal := main_instance.get_node("ModalLayer/HouseModal") as HouseModal
	var buy_house_modal := main_instance.get_node("ModalLayer/BuyHouseModal") as BuyHouseModal
	var map_icon := shared_hud.find_child("MapIcon", true, false) as TextureRect
	var family_icon := shared_hud.find_child("FamilyTreeIcon", true, false) as TextureRect
	_assert_true(
		map_screen.visible and map_screen.process_mode != Node.PROCESS_MODE_DISABLED
		and map_screen.map_camera.enabled
		and get_viewport().get_camera_2d() == map_screen.map_camera
		and not family_tree.visible and family_tree.process_mode == Node.PROCESS_MODE_DISABLED
		and not family_tree.family_tree_camera.enabled,
		"Map navigation activates only the Map screen and its independent camera"
	)
	_assert_true(
		map_icon != null and map_icon.size.is_equal_approx(Vector2(132, 132))
		and family_icon != null and family_icon.size.is_equal_approx(Vector2(110, 110)),
		"Shared reference navigation switches to the correct Map active state"
	)
	var original_businesses := BusinessManager.businesses.duplicate(true)
	var original_money := GameManager.family_money
	var original_next_business_id := BusinessManager.next_business_instance_number
	var original_houses := HouseManager.houses.duplicate(true)
	var original_next_house_id := HouseManager.next_house_instance_number
	BusinessManager.businesses = [{
		"business_instance_id": "business_map_route_test",
		"business_type_id": "cafe",
		"plot_id": "cafe_01",
		"level": 1,
		"slots": [
			{"slot_id": "manager_01", "assigned_character_id": null, "assigned_npc_id": null},
			{"slot_id": "barista_01", "assigned_character_id": null, "assigned_npc_id": null},
		],
	}]
	map_screen.call("_on_property_selected", "cafe_01")
	_assert_true(
		business_modal.visible and not buy_building_modal.visible
		and business_modal.business_instance_id == "business_map_route_test",
		"Owned family-business property opens the shared BusinessModal with its instance ID"
	)
	business_modal.close_modal()
	map_screen.call("_on_property_selected", "cafe_02")
	_assert_true(
		buy_building_modal.visible and not business_modal.visible
		and buy_building_modal.property_id == "cafe_02"
		and buy_building_modal.business_type_id == "cafe",
		"Unowned family-business property opens the shared BuyBuildingModal with stable metadata"
	)
	var blocked_camera_position := map_screen.map_camera.position
	var blocked_mouse_down := InputEventMouseButton.new()
	blocked_mouse_down.button_index = MOUSE_BUTTON_LEFT
	blocked_mouse_down.pressed = true
	blocked_mouse_down.position = Vector2(540, 960)
	Input.parse_input_event(blocked_mouse_down)
	var blocked_mouse_move := InputEventMouseMotion.new()
	blocked_mouse_move.position = Vector2(440, 880)
	blocked_mouse_move.relative = Vector2(-100, -80)
	Input.parse_input_event(blocked_mouse_move)
	var blocked_mouse_up := InputEventMouseButton.new()
	blocked_mouse_up.button_index = MOUSE_BUTTON_LEFT
	blocked_mouse_up.pressed = false
	blocked_mouse_up.position = blocked_mouse_move.position
	Input.parse_input_event(blocked_mouse_up)
	await get_tree().process_frame
	_assert_true(
		map_screen.map_camera.position.is_equal_approx(blocked_camera_position),
		"Open BuyBuildingModal consumes pointer drag before it can pan the Map"
	)
	buy_building_modal.close_modal()
	HouseManager.houses = []
	map_screen.call("_on_property_selected", "house_02")
	_assert_true(
		buy_house_modal.visible and not house_modal.visible,
		"Unowned House opens the House purchase flow, not owned management"
	)
	buy_house_modal.close_modal()
	HouseManager.restore_save_state({"houses": [{"house_instance_id": "house_route_test", "house_definition_id": "family_house", "property_id": "house_01", "level": 1, "role_assignments": {"head_of_household": null, "cook": null, "housekeeper": null, "caregiver": null}, "resident_character_ids": []}]})
	map_screen.call("_on_property_selected", "house_01")
	_assert_true(
		house_modal.visible and not buy_house_modal.visible
		and house_modal.house_instance_id == "house_route_test",
		"Owned House opens management for the exact House instance"
	)
	house_modal.close_modal()
	map_screen.call("_on_property_selected", "land_2x2_01")
	_assert_true(
		not business_modal.visible and not buy_building_modal.visible
		and not house_modal.visible and not buy_house_modal.visible
		and main_instance.get_node("ModalLayer").get_child_count() == 4,
		"Land opens no modal and Main owns one reusable instance of each property modal"
	)

	GameManager.set_family_money(30_000)
	map_screen.call("_on_property_selected", "cafe_02")
	buy_building_modal.call("_on_buy_pressed")
	var purchased_business := BusinessManager.get_business_on_plot("cafe_02")
	var purchased_property: MapProperty = null
	for property_value in map_screen.get_map_properties():
		if property_value.get_property_id() == "cafe_02":
			purchased_property = property_value
			break
	_assert_true(
		not purchased_business.is_empty()
		and str(purchased_business.get("business_type_id", "")) == "cafe"
		and GameManager.family_money == 5_000
		and not buy_building_modal.visible
		and business_modal.visible
		and business_modal.business_instance_id == str(purchased_business.get("business_instance_id", "")),
		"Successful Map purchase deducts once and transitions directly into BusinessModal"
	)
	_assert_true(
		purchased_property != null
		and purchased_property.property_tag.state_label.text == "0 / 3 staff"
		and shared_hud.coin_value_label.text == "5k",
		"Successful purchase refreshes the authored Map tag and shared money HUD"
	)
	business_modal.close_modal()
	BusinessManager.businesses = original_businesses
	BusinessManager.next_business_instance_number = original_next_business_id
	HouseManager.houses = original_houses
	HouseManager.next_house_instance_number = original_next_house_id
	GameManager.set_family_money(original_money)
	var camera := map_screen.map_camera
	camera.position = Vector2(3100, 2100)
	var input_start := camera.position
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	mouse_down.position = Vector2(540, 960)
	Input.parse_input_event(mouse_down)
	var mouse_move := InputEventMouseMotion.new()
	mouse_move.position = Vector2(440, 880)
	mouse_move.relative = Vector2(-100, -80)
	Input.parse_input_event(mouse_move)
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	mouse_up.position = mouse_move.position
	Input.parse_input_event(mouse_up)
	await get_tree().process_frame
	_assert_true(
		camera.position.x > input_start.x and camera.position.y > input_start.y,
		"Main dispatches desktop drag through fullscreen UI to the active Map camera"
	)
	_assert_true(
		map_screen.find_child("BottomNavigation", true, false) == null
		and map_screen.find_child("DatePill", true, false) == null
		and not (family_tree.get_node("HUDLayer") as CanvasLayer).visible,
		"Map has no duplicate navigation/top values and Family Tree-only controls are hidden"
	)

	var original_map_id := map_screen.get_instance_id()
	for screen_id in ["family_tree", "map", "family_tree", "map"]:
		main_instance.call("show_screen", screen_id)
		await get_tree().process_frame
	_assert_true(
		main_instance.get_node("World/MapScreen").get_instance_id() == original_map_id
		and main_instance.get_node("SharedUI").get_child_count() == 1,
		"Repeated Family Tree/Map navigation reuses both screen and HUD without duplicates"
	)
	main_instance.call("show_screen", "family_tree")
	await get_tree().process_frame
	var active_family_icon := shared_hud.find_child("FamilyTreeIcon", true, false) as TextureRect
	var hidden_map_canvas_items := true
	for node in map_screen.get_node("MapWorld/Buildings").find_children("*", "CanvasItem", true, false):
		hidden_map_canvas_items = hidden_map_canvas_items and not (node as CanvasItem).is_visible_in_tree()
	_assert_true(
		family_tree.visible
		and (family_tree.get_node("HUDLayer") as CanvasLayer).visible
		and family_tree.family_tree_camera.enabled
		and get_viewport().get_camera_2d() == family_tree.family_tree_camera
		and not map_screen.map_camera.enabled
		and not map_screen.backdrop_layer.visible
		and not map_screen.map_world.is_visible_in_tree()
		and hidden_map_canvas_items
		and active_family_icon != null and active_family_icon.size.is_equal_approx(Vector2(132, 132)),
		"Family Tree returns with its original camera and no Map canvas content remains visible"
	)
	print("Main / shared navigation tests: %d passed / %d failed" % [passed, failed])
	if failed == 0: print("ALL MAIN / SHARED NAVIGATION TESTS PASSED.")
	else: push_error("Main / shared navigation has %d failing test(s)." % failed)


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)
