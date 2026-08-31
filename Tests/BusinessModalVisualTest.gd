extends Node

const MAIN_SCENE := preload("res://Scenes/Main/Main.tscn")
const CAPTURE_PATH := "res://Tests/Artifacts/business_modal_disabled_upgrade.png"


func _ready() -> void:
	var original_businesses := BusinessManager.businesses.duplicate(true)
	var original_next_id := BusinessManager.next_business_instance_number
	var original_money := GameManager.family_money
	BusinessManager.businesses = []
	BusinessManager.next_business_instance_number = 1
	GameManager.set_family_money(500_000)
	var business := BusinessManager.create_business_instance("hospital", "hospital_01", false)
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
	main.map_screen.call("_on_property_selected", "hospital_01")
	await _wait_frames(6)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(CAPTURE_PATH))
	var small_icon_removed := main.business_modal.find_child("BusinessIcon", true, false) == null
	if (
		error == OK
		and not business.is_empty()
		and main.business_modal.upgrade_button.disabled
		and small_icon_removed
	):
		print("BUSINESS MODAL DISABLED-UPGRADE VISUAL CAPTURE PASSED.")
	else:
		push_error("Business Modal disabled-upgrade visual capture failed.")
	BusinessManager.businesses = original_businesses
	BusinessManager.next_business_instance_number = original_next_id
	GameManager.set_family_money(original_money)
	get_tree().quit()


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
