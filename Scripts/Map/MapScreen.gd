extends Control
class_name MapScreen

signal property_selected(property_id: String)

const WORLD_BOUNDS := Rect2(0.0, 0.0, 6200.0, 4200.0)

@onready var map_camera: MapCamera = $MapWorld/Camera2D
@onready var backdrop_layer: CanvasLayer = $BackdropLayer
@onready var map_world: Node2D = $MapWorld

var _properties_by_id: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_authored_properties()
	_connect_business_manager_signals()
	_connect_house_manager_signals()


func set_screen_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	backdrop_layer.visible = active
	map_world.visible = active
	map_camera.set_screen_active(active)


func refresh_from_managers() -> void:
	for property_value in _properties_by_id.values():
		var map_property := property_value as MapProperty
		if map_property != null:
			map_property.refresh_from_business_manager()


func get_property_data(property_id: String) -> Dictionary:
	var map_property := _properties_by_id.get(property_id) as MapProperty
	if map_property == null:
		return {}
	return map_property.get_property_data()


func get_map_properties() -> Array[MapProperty]:
	var properties: Array[MapProperty] = []
	for property_value in _properties_by_id.values():
		var map_property := property_value as MapProperty
		if map_property != null:
			properties.append(map_property)
	return properties


func get_world_bounds() -> Rect2:
	return WORLD_BOUNDS


func _register_authored_properties() -> void:
	_properties_by_id.clear()
	var interactive := map_world.get_node_or_null("Buildings/Interactive")
	if interactive == null:
		return
	for child in interactive.get_children():
		if not child is MapProperty:
			continue
		var map_property := child as MapProperty
		var id := map_property.get_property_id()
		if id.is_empty():
			push_warning("MapProperty has no stable property_id: " + str(map_property.get_path()))
			continue
		if _properties_by_id.has(id):
			push_error("Duplicate Map property_id: " + id)
			continue
		_properties_by_id[id] = map_property
		if not map_property.selected.is_connected(_on_property_selected):
			map_property.selected.connect(_on_property_selected)


func _connect_business_manager_signals() -> void:
	if not BusinessManager.family_business_slot_changed.is_connected(
		_on_family_business_slot_changed
	):
		BusinessManager.family_business_slot_changed.connect(
			_on_family_business_slot_changed
		)
	if not BusinessManager.family_business_npc_slot_changed.is_connected(
		_on_family_business_npc_slot_changed
	):
		BusinessManager.family_business_npc_slot_changed.connect(
			_on_family_business_npc_slot_changed
		)
	if not BusinessManager.family_business_created.is_connected(
		_on_family_business_created
	):
		BusinessManager.family_business_created.connect(
			_on_family_business_created
		)
	if not BusinessManager.family_business_upgraded.is_connected(
		_on_family_business_upgraded
	):
		BusinessManager.family_business_upgraded.connect(
			_on_family_business_upgraded
		)


func _connect_house_manager_signals() -> void:
	if not HouseManager.house_created.is_connected(_on_house_created):
		HouseManager.house_created.connect(_on_house_created)
	if not HouseManager.house_state_changed.is_connected(_on_house_state_changed):
		HouseManager.house_state_changed.connect(_on_house_state_changed)


func _on_family_business_slot_changed(
	business_instance_id: String,
	_slot_id: String,
	_character_id: int
) -> void:
	_refresh_business_property(business_instance_id)


func _on_family_business_npc_slot_changed(
	business_instance_id: String,
	_slot_id: String,
	_npc_id: String
) -> void:
	_refresh_business_property(business_instance_id)


func _on_family_business_created(
	_business_instance_id: String,
	_business_type_id: String,
	plot_id: String,
	_purchase_cost: int
) -> void:
	_refresh_property(plot_id)


func _on_family_business_upgraded(
	business_instance_id: String,
	_new_level: int,
	_upgrade_cost: int
) -> void:
	_refresh_business_property(business_instance_id)


func _on_house_created(
	_house_instance_id: String,
	property_id: String,
	_purchase_cost: int
) -> void:
	_refresh_property(property_id)


func _on_house_state_changed(house_instance_id: String, _reason: String) -> void:
	var house := HouseManager.get_house_by_instance_id(house_instance_id)
	if not house.is_empty():
		_refresh_property(str(house.get("property_id", "")))


func _refresh_business_property(business_instance_id: String) -> void:
	var business: Dictionary = BusinessManager.get_business_by_instance_id(
		business_instance_id
	)
	if business.is_empty():
		return
	_refresh_property(str(business.get("plot_id", "")))


func _refresh_property(property_id: String) -> void:
	var map_property := _properties_by_id.get(property_id) as MapProperty
	if map_property != null:
		map_property.refresh_from_business_manager()


func _on_property_selected(property_id: String) -> void:
	if _properties_by_id.has(property_id):
		property_selected.emit(property_id)
