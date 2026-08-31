extends Node
class_name MainScreenController

const MAP_SCENE := preload("res://UI/Map.tscn")

@onready var world: Node = $World
@onready var family_tree_screen: FamilyTreeScreen = $World/FamilyTreeScreen
@onready var main_hud: MainHUD = $SharedUI/MainHUD
@onready var business_modal: BusinessModal = $ModalLayer/BusinessModal
@onready var buy_building_modal: BuyBuildingModal = $ModalLayer/BuyBuildingModal
@onready var house_modal: HouseModal = $ModalLayer/HouseModal
@onready var buy_house_modal: BuyHouseModal = $ModalLayer/BuyHouseModal

var map_screen: MapScreen


func _ready() -> void:
	if not main_hud.screen_requested.is_connected(_on_screen_requested):
		main_hud.screen_requested.connect(_on_screen_requested)
	if not buy_building_modal.purchase_completed.is_connected(_on_building_purchase_completed):
		buy_building_modal.purchase_completed.connect(_on_building_purchase_completed)
	if not buy_building_modal.closed.is_connected(_on_shared_modal_closed):
		buy_building_modal.closed.connect(_on_shared_modal_closed)
	if not business_modal.closed.is_connected(_on_shared_modal_closed):
		business_modal.closed.connect(_on_shared_modal_closed)
	if not house_modal.closed.is_connected(_on_shared_modal_closed):
		house_modal.closed.connect(_on_shared_modal_closed)
	if not buy_house_modal.closed.is_connected(_on_shared_modal_closed):
		buy_house_modal.closed.connect(_on_shared_modal_closed)
	if not buy_house_modal.purchase_completed.is_connected(_on_house_purchase_completed):
		buy_house_modal.purchase_completed.connect(_on_house_purchase_completed)
	_show_family_tree()


func show_screen(screen_id: String) -> void:
	_on_screen_requested(screen_id)


func _on_screen_requested(screen_id: String) -> void:
	match screen_id:
		"map":
			_show_map()
		"family_tree":
			_show_family_tree()


func _show_map() -> void:
	_close_shared_modals()
	if map_screen == null:
		map_screen = MAP_SCENE.instantiate() as MapScreen
		map_screen.name = "MapScreen"
		world.add_child(map_screen)
		if not map_screen.property_selected.is_connected(_on_map_property_selected):
			map_screen.property_selected.connect(_on_map_property_selected)
	_set_family_tree_active(false)
	map_screen.set_screen_active(true)
	map_screen.refresh_from_managers()
	main_hud.set_active_screen("map")
	main_hud.refresh_from_managers()


func _show_family_tree() -> void:
	_close_shared_modals()
	if map_screen != null:
		map_screen.set_screen_active(false)
	_set_family_tree_active(true)
	family_tree_screen.refresh_from_managers()
	main_hud.set_active_screen("family_tree")
	main_hud.refresh_from_managers()


func _set_family_tree_active(active: bool) -> void:
	family_tree_screen.visible = active
	family_tree_screen.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if family_tree_screen.has_method("set_screen_active"):
		family_tree_screen.call("set_screen_active", active)
	var family_camera := family_tree_screen.family_tree_camera
	if family_camera != null:
		family_camera.enabled = active
		if active:
			family_camera.make_current()


func _on_map_property_selected(property_id: String) -> void:
	if map_screen == null:
		return
	var property_data := map_screen.get_property_data(property_id)
	if property_data.is_empty():
		return
	var category := str(property_data.get("category", ""))
	if category == "house":
		_open_house_property(property_id)
		return
	if category != "family_business":
		return
	var property_business_type_id := str(property_data.get("business_type_id", ""))
	if property_business_type_id.is_empty():
		return
	var business: Dictionary = BusinessManager.get_business_on_plot(property_id)
	if business.is_empty():
		if business_modal.visible:
			business_modal.close_modal()
		var opened := buy_building_modal.open_for_property(
			property_id,
			property_business_type_id
		)
		if opened:
			_set_map_modal_input_blocked(true)
		return
	if str(business.get("business_type_id", "")) != property_business_type_id:
		push_warning("Map property/business type mismatch for plot: " + property_id)
		return
	var business_instance_id := str(business.get("business_instance_id", ""))
	if business_instance_id.is_empty():
		return
	if buy_building_modal.visible:
		buy_building_modal.close_modal()
	business_modal.open_for_business(business_instance_id)
	_set_map_modal_input_blocked(true)


func _open_house_property(property_id: String) -> void:
	var house := HouseManager.get_house_on_property(property_id)
	if house.is_empty():
		if house_modal.visible:
			house_modal.close_modal()
		if buy_house_modal.open_for_property(property_id):
			_set_map_modal_input_blocked(true)
		return
	if buy_house_modal.visible:
		buy_house_modal.close_modal()
	var house_instance_id := str(house.get("house_instance_id", ""))
	if house_modal.open_for_house(house_instance_id):
		_set_map_modal_input_blocked(true)


func _on_house_purchase_completed(
	house_instance_id: String,
	property_id: String
) -> void:
	var house := HouseManager.get_house_by_instance_id(house_instance_id)
	if house.is_empty() or str(house.get("property_id", "")) != property_id:
		return
	if map_screen != null:
		map_screen.refresh_from_managers()
	main_hud.refresh_from_managers()
	house_modal.open_for_house(house_instance_id)
	_set_map_modal_input_blocked(true)


func _on_building_purchase_completed(
	business_instance_id: String,
	property_id: String
) -> void:
	var business := BusinessManager.get_business_by_instance_id(
		business_instance_id
	)
	if business.is_empty():
		return
	if str(business.get("plot_id", "")) != property_id:
		push_warning("Purchased business/plot mismatch for: " + property_id)
		return
	if map_screen != null:
		map_screen.refresh_from_managers()
	main_hud.refresh_from_managers()
	business_modal.open_for_business(business_instance_id)
	_set_map_modal_input_blocked(true)


func _close_shared_modals() -> void:
	if business_modal.visible:
		business_modal.close_modal()
	if buy_building_modal.visible:
		buy_building_modal.close_modal()
	if house_modal.visible:
		house_modal.close_modal()
	if buy_house_modal.visible:
		buy_house_modal.close_modal()
	_set_map_modal_input_blocked(false)


func _on_shared_modal_closed() -> void:
	if map_screen != null:
		map_screen.refresh_from_managers()
	if (
		not business_modal.visible
		and not buy_building_modal.visible
		and not house_modal.visible
		and not buy_house_modal.visible
	):
		_set_map_modal_input_blocked(false)


func _set_map_modal_input_blocked(blocked: bool) -> void:
	if map_screen == null:
		return
	var should_process_map_input := not blocked and map_screen.visible
	map_screen.map_camera.set_process_unhandled_input(should_process_map_input)
