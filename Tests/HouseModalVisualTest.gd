extends Node

const MAIN_SCENE := preload("res://Scenes/Main/Main.tscn")
const CAPTURE_PATH := "res://Tests/Artifacts/house_modal_reference.png"


func _ready() -> void:
	var original_characters := CharacterManager.characters.duplicate(true)
	var original_houses := HouseManager.houses.duplicate(true)
	var original_money := GameManager.family_money
	CharacterManager.characters = [{
		"character_id": 1, "first_name": "Emma", "gender": "female",
		"genetics": {"skin_tone": "light"}, "portrait_variant_id": "character_001",
		"portrait_path": "res://Resources/Characters/Female/Light/YoungAdult/character_001.png",
		"is_alive": true, "is_player_family": true, "life_stage": "young_adult",
		"birth_date": "1960-01-26", "death_date": null, "parent_ids": [],
		"partner_id": null, "children_ids": [], "is_adopted": false,
		"logic": 92, "health": 88, "social": 90, "confidence": 89,
		"discipline": 91, "creativity": 88, "attractiveness": 75,
		"happiness": 50, "flag_ids": [], "job_id": null,
		"company_id": null, "salary": 0
	}]
	HouseManager.restore_save_state({"houses": [{
		"house_instance_id": "house_visual", "house_definition_id": "family_house",
		"property_id": "house_01", "level": 1,
		"role_assignments": {"head_of_household": 1, "cook": null, "housekeeper": null, "caregiver": null},
		"resident_character_ids": []
	}]})
	GameManager.family_money = 0
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main := MAIN_SCENE.instantiate() as MainScreenController
	viewport.add_child(main)
	await _wait_frames(4)
	main.show_screen("map")
	await _wait_frames(4)
	main.map_screen.call("_on_property_selected", "house_01")
	await _wait_frames(6)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(CAPTURE_PATH))
	if error == OK:
		print("HOUSE MODAL VISUAL CAPTURE PASSED: " + CAPTURE_PATH)
	else:
		push_error("House Modal visual capture failed: " + str(error))
	CharacterManager.characters = original_characters
	HouseManager.houses = original_houses
	GameManager.family_money = original_money
	get_tree().quit()


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
