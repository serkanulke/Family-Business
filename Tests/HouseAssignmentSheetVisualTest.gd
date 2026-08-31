extends Node

const MAIN_SCENE := preload("res://Scenes/Main/Main.tscn")
const ASSIGNMENT_SCENE := preload("res://Scenes/UI/House/HouseAssignmentSheet.tscn")
const ELIGIBLE_CAPTURE_PATH := "res://Tests/Artifacts/house_assignment_eligible.png"
const EMPTY_CAPTURE_PATH := "res://Tests/Artifacts/house_assignment_empty.png"


func _ready() -> void:
	var original_characters := CharacterManager.characters.duplicate(true)
	var original_houses := HouseManager.houses.duplicate(true)
	var original_money := GameManager.family_money
	_prepare_eligible_state()
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
	var modal := main.house_modal as HouseModal
	var eligible_sheet := ASSIGNMENT_SCENE.instantiate() as HouseAssignmentSheet
	eligible_sheet.setup_role("house_visual", "head_of_household")
	modal.add_child(eligible_sheet)
	await _wait_frames(5)
	await _save_capture(viewport, ELIGIBLE_CAPTURE_PATH)
	eligible_sheet.queue_free()
	await _wait_frames(2)
	CharacterManager.characters = [CharacterManager.characters[0]]
	var empty_sheet := ASSIGNMENT_SCENE.instantiate() as HouseAssignmentSheet
	empty_sheet.setup_role("house_visual", "head_of_household")
	empty_sheet.current_character_id = 0
	modal.add_child(empty_sheet)
	await _wait_frames(5)
	await _save_capture(viewport, EMPTY_CAPTURE_PATH)
	CharacterManager.characters = original_characters
	HouseManager.houses = original_houses
	GameManager.family_money = original_money
	get_tree().quit()


func _prepare_eligible_state() -> void:
	CharacterManager.characters = [
		_character(1, "George", "1960-01-26", "male", "mixed", 80),
		_character(2, "Emma", "1963-01-26", "female", "light", 88)
	]
	HouseManager.restore_save_state({"houses": [{
		"house_instance_id": "house_visual", "house_definition_id": "family_house",
		"property_id": "house_01", "level": 1,
		"role_assignments": {"head_of_household": 1, "cook": null, "housekeeper": null, "caregiver": null},
		"resident_character_ids": []
	}]})
	GameManager.family_money = 999000000


func _character(character_id: int, first_name: String, birth_date: String, gender: String, skin_tone: String, stat_value: int) -> Dictionary:
	return {
		"character_id": character_id, "first_name": first_name, "last_name": "",
		"gender": gender, "genetics": {"skin_tone": skin_tone},
		"portrait_variant_id": "character_001",
		"is_alive": true, "is_player_family": true, "life_stage": "young_adult",
		"birth_date": birth_date, "death_date": null, "parent_ids": [],
		"partner_id": null, "children_ids": [], "is_adopted": false,
		"logic": stat_value, "health": stat_value, "social": stat_value,
		"confidence": stat_value, "discipline": stat_value, "creativity": stat_value,
		"attractiveness": stat_value, "happiness": stat_value,
		"flag_ids": [], "job_id": null, "company_id": null, "salary": 0
	}


func _save_capture(viewport: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if error == OK:
		print("HOUSE ASSIGNMENT VISUAL CAPTURE PASSED: " + path)
	else:
		push_error("House assignment visual capture failed: " + str(error))


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
