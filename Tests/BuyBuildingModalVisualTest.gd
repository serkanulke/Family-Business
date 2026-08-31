extends Node

const MAIN_SCENE := preload("res://Scenes/Main/Main.tscn")
const BUY_CAPTURE_PATH := "res://Tests/Artifacts/buy_building_modal_hospital.png"
const INSUFFICIENT_CAPTURE_PATH := "res://Tests/Artifacts/buy_building_modal_insufficient_funds.png"
const OWNED_CAPTURE_PATH := "res://Tests/Artifacts/buy_building_modal_after_purchase.png"


func _ready() -> void:
	var original_businesses := BusinessManager.businesses.duplicate(true)
	var original_money := GameManager.family_money
	var original_next_id := BusinessManager.next_business_instance_number
	BusinessManager.businesses = []
	BusinessManager.next_business_instance_number = 1
	GameManager.set_family_money(0)

	var render_viewport := SubViewport.new()
	render_viewport.size = Vector2i(1080, 1920)
	render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	render_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(render_viewport)
	var main := MAIN_SCENE.instantiate() as MainScreenController
	render_viewport.add_child(main)
	await _wait_frames(4)
	main.show_screen("map")
	await _wait_frames(5)
	main.map_screen.map_camera.position = Vector2(4200, 1019)
	main.map_screen.call("_on_property_selected", "hospital_01")
	await _wait_frames(5)
	await RenderingServer.frame_post_draw
	_save_viewport_capture(render_viewport, INSUFFICIENT_CAPTURE_PATH)
	var insufficient_state_is_valid := (
		main.buy_building_modal.buy_button.disabled
		and main.buy_building_modal.feedback_label.text.is_empty()
		and not main.buy_building_modal.feedback_label.visible
	)

	GameManager.set_family_money(500_000)
	await _wait_frames(3)
	await RenderingServer.frame_post_draw
	_save_viewport_capture(render_viewport, BUY_CAPTURE_PATH)

	main.buy_building_modal.call("_on_buy_pressed")
	await _wait_frames(7)
	await RenderingServer.frame_post_draw
	_save_viewport_capture(render_viewport, OWNED_CAPTURE_PATH)

	var purchased := BusinessManager.get_business_on_plot("hospital_01")
	if (
		FileAccess.file_exists(BUY_CAPTURE_PATH)
		and FileAccess.file_exists(INSUFFICIENT_CAPTURE_PATH)
		and FileAccess.file_exists(OWNED_CAPTURE_PATH)
		and insufficient_state_is_valid
		and not purchased.is_empty()
		and main.business_modal.visible
	):
		print("BUY BUILDING MODAL VISUAL CAPTURES PASSED.")
	else:
		push_error("Buy Building Modal visual capture failed.")

	BusinessManager.businesses = original_businesses
	BusinessManager.next_business_instance_number = original_next_id
	GameManager.set_family_money(original_money)
	get_tree().quit()


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _save_viewport_capture(viewport: SubViewport, path: String) -> void:
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("Could not read visual capture viewport: " + path)
		return
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Could not save visual capture: " + path)
