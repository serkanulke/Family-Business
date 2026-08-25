extends Node

const MAIN_SCENE := preload("res://Scenes/Main/Main.tscn")
const CAPTURE_PATH := "res://Tests/Artifacts/map_empty_navigation.png"


func _ready() -> void:
	var render_viewport := SubViewport.new()
	render_viewport.size = Vector2i(1080, 1920)
	render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	render_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(render_viewport)
	var main_instance := MAIN_SCENE.instantiate()
	render_viewport.add_child(main_instance)
	await get_tree().process_frame
	await get_tree().process_frame
	main_instance.call("show_screen", "map")
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := render_viewport.get_texture().get_image()
	var result := image.save_png(CAPTURE_PATH)
	if result != OK: push_error("Map navigation capture failed: " + CAPTURE_PATH)
	else: print("MAP EMPTY NAVIGATION CAPTURE COMPLETE: " + CAPTURE_PATH)
	get_tree().quit()
