extends Node

const MAP_SCENE := preload("res://UI/Map.tscn")

var passed := 0
var failed := 0
var selected_property_ids: Array[String] = []


func _ready() -> void:
	var map_screen := MAP_SCENE.instantiate() as MapScreen
	add_child(map_screen)
	await get_tree().process_frame
	await get_tree().process_frame
	_test_authoring_scene_structure(map_screen)
	_test_authored_property_inventory(map_screen)
	_test_runtime_generated_property_mode()
	_test_property_interaction_geometry(map_screen)
	_test_property_router_and_drag_threshold(map_screen)
	_test_property_tag_readability(map_screen)
	await _test_tag_input_does_not_pan_camera(map_screen)
	_test_business_property_refresh(map_screen)
	_test_fixed_rectangular_bounds(map_screen)
	_test_mouse_drag(map_screen)
	_test_touch_drag(map_screen)
	_test_zoom_is_disabled(map_screen)
	print("Map infrastructure tests: %d passed / %d failed" % [passed, failed])
	if failed == 0: print("ALL MAP INFRASTRUCTURE TESTS PASSED.")
	else: push_error("Map infrastructure has %d failing test(s)." % failed)
	map_screen.queue_free()


func _test_authoring_scene_structure(map_screen: MapScreen) -> void:
	var world := map_screen.get_node("MapWorld")
	var required_layers_exist := true
	for layer_name in ["Ground", "Roads", "Plots", "Buildings", "Environment", "Interactions"]:
		var layer := world.get_node_or_null(layer_name)
		required_layers_exist = required_layers_exist and layer != null
	_assert_true(
		required_layers_exist
		and not map_screen.has_node("HUD"),
		"Map keeps its organized authoring layers without a duplicate local HUD"
	)
	_assert_true(
		world.get_node("Buildings/Interactive") is Node2D
		and world.get_node("Buildings/Decorative") is Node2D,
		"Building group containers preserve the CanvasItem visibility chain"
	)
	var boundary := world.get_node("BoundaryGuide") as MapBoundaryGuide
	_assert_true(not boundary.visible, "World boundary guide is editor-only and hidden in production")


func _test_authored_property_inventory(map_screen: MapScreen) -> void:
	var category_counts := {
		"family_business": 0,
		"house": 0,
		"land": 0,
	}
	var property_ids: Dictionary = {}
	var metadata_is_valid := true
	var single_authored_visual := true
	for map_property in map_screen.get_map_properties():
		var data := map_property.get_property_data()
		var property_id := str(data.get("property_id", ""))
		var category := str(data.get("category", ""))
		metadata_is_valid = metadata_is_valid and not property_id.is_empty()
		metadata_is_valid = metadata_is_valid and not property_ids.has(property_id)
		property_ids[property_id] = true
		if category_counts.has(category):
			category_counts[category] += 1
		else:
			metadata_is_valid = false
		if category == "family_business":
			metadata_is_valid = metadata_is_valid and not BusinessManager.get_business_type_by_id(
				str(data.get("business_type_id", ""))
			).is_empty()
		single_authored_visual = single_authored_visual and map_property.visual != null
		single_authored_visual = single_authored_visual and map_property.find_children(
			"*", "Sprite2D", true, false
		).size() == 1
	_assert_true(
		map_screen.get_map_properties().size() == 68
		and category_counts["family_business"] == 52
		and category_counts["house"] == 10
		and category_counts["land"] == 6,
		"Authored Map exposes 52 family businesses, 10 houses, and 6 land properties"
	)
	_assert_true(
		metadata_is_valid
		and property_ids.has("stadium_01")
		and property_ids.has("cruise_01")
		and property_ids.has("house_10")
		and property_ids.has("land_2x2_03")
		and property_ids.has("land_4x4_03"),
		"Every interactive property has a unique stable ID and authoritative category metadata"
	)
	_assert_true(
		single_authored_visual,
		"MapProperty reuses exactly one authored Sprite2D without generating duplicates"
	)
	var decorative := map_screen.get_node("MapWorld/Buildings/Decorative")
	_assert_true(
		decorative.find_children("*", "MapProperty", true, false).is_empty()
		and decorative.find_children("*", "Area2D", true, false).is_empty(),
		"Decorative buildings remain outside property interaction"
	)


