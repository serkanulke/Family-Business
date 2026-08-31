extends Node

const MAIN_SCENE := preload("res://Scenes/Main/Main.tscn")
const BUY_CAPTURE := "res://Tests/Artifacts/buy_house_modal_disabled.png"
const INFO_CAPTURE := "res://Tests/Artifacts/house_info_modal.png"


func _ready() -> void:
	var original_houses := HouseManager.houses.duplicate(true)
	var original_money := GameManager.family_money
	HouseManager.houses = []
	GameManager.set_family_money(0)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main := MAIN_SCENE.instantiate() as MainScreenController
	viewport.add_child(main)
	await _wait_frames(4)
	main.show_screen("map")
	await _wait_frames(4)
	main.map_screen.call("_on_property_selected", "house_02")
	await _wait_frames(5)
	await RenderingServer.frame_post_draw
	_save(viewport, BUY_CAPTURE)

	main.buy_house_modal.close_modal()
	HouseManager.restore_save_state({"houses": [{
		"house_instance_id": "house_info_visual",
		"house_definition_id": "family_house",
		"property_id": "house_01",
		"level": 1,
		"role_assignments": {
			"head_of_household": null,
			"cook": null,
			"housekeeper": null,
			"caregiver": null
		},
		"resident_character_ids": []
	}]})
	main.map_screen.call("_on_property_selected", "house_01")
	await _wait_frames(5)
	main.house_modal.call("_open_info_modal")
	await _wait_frames(5)
	await RenderingServer.frame_post_draw
	_save(viewport, INFO_CAPTURE)

	if FileAccess.file_exists(BUY_CAPTURE) and FileAccess.file_exists(INFO_CAPTURE):
		print("HOUSE PURCHASE AND INFO VISUAL CAPTURES PASSED.")
	else:
		push_error("House purchase/info visual capture failed.")
	HouseManager.houses = original_houses
	GameManager.set_family_money(original_money)
	get_tree().quit()


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _save(viewport: SubViewport, path: String) -> void:
	var image := viewport.get_texture().get_image()
	if image == null or image.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("Could not save visual capture: " + path)
