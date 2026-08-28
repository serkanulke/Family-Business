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