func _test_runtime_generated_property_mode() -> void:
	var runtime_property := MapProperty.new()
	add_child(runtime_property)
	runtime_property.configure({
		"property_id": "runtime_cafe_test",
		"category": "family_business",
		"business_type_id": "cafe",
		"footprint": [2, 2],
		"purchasable": true,
	})
	_assert_true(
		runtime_property.visual != null
		and runtime_property.visual.name == "BuildingVisual"
		and runtime_property.interaction_area != null
		and runtime_property.property_tag != null
		and runtime_property.find_children("*", "Sprite2D", true, false).size() == 1,
		"Runtime-generated MapProperty visual mode remains available"
	)
	runtime_property.queue_free()


func _test_property_interaction_geometry(map_screen: MapScreen) -> void:
	var geometry_is_valid := true
	for property_id in ["cafe_01", "hotel_01", "cruise_01", "land_4x4_01"]:
		var map_property := map_screen.get_node(
			"MapWorld/Buildings/Interactive/" + _node_name_for_property(property_id)
		) as MapProperty
		var data := map_property.get_property_data()
		var footprint_value: Array = data.get("footprint", [])
		var footprint := Vector2i(int(footprint_value[0]), int(footprint_value[1]))
		var rect := map_property.visual.get_rect()
		var visual_south := Vector2(rect.get_center().x, rect.end.y)
		var expected_anchor := map_property.to_local(map_property.visual.to_global(visual_south))
		var collision := map_property.interaction_area.get_node("FootprintCollision") as CollisionPolygon2D
		geometry_is_valid = geometry_is_valid and map_property.interaction_area.position.is_equal_approx(expected_anchor)
		geometry_is_valid = geometry_is_valid and collision.polygon == MapCoordinateHelper.get_footprint_polygon(footprint)
	_assert_true(
		geometry_is_valid,
		"Collision diamonds use true 2:1 footprints anchored to each authored texture transform"
	)
	var cruise := map_screen.get_node("MapWorld/Buildings/Interactive/Cruise") as MapProperty
	_assert_true(
		not cruise.visual.scale.is_equal_approx(Vector2.ONE)
		and cruise.interaction_area.position.y > cruise.visual.position.y,
		"Cruise collision anchor accounts for its authored Sprite2D scale"
	)


func _test_property_router_and_drag_threshold(map_screen: MapScreen) -> void:
	selected_property_ids.clear()
	if not map_screen.property_selected.is_connected(_on_property_selected):
		map_screen.property_selected.connect(_on_property_selected)
	_simulate_footprint_tap(map_screen, "Cafe_01")
	_simulate_footprint_tap(map_screen, "House_01")
	_simulate_footprint_tap(map_screen, "Land_2x2_01")
	_assert_true(
		selected_property_ids.is_empty(),
		"Business, House, and Land footprints remain present but are disabled for selection"
	)
	_simulate_tag_tap(map_screen, "Cafe_01")
	_simulate_tag_tap(map_screen, "House_01")
	_simulate_tag_tap(map_screen, "Land_2x2_01")
	_assert_true(
		selected_property_ids == ["cafe_01", "house_01", "land_2x2_01"],
		"Business, House, and Land Property Tags route stable IDs through MapScreen"
	)
	selected_property_ids.clear()
	var map_property := map_screen.get_node("MapWorld/Buildings/Interactive/Cafe_01") as MapProperty
	var tag := map_property.property_tag
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = Vector2(100, 100)
	tag.call("_gui_input", pressed)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(140, 100)
	tag.call("_gui_input", motion)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = Vector2(140, 100)
	tag.call("_gui_input", released)
	_assert_true(
		selected_property_ids.is_empty(),
		"Business tag drag beyond the existing threshold does not emit a click"
	)


