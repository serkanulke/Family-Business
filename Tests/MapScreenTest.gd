extends Node

const MAP_SCENE := preload("res://UI/Map.tscn")

var passed := 0
var failed := 0
var saved_businesses: Array = []


func _ready() -> void:
	saved_businesses = BusinessManager.businesses.duplicate(true)
	await _run_tests()
	BusinessManager.businesses = saved_businesses
	print("Map screen tests: %d passed / %d failed" % [passed, failed])
	if failed == 0:
		print("ALL MAP SCREEN TESTS PASSED.")
	else:
		push_error("Map screen has %d failing test(s)." % failed)


func _run_tests() -> void:
	var map_screen := MAP_SCENE.instantiate() as MapScreen
	add_child(map_screen)
	await get_tree().process_frame
	await get_tree().process_frame
	_test_validation_report(map_screen)
	_test_scene_hierarchy_and_alignment(map_screen)
	_test_property_counts(map_screen)
	_test_land_capacity_rules()
	_test_business_modal_and_worker_tag(map_screen)
	_test_camera_controls(map_screen)
	_test_map_hud(map_screen)
	map_screen.queue_free()


func _test_validation_report(map_screen: MapScreen) -> void:
	var report := map_screen.get_validation_report()
	_assert_true(
		bool(report.get("valid", false))
		and (report.get("errors", []) as Array).is_empty(),
		"Authored Map.json passes footprint, count, projection, asset and bike-route validation"
	)


func _test_scene_hierarchy_and_alignment(map_screen: MapScreen) -> void:
	var main_layer := map_screen.get_node("World/MainGrid/MainGround") as TileMapLayer
	var detail_layer := map_screen.get_node("World/DetailGrid/DetailGroundPaths") as TileMapLayer
	var aligned := true
	for sample in [Vector2i.ZERO, Vector2i(1, 1), Vector2i(7, 13), Vector2i(48, 48)]:
		var main_center := main_layer.position + main_layer.map_to_local(sample)
		var detail_base: Vector2i = sample * 4
		var main_corners := PackedVector2Array([
			main_center + Vector2(0, -50), main_center + Vector2(100, 0),
			main_center + Vector2(0, 50), main_center + Vector2(-100, 0)
		])
		var detail_corners := PackedVector2Array([
			detail_layer.position + detail_layer.map_to_local(detail_base) + Vector2(0, -12.5),
			detail_layer.position + detail_layer.map_to_local(detail_base + Vector2i(3, 0)) + Vector2(25, 0),
			detail_layer.position + detail_layer.map_to_local(detail_base + Vector2i(3, 3)) + Vector2(0, 12.5),
			detail_layer.position + detail_layer.map_to_local(detail_base + Vector2i(0, 3)) + Vector2(-25, 0)
		])
		if main_corners != detail_corners:
			aligned = false
	_assert_true(
		main_layer.tile_set.tile_size == Vector2i(200, 100)
		and detail_layer.tile_set.tile_size == Vector2i(50, 25)
		and aligned
		and map_screen.has_node("World/MainGrid/Roads")
		and map_screen.has_node("World/MainGrid/PlotBuildingGround")
		and map_screen.has_node("World/MainGrid/CoastGround")
		and map_screen.has_node("World/TallObjects/EnvironmentDecorations")
		and map_screen.has_node("World/TallObjects/Buildings"),
		"Map scene exposes separated editable layers and exact 4x4 grid alignment"
	)


func _test_property_counts(map_screen: MapScreen) -> void:
	var counts: Dictionary = map_screen.get_validation_report().get("counts", {})
	var businesses: Dictionary = counts.get("businesses", {})
	_assert_true(
		int(businesses.get("stadium", 0)) == 1
		and int(businesses.get("cruise", 0)) == 1
		and int(businesses.get("cafe", 0)) == 5
		and int(businesses.get("restaurant", 0)) == 5
		and int(businesses.get("hotel", 0)) == 5
		and int(counts.get("houses_total", 0)) == 24
		and int(counts.get("houses_purchasable", 0)) == 10
		and int(counts.get("land_2x2", 0)) == 3
		and int(counts.get("land_4x4", 0)) == 3,
		"Production city has the approved business, house and land counts"
	)


