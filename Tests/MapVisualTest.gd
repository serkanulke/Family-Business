extends Node

const MAP_SCENE := preload("res://UI/Map.tscn")


func _ready() -> void:
	var render_viewport := SubViewport.new()
	render_viewport.size = Vector2i(1080, 1920)
	render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	render_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(render_viewport)
	var map_screen := MAP_SCENE.instantiate() as MapScreen
	render_viewport.add_child(map_screen)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var camera: MapCamera = map_screen.get_node("World/MapCamera")
	var hud: CanvasLayer = map_screen.get_node("HUD")

	hud.visible = false
	camera.zoom = Vector2.ONE * 0.105
	camera.position = camera.content_bounds.get_center()
	await _capture(render_viewport, "res://Tests/Artifacts/map_production_overview.png")

	hud.visible = true
	camera.zoom = Vector2.ONE * 0.55
	camera.position = MapCoordinateHelper.main_grid_to_world(Vector2i(8, 8))
	await _capture(render_viewport, "res://Tests/Artifacts/map_production_waterfront.png")
	camera.position = MapCoordinateHelper.main_grid_to_world(Vector2i(25, 14))
	await _capture(render_viewport, "res://Tests/Artifacts/map_production_downtown.png")
	camera.position = MapCoordinateHelper.main_grid_to_world(Vector2i(8, 32))
	await _capture(render_viewport, "res://Tests/Artifacts/map_production_residential.png")
	camera.position = MapCoordinateHelper.main_grid_to_world(Vector2i(37, 37))
	await _capture(render_viewport, "res://Tests/Artifacts/map_production_industrial.png")

	print("MAP VISUAL CAPTURES COMPLETE.")
	get_tree().quit()


func _capture(render_viewport: SubViewport, path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := render_viewport.get_texture().get_image()
	var result := image.save_png(path)
	if result != OK:
		push_error("Map capture failed: " + path)