func _test_property_tag_readability(map_screen: MapScreen) -> void:
	var cafe := map_screen.get_node("MapWorld/Buildings/Interactive/Cafe_01") as MapProperty
	var tag := cafe.property_tag
	var title_size := tag.title_label.get_theme_font_size("font_size")
	var state_size := tag.state_label.get_theme_font_size("font_size")
	var rendered_scale: float = tag.get_global_transform().x.length()
	var rows := tag.get_node("Margin/Rows") as VBoxContainer
	var tag_inverse := tag.get_global_transform().affine_inverse()
	var title_center := tag_inverse * (
		tag.title_label.get_global_transform() * (tag.title_label.size * 0.5)
	)
	var state_center := tag_inverse * (
		tag.state_label.get_global_transform() * (tag.state_label.size * 0.5)
	)
	_assert_true(
		tag.custom_minimum_size == Vector2(240, 92)
		and title_size == 24
		and state_size == 20
		and float(title_size) * rendered_scale >= 20.0
		and float(state_size) * rendered_scale >= 20.0,
		"Property tag renders 24 px title and at least 20 px state text at authored Map scale"
	)
	_assert_true(
		tag.title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and tag.state_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and tag.title_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL
		and tag.state_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL
		and rows.size_flags_horizontal == Control.SIZE_EXPAND_FILL
		and rows.alignment == BoxContainer.ALIGNMENT_CENTER
		and is_equal_approx(title_center.x, tag.size.x * 0.5)
		and is_equal_approx(state_center.x, tag.size.x * 0.5),
		"Property name and state rows share the exact geometric card center"
	)
	_assert_true(
		tag.mouse_filter == Control.MOUSE_FILTER_STOP
		and cafe.interaction_area.input_pickable == false,
		"Business tag card is the primary full-card input target"
	)


func _test_tag_input_does_not_pan_camera(map_screen: MapScreen) -> void:
	selected_property_ids.clear()
	var cafe := map_screen.get_node("MapWorld/Buildings/Interactive/Cafe_01") as MapProperty
	var tag := cafe.property_tag
	var camera := map_screen.map_camera
	camera.position = cafe.to_global(tag.position + tag.size * 0.5)
	await get_tree().process_frame
	var screen_position := tag.get_global_transform_with_canvas() * (tag.size * 0.5)
	var before := camera.position
	var tap_pressed := InputEventMouseButton.new()
	tap_pressed.button_index = MOUSE_BUTTON_LEFT
	tap_pressed.pressed = true
	tap_pressed.position = screen_position
	tap_pressed.global_position = screen_position
	get_viewport().push_input(tap_pressed, true)
	await get_tree().process_frame
	var tap_released := InputEventMouseButton.new()
	tap_released.button_index = MOUSE_BUTTON_LEFT
	tap_released.pressed = false
	tap_released.position = screen_position
	tap_released.global_position = screen_position
	get_viewport().push_input(tap_released, true)
	await get_tree().process_frame
	_assert_true(
		selected_property_ids == ["cafe_01"]
		and camera.position.is_equal_approx(before),
		"Real viewport tap on the full business card routes its stable ID without panning"
	)
	selected_property_ids.clear()
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = screen_position
	pressed.global_position = screen_position
	get_viewport().push_input(pressed, true)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = screen_position + Vector2(40, 0)
	motion.global_position = motion.position
	motion.relative = Vector2(40, 0)
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = motion.position
	released.global_position = released.position
	get_viewport().push_input(released, true)
	await get_tree().process_frame
	_assert_true(
		camera.position.is_equal_approx(before)
		and selected_property_ids.is_empty(),
		"Pointer drag over the tag is consumed by the card and cannot pan or select the Map"
	)