func _test_land_capacity_rules() -> void:
	_assert_true(
		MapDataValidator.land_accepts_footprint("2x2", Vector2i(2, 2))
		and not MapDataValidator.land_accepts_footprint("2x2", Vector2i(3, 2))
		and MapDataValidator.land_accepts_footprint("4x4", Vector2i(2, 2))
		and MapDataValidator.land_accepts_footprint("4x4", Vector2i(3, 3))
		and MapDataValidator.land_accepts_footprint("4x4", Vector2i(4, 3))
		and MapDataValidator.land_accepts_footprint("4x4", Vector2i(4, 4))
		and not MapDataValidator.land_accepts_footprint("4x4", Vector2i(1, 3), true),
		"2x2 and 4x4 land capacity rules accept fitting buildings and exclude Cruise"
	)


func _test_business_modal_and_worker_tag(map_screen: MapScreen) -> void:
	var unsupported_purchase: Array = []
	map_screen.property_purchase_requested.connect(
		func(
			_property_id: String,
			_category: String,
			_reference_id: String,
			purchase_cost: Variant,
			backend_available: bool
		) -> void:
			unsupported_purchase.assign([purchase_cost, backend_available])
	)
	BusinessManager.businesses = [
		{
			"business_instance_id": "map_test_hospital",
			"business_type_id": "hospital",
			"visual_variant_id": "",
			"plot_id": "hospital_01",
			"level": 1,
			"slots": [
				{"slot_id": "doctor_01", "assigned_character_id": 77, "assigned_npc_id": null},
				{"slot_id": "nurse_01", "assigned_character_id": null, "assigned_npc_id": null},
				{"slot_id": "cleaner_01", "assigned_character_id": null, "assigned_npc_id": "npc_map_test"}
			]
		}
	]
	map_screen.refresh_from_managers()
	var property_node: MapProperty = map_screen.property_nodes.get("hospital_01")
	var state_label := property_node.get_node("PropertyTag/Margin/Rows/State") as Label
	map_screen.call("_on_property_selected", "hospital_01")
	map_screen.call("_on_property_selected", "cruise_01")
	_assert_true(
		state_label.text == "2 / 3 staff"
		and map_screen.business_modal.visible
		and map_screen.business_modal.business_instance_id == "map_test_hospital",
		"Owned map property shows occupied active slots and opens the exact BusinessModal instance"
	)
	_assert_true(
		unsupported_purchase.size() == 2
		and unsupported_purchase[0] == null
		and not bool(unsupported_purchase[1]),
		"Unbalanced business selection reports no invented purchase price or available backend"
	)
	map_screen.business_modal.close_modal()


func _test_camera_controls(map_screen: MapScreen) -> void:
	var camera: MapCamera = map_screen.get_node("World/MapCamera")
	camera.call("_set_zoom_value", 99.0)
	var max_is_clamped := is_equal_approx(camera.zoom.x, camera.max_zoom)
	camera.call("_set_zoom_value", 0.01)
	_assert_true(
		max_is_clamped
		and is_equal_approx(camera.zoom.x, camera.min_zoom)
		and camera.content_bounds.size.x > 1080.0,
		"Map camera exposes bounded portrait-friendly pan and zoom limits"
	)


func _test_map_hud(map_screen: MapScreen) -> void:
	var hud_root := map_screen.get_node("HUD/HUDRoot") as Control
	var date_label := hud_root.find_child("DateValue", true, false) as Label
	var money_label := hud_root.find_child("MoneyValue", true, false) as Label
	var diamond_label := hud_root.find_child("DiamondValue", true, false) as Label
	_assert_true(
		date_label != null and not date_label.text.is_empty()
		and money_label != null and not money_label.text.is_empty()
		and diamond_label != null and not diamond_label.text.is_empty()
		and map_screen.get_node_or_null("HUD/HUDRoot/TimeControls") == null,
		"Map HUD shows date, Money and Diamonds without Family Tree time controls"
	)


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)
