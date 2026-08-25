extends Node

const MAP_SCENE := preload("res://UI/Map.tscn")

var passed := 0
var failed := 0


func _ready() -> void:
	var map_screen := MAP_SCENE.instantiate() as MapScreen
	add_child(map_screen)
	await get_tree().process_frame
	await get_tree().process_frame
	_test_empty_authoring_scene(map_screen)
	_test_fixed_rectangular_bounds(map_screen)
	_test_mouse_drag(map_screen)
	_test_touch_drag(map_screen)
	_test_zoom_is_disabled(map_screen)
	print("Map infrastructure tests: %d passed / %d failed" % [passed, failed])
	if failed == 0: print("ALL MAP INFRASTRUCTURE TESTS PASSED.")
	else: push_error("Map infrastructure has %d failing test(s)." % failed)
	map_screen.queue_free()


func _test_empty_authoring_scene(map_screen: MapScreen) -> void:
	var world := map_screen.get_node("MapWorld")
	var empty_layers := true
	for layer_name in ["Ground", "Roads", "Plots", "Buildings", "Environment", "Interactions"]:
		var layer := world.get_node_or_null(layer_name)
		empty_layers = empty_layers and layer != null and layer.get_child_count() == 0
	_assert_true(
		empty_layers
		and map_screen.find_children("*", "TileMapLayer", true, false).is_empty()
		and not FileAccess.file_exists("res://Resources/Json/Map.json")
		and not map_screen.has_node("HUD"),
		"Map is an empty organized canvas without TileSets, authored content, or a local HUD"
	)
	var boundary := world.get_node("BoundaryGuide") as MapBoundaryGuide
	_assert_true(not boundary.visible, "World boundary guide is editor-only and hidden in production")


func _test_fixed_rectangular_bounds(map_screen: MapScreen) -> void:
	var camera := map_screen.map_camera
	_assert_true(
		map_screen.get_world_bounds() == Rect2(0, 0, 6200, 4200)
		and camera.limit_left == 0 and camera.limit_right == 6200
		and camera.limit_top == 0 and camera.limit_bottom == 4200
		and camera.limit_enabled and camera.enabled,
		"Camera uses the fixed 6200x4200 rectangular world limits"
	)
	camera.call("_initialize_position")
	var start := camera.position
	camera.pan_by_screen_delta(Vector2(-120, -90))
	_assert_true(camera.position.x > start.x and camera.position.y > start.y, "Camera is not locked at startup and can travel right/down")
	var half_view: Vector2 = camera.call("_get_half_view_size")
	camera.position = Vector2(3100, 2100)
	camera.pan_by_screen_delta(Vector2(100000, 100000))
	var hit_min := camera.position.is_equal_approx(half_view)
	camera.pan_by_screen_delta(Vector2(-100000, -100000))
	var expected_max := Vector2(6200, 4200) - half_view
	_assert_true(hit_min and camera.position.is_equal_approx(expected_max), "Camera reaches and stops at all rectangular world boundaries")


func _test_mouse_drag(map_screen: MapScreen) -> void:
	var camera := map_screen.map_camera
	camera.position = Vector2(3100, 2100)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	camera.call("_unhandled_input", pressed)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-100, 80)
	var before := camera.position
	camera.call("_unhandled_input", motion)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	camera.call("_unhandled_input", released)
	_assert_true(
		camera.drag_sensitivity == 2.0
		and is_equal_approx(camera.position.x - before.x, 200.0)
		and is_equal_approx(camera.position.y - before.y, -160.0),
		"Desktop left-mouse drag pans both axes at sensitivity 2.0"
	)


func _test_touch_drag(map_screen: MapScreen) -> void:
	var camera := map_screen.map_camera
	camera.position = Vector2(3100, 2100)
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	camera.call("_unhandled_input", touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.relative = Vector2(75, -50)
	var before := camera.position
	camera.call("_unhandled_input", drag)
	touch.pressed = false
	camera.call("_unhandled_input", touch)
	_assert_true(
		is_equal_approx(camera.position.x - before.x, -150.0)
		and is_equal_approx(camera.position.y - before.y, 100.0),
		"Mobile one-finger drag uses the same high-sensitivity pan path"
	)


func _test_zoom_is_disabled(map_screen: MapScreen) -> void:
	var camera := map_screen.map_camera
	var expected_zoom := Vector2.ONE * camera.fixed_zoom
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	camera.call("_unhandled_input", wheel)
	var after_wheel := camera.zoom
	camera.zoom = Vector2(3, 3)
	camera.pan_by_screen_delta(Vector2.ZERO)
	_assert_true(after_wheel == expected_zoom and camera.zoom == expected_zoom, "Mouse wheel and external changes cannot alter the fixed Map zoom")


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)