func _test_business_property_refresh(map_screen: MapScreen) -> void:
	var original_businesses := BusinessManager.businesses.duplicate(true)
	BusinessManager.businesses = [{
		"business_instance_id": "business_map_test",
		"business_type_id": "cafe",
		"plot_id": "cafe_01",
		"level": 1,
		"slots": [
			{"slot_id": "manager_01", "assigned_character_id": null, "assigned_npc_id": null},
			{"slot_id": "barista_01", "assigned_character_id": null, "assigned_npc_id": null},
			{"slot_id": "barista_02", "assigned_character_id": null, "assigned_npc_id": null},
		],
	}]
	map_screen.refresh_from_managers()
	var owned := map_screen.get_node("MapWorld/Buildings/Interactive/Cafe_01") as MapProperty
	var unowned := map_screen.get_node("MapWorld/Buildings/Interactive/Cafe_02") as MapProperty
	var warning_style := owned.property_tag.warning_style as StyleBoxFlat
	var normal_style := owned.property_tag.normal_style as StyleBoxFlat
	_assert_true(
		owned.property_tag.state_label.text == "0 / 3 staff"
		and owned.property_tag.is_warning_state
		and owned.property_tag.get_theme_stylebox("panel") == warning_style
		and warning_style != null and normal_style != null
		and warning_style.bg_color.r > warning_style.bg_color.g + 0.15
		and warning_style.bg_color.r > warning_style.bg_color.b + 0.15
		and unowned.property_tag.state_label.text == "For Sale"
		and not unowned.property_tag.is_warning_state
		and unowned.property_tag.get_theme_stylebox("panel") == normal_style,
		"Owned understaffing uses a visibly red background while For Sale stays normal"
	)
	var business: Dictionary = BusinessManager.businesses[0]
	var slots: Array = business["slots"]
	slots[0]["assigned_character_id"] = 101
	BusinessManager.family_business_slot_changed.emit(
		"business_map_test", "manager_01", 101
	)
	_assert_true(
		owned.property_tag.state_label.text == "1 / 3 staff"
		and owned.property_tag.is_warning_state
		and owned.property_tag.get_theme_stylebox("panel") == warning_style,
		"Character staffing signal refreshes the authoritative Map count immediately"
	)
	slots[1]["assigned_npc_id"] = "worker_map_test"
	BusinessManager.family_business_npc_slot_changed.emit(
		"business_map_test", "barista_01", "worker_map_test"
	)
	slots[2]["assigned_character_id"] = 102
	BusinessManager.family_business_slot_changed.emit(
		"business_map_test", "barista_02", 102
	)
	_assert_true(
		owned.property_tag.state_label.text == "3 / 3 staff"
		and not owned.property_tag.is_warning_state
		and owned.property_tag.get_theme_stylebox("panel") == normal_style,
		"Fully staffed business returns to the normal tag treatment"
	)
	slots[2]["assigned_character_id"] = null
	BusinessManager.family_business_slot_changed.emit(
		"business_map_test", "barista_02", 0
	)
	_assert_true(
		owned.property_tag.state_label.text == "2 / 3 staff"
		and owned.property_tag.is_warning_state
		and owned.property_tag.get_theme_stylebox("panel") == warning_style,
		"Worker removal signal restores the understaffed warning without reopening Map"
	)
	BusinessManager.businesses = original_businesses
	map_screen.refresh_from_managers()


func _simulate_footprint_tap(map_screen: MapScreen, node_name: String) -> void:
	var map_property := map_screen.get_node("MapWorld/Buildings/Interactive/" + node_name) as MapProperty
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = Vector2(100, 100)
	map_property.call("_on_input_event", get_viewport(), pressed, 0)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = Vector2(100, 100)
	map_property.call("_on_input_event", get_viewport(), released, 0)


func _simulate_tag_tap(map_screen: MapScreen, node_name: String) -> void:
	var map_property := map_screen.get_node("MapWorld/Buildings/Interactive/" + node_name) as MapProperty
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = map_property.property_tag.size * 0.5
	map_property.property_tag.call("_gui_input", pressed)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = pressed.position
	map_property.property_tag.call("_gui_input", released)


func _node_name_for_property(property_id: String) -> String:
	match property_id:
		"cafe_01":
			return "Cafe_01"
		"hotel_01":
			return "Hotel_01"
		"cruise_01":
			return "Cruise"
		"land_4x4_01":
			return "Land_4x4_01"
	return ""


func _on_property_selected(property_id: String) -> void:
	selected_property_ids.append(property_id)


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
