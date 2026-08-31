extends Node

const MAIN_SCENE := preload("res://Scenes/Main/Main.tscn")
const CAPTURE_PATH := "res://Tests/Artifacts/map_property_tag_readability.png"


func _ready() -> void:
	var original_businesses := BusinessManager.businesses.duplicate(true)
	BusinessManager.businesses = [{
		"business_instance_id": "business_tag_visual_test",
		"business_type_id": "hospital",
		"plot_id": "hospital_01",
		"level": 1,
		"slots": [
			{"slot_id": "doctor_01", "assigned_character_id": 101, "assigned_npc_id": null},
			{"slot_id": "doctor_02", "assigned_character_id": null, "assigned_npc_id": null},
			{"slot_id": "nurse_01", "assigned_character_id": null, "assigned_npc_id": null},
		],
	}]
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
	var map_screen := main_instance.get_node("World/MapScreen") as MapScreen
	var hospital := map_screen.get_node(
		"MapWorld/Buildings/Interactive/Hospital_01"
	) as MapProperty
	map_screen.map_camera.position = hospital.to_global(
		hospital.property_tag.position + hospital.property_tag.size * 0.5
	)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := render_viewport.get_texture().get_image()
	var result := image.save_png(CAPTURE_PATH)
	if result != OK: push_error("Map property tag capture failed: " + CAPTURE_PATH)
	else: print("MAP PROPERTY TAG CAPTURE COMPLETE: " + CAPTURE_PATH)
	BusinessManager.businesses = original_businesses
	get_tree().quit()
