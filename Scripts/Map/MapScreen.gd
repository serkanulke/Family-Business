extends Control
class_name MapScreen

signal family_tree_requested
signal property_purchase_requested(
	property_id: String,
	category: String,
	reference_id: String,
	purchase_cost: Variant,
	backend_available: bool
)
signal land_build_requested(property_id: String, land_plot_type: String)

const MAP_DATA_PATH := "res://Resources/Json/Map.json"
const MAP_PROPERTY_SCRIPT := preload("res://Scripts/Map/MapProperty.gd")
const BUSINESS_MODAL_SCENE := preload("res://Scenes/UI/Business/BusinessModal.tscn")

const GROUND_ASSETS := {
	"grass": "res://Resources/Map/roads/grass.svg",
	"asphalt": "res://Resources/Map/roads/asphalt.svg",
	"sea": "res://Resources/Map/roads/sea.svg"
}

@onready var main_ground: TileMapLayer = $World/MainGrid/MainGround
@onready var roads: TileMapLayer = $World/MainGrid/Roads
@onready var plot_ground: TileMapLayer = $World/MainGrid/PlotBuildingGround
@onready var coast_ground: TileMapLayer = $World/MainGrid/CoastGround
@onready var detail_ground: TileMapLayer = $World/DetailGrid/DetailGroundPaths
@onready var environment_layer: Node2D = $World/TallObjects/EnvironmentDecorations
@onready var buildings_layer: Node2D = $World/TallObjects/Buildings
@onready var map_camera: MapCamera = $World/MapCamera
@onready var hud_root: Control = $HUD/HUDRoot
@onready var modal_root: Control = $ModalLayer/ModalRoot

var map_data: Dictionary = {}
var property_nodes: Dictionary = {}
var property_data_by_id: Dictionary = {}
var business_modal: BusinessModal
var _source_caches: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_map_data()
	_configure_layers()
	_build_authored_city()
	_build_hud()
	_build_business_modal()
	_connect_business_signals()
	_refresh_property_tags()
	_update_camera_bounds()
	call_deferred("_validate_runtime_alignment")


func refresh_from_managers() -> void:
	_refresh_property_tags()
	_refresh_hud_values()


func purchase_business_property(property_id: String) -> Dictionary:
	var data: Dictionary = property_data_by_id.get(property_id, {})
	if str(data.get("category", "")) != "family_business":
		return {}
	var business_type_id := str(data.get("business_type_id", ""))
	if BusinessManager.get_business_type_by_id(business_type_id).is_empty():
		return {}
	if BusinessManager.get_level_definition(business_type_id, 1).is_empty():
		return {}
	var created: Dictionary = BusinessManager.create_business_instance(
		business_type_id,
		property_id,
		false
	)
	if not created.is_empty():
		_refresh_property_tag(property_id)
	return created


func request_land_build(property_id: String) -> void:
	var data: Dictionary = property_data_by_id.get(property_id, {})
	if str(data.get("category", "")) != "land":
		return
	land_build_requested.emit(property_id, str(data.get("land_plot_type", "")))


func get_validation_report() -> Dictionary:
	return MapDataValidator.validate(map_data)


func _load_map_data() -> void:
	if not FileAccess.file_exists(MAP_DATA_PATH):
		push_error("Production map data is missing: " + MAP_DATA_PATH)
		return
	var file := FileAccess.open(MAP_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Production map data could not be opened.")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Production map data must have a Dictionary root.")
		return
	map_data = parsed
	var report := MapDataValidator.validate(map_data)
	for error_value in report.get("errors", []):
		push_error("Map data validation: " + str(error_value))


func _configure_layers() -> void:
	_configure_tile_layer(main_ground, Vector2i(200, 100))
	_configure_tile_layer(roads, Vector2i(200, 100))
	_configure_tile_layer(plot_ground, Vector2i(200, 100))
	_configure_tile_layer(coast_ground, Vector2i(200, 100))
	_configure_tile_layer(detail_ground, Vector2i(50, 25))


func _configure_tile_layer(layer: TileMapLayer, tile_size: Vector2i) -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = tile_size
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	layer.tile_set = tile_set
	if tile_size == Vector2i(200, 100):
		# TileMapLayer stores diamond tiles by their atlas rectangle. Moving the
		# main layer by half a tile makes logical cell (0,0) share the map origin.
		layer.position = Vector2(-100.0, -50.0)
	else:
		# A 4x4 block of 50x25 diamonds has a 75 px horizontal atlas-origin
		# correction relative to a 200x100 diamond. This aligns the outer tile
		# boundaries exactly; it is derived from the subdivision, not an art offset.
		layer.position = Vector2(-25.0, -50.0)
	_source_caches[layer.get_instance_id()] = {}


func _build_authored_city() -> void:
	_paint_regions(map_data.get("ground_regions", []))
	_paint_segments(roads, map_data.get("road_segments", []))
	_paint_overrides(roads, map_data.get("road_overrides", []))
	_paint_regions(map_data.get("coast_regions", []))
	_paint_segments(detail_ground, map_data.get("detail_segments", []))
	_build_properties(map_data.get("properties", []))
	_build_decorations(map_data.get("decorations", []))


func _paint_regions(regions_value: Variant) -> void:
	if not regions_value is Array:
		return
	for region_value in regions_value:
		if not region_value is Dictionary:
			continue
		var region: Dictionary = region_value
		var layer := _get_layer_by_name(str(region.get("layer", "")))
		if layer == null:
			continue
		var from_cell := _array_to_vector2i(region.get("from", []))
		var to_cell := _array_to_vector2i(region.get("to", []))
		var asset_path := str(region.get("asset", ""))
		for x in range(from_cell.x, to_cell.x + 1):
			for y in range(from_cell.y, to_cell.y + 1):
				_set_tile(layer, Vector2i(x, y), asset_path)


func _paint_segments(layer: TileMapLayer, segments_value: Variant) -> void:
	if not segments_value is Array:
		return
	for segment_value in segments_value:
		if not segment_value is Dictionary:
			continue
		var segment: Dictionary = segment_value
		var asset_path := str(segment.get("asset", ""))
		for cell in MapDataValidator.expand_segment(segment):
			_set_tile(layer, cell, asset_path)


func _paint_overrides(layer: TileMapLayer, overrides_value: Variant) -> void:
	if not overrides_value is Array:
		return
	for override_value in overrides_value:
		if not override_value is Dictionary:
			continue
		var override: Dictionary = override_value
		_set_tile(
			layer,
			_array_to_vector2i(override.get("cell", [])),
			str(override.get("asset", ""))
		)


func _build_properties(properties_value: Variant) -> void:
	if not properties_value is Array:
		return
	for property_value in properties_value:
		if not property_value is Dictionary:
			continue
		var data: Dictionary = property_value
		var property_id := str(data.get("id", ""))
		property_data_by_id[property_id] = data
		_paint_property_ground(data)
		var property_node := MAP_PROPERTY_SCRIPT.new() as MapProperty
		var grid_position := _array_to_vector2i(data.get("grid_position", []))
		var footprint := _array_to_vector2i(data.get("footprint", [1, 1]))
		property_node.position = MapCoordinateHelper.get_south_anchor(grid_position, footprint)
		property_node.selected.connect(_on_property_selected)
		buildings_layer.add_child(property_node)
		property_node.configure(data)
		property_nodes[property_id] = property_node


func _paint_property_ground(data: Dictionary) -> void:
	var ground_type := str(data.get("ground_type", "none"))
	if ground_type in ["none", "sea"]:
		return
	var asset_path := str(GROUND_ASSETS.get(ground_type, ""))
	if asset_path.is_empty():
		return
	var position := _array_to_vector2i(data.get("grid_position", []))
	var footprint := _array_to_vector2i(data.get("footprint", [1, 1]))
	for x in range(position.x, position.x + footprint.x):
		for y in range(position.y, position.y + footprint.y):
			_set_tile(plot_ground, Vector2i(x, y), asset_path)


func _build_decorations(decorations_value: Variant) -> void:
	if not decorations_value is Array:
		return
	for decoration_value in decorations_value:
		if not decoration_value is Dictionary:
			continue
		var data: Dictionary = decoration_value
		var visual_path := str(data.get("visual_path", ""))
		if not ResourceLoader.exists(visual_path):
			continue
		var texture := load(visual_path) as Texture2D
		if texture == null:
			continue
		var root := Node2D.new()
		root.name = str(data.get("id", "Decoration"))
		root.position = MapCoordinateHelper.detail_grid_to_world(
			_array_to_vector2i(data.get("detail_grid_position", []))
		)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = Vector2(0.0, -texture.get_height() * 0.5)
		var scale_value := float(data.get("visual_scale", 2.25))
		sprite.scale = Vector2.ONE * scale_value
		root.add_child(sprite)
		environment_layer.add_child(root)


func _set_tile(layer: TileMapLayer, cell: Vector2i, asset_path: String) -> void:
	if asset_path.is_empty() or not ResourceLoader.exists(asset_path):
		push_warning("Map tile asset is unavailable: " + asset_path)
		return
	var source_id := _get_or_create_source(layer, asset_path)
	if source_id < 0:
		return
	layer.set_cell(cell, source_id, Vector2i.ZERO, 0)


func _get_or_create_source(layer: TileMapLayer, asset_path: String) -> int:
	var cache: Dictionary = _source_caches[layer.get_instance_id()]
	if cache.has(asset_path):
		return int(cache[asset_path])
	var texture := load(asset_path) as Texture2D
	if texture == null:
		return -1
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
	atlas.create_tile(Vector2i.ZERO)
	var source_id := layer.tile_set.get_next_source_id()
	layer.tile_set.add_source(atlas, source_id)
	cache[asset_path] = source_id
	return source_id


func _get_layer_by_name(layer_name: String) -> TileMapLayer:
	match layer_name:
		"MainGround": return main_ground
		"Roads": return roads
		"PlotBuildingGround": return plot_ground
		"CoastGround": return coast_ground
		"DetailGroundPaths": return detail_ground
	return null


func _build_business_modal() -> void:
	business_modal = BUSINESS_MODAL_SCENE.instantiate() as BusinessModal
	business_modal.name = "BusinessModal"
	business_modal.visible = false
	modal_root.add_child(business_modal)


func _on_property_selected(property_id: String) -> void:
	var data: Dictionary = property_data_by_id.get(property_id, {})
	if data.is_empty():
		return
	var category := str(data.get("category", ""))
	if category == "family_business":
		var business: Dictionary = BusinessManager.get_business_on_plot(property_id)
		if not business.is_empty():
			business_modal.open_for_business(str(business.get("business_instance_id", "")))
			return
		var type_id := str(data.get("business_type_id", ""))
		var backend_available := (
			not BusinessManager.get_business_type_by_id(type_id).is_empty()
			and not BusinessManager.get_level_definition(type_id, 1).is_empty()
		)
		var price: Variant = (
			BusinessManager.get_business_acquisition_cost(type_id, false)
			if backend_available
			else null
		)
		property_purchase_requested.emit(
			property_id,
			category,
			type_id,
			price,
			backend_available
		)
	elif category == "land":
		property_purchase_requested.emit(
			property_id,
			category,
			str(data.get("land_plot_type", "")),
			null,
			false
		)
	elif category == "house":
		property_purchase_requested.emit(property_id, category, "", null, false)


func _connect_business_signals() -> void:
	if not BusinessManager.family_business_created.is_connected(_on_business_created):
		BusinessManager.family_business_created.connect(_on_business_created)
	if not BusinessManager.family_business_upgraded.is_connected(_on_business_changed):
		BusinessManager.family_business_upgraded.connect(_on_business_changed)
	if not BusinessManager.family_business_slot_changed.is_connected(_on_business_slot_changed):
		BusinessManager.family_business_slot_changed.connect(_on_business_slot_changed)
	if not BusinessManager.family_business_npc_slot_changed.is_connected(_on_business_npc_slot_changed):
		BusinessManager.family_business_npc_slot_changed.connect(_on_business_npc_slot_changed)


func _on_business_created(_instance_id: String, _type_id: String, plot_id: String, _cost: int) -> void:
	_refresh_property_tag(plot_id)


func _on_business_changed(business_instance_id: String, _level: int, _cost: int) -> void:
	_refresh_tag_for_business(business_instance_id)


func _on_business_slot_changed(business_instance_id: String, _slot_id: String, _character_id: int) -> void:
	_refresh_tag_for_business(business_instance_id)


func _on_business_npc_slot_changed(business_instance_id: String, _slot_id: String, _npc_id: String) -> void:
	_refresh_tag_for_business(business_instance_id)


func _refresh_tag_for_business(business_instance_id: String) -> void:
	var business: Dictionary = BusinessManager.get_business_by_instance_id(business_instance_id)
	if not business.is_empty():
		_refresh_property_tag(str(business.get("plot_id", "")))


func _refresh_property_tags() -> void:
	for property_id in property_nodes:
		_refresh_property_tag(str(property_id))


func _refresh_property_tag(property_id: String) -> void:
	var property_node: MapProperty = property_nodes.get(property_id)
	if property_node != null:
		property_node.refresh_from_business_manager()


func _update_camera_bounds() -> void:
	var min_cell := Vector2i.ZERO
	var max_cell := Vector2i.ZERO
	var initialized := false
	for region_value in map_data.get("ground_regions", []):
		if not region_value is Dictionary:
			continue
		var region: Dictionary = region_value
		var from_cell := _array_to_vector2i(region.get("from", []))
		var to_cell := _array_to_vector2i(region.get("to", []))
		if not initialized:
			min_cell = from_cell
			max_cell = to_cell
			initialized = true
		else:
			min_cell = Vector2i(mini(min_cell.x, from_cell.x), mini(min_cell.y, from_cell.y))
			max_cell = Vector2i(maxi(max_cell.x, to_cell.x), maxi(max_cell.y, to_cell.y))
	var corners := [
		MapCoordinateHelper.main_grid_to_world(min_cell),
		MapCoordinateHelper.main_grid_to_world(Vector2i(max_cell.x + 1, min_cell.y)),
		MapCoordinateHelper.main_grid_to_world(Vector2i(min_cell.x, max_cell.y + 1)),
		MapCoordinateHelper.main_grid_to_world(max_cell + Vector2i.ONE)
	]
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	for property_id in property_nodes:
		var property_node: MapProperty = property_nodes[property_id]
		if property_node.visual == null:
			continue
		var texture_size := property_node.visual.texture.get_size()
		var visual_rect := Rect2(
			property_node.position + property_node.visual.position - texture_size * 0.5,
			texture_size
		)
		bounds = bounds.merge(visual_rect)
	map_camera.set_content_bounds(bounds)
	map_camera.focus_content()


func _validate_runtime_alignment() -> void:
	var samples := [Vector2i.ZERO, Vector2i(1, 1), Vector2i(7, 13), Vector2i(48, 48)]
	for sample in samples:
		var main_center := main_ground.position + main_ground.map_to_local(sample)
		var main_corners := PackedVector2Array([
			main_center + Vector2(0.0, -50.0),
			main_center + Vector2(100.0, 0.0),
			main_center + Vector2(0.0, 50.0),
			main_center + Vector2(-100.0, 0.0)
		])
		var detail_base: Vector2i = MapCoordinateHelper.main_to_detail(sample)
		var detail_corners := PackedVector2Array([
			detail_ground.position + detail_ground.map_to_local(detail_base) + Vector2(0.0, -12.5),
			detail_ground.position + detail_ground.map_to_local(detail_base + Vector2i(3, 0)) + Vector2(25.0, 0.0),
			detail_ground.position + detail_ground.map_to_local(detail_base + Vector2i(3, 3)) + Vector2(0.0, 12.5),
			detail_ground.position + detail_ground.map_to_local(detail_base + Vector2i(0, 3)) + Vector2(-25.0, 0.0)
		])
		if main_corners != detail_corners:
			push_error("Runtime main/detail TileMapLayer alignment failed at " + str(sample))


func _build_hud() -> void:
	var top_panel := PanelContainer.new()
	top_panel.name = "TopBar"
	top_panel.position = Vector2(28.0, 34.0)
	top_panel.size = Vector2(1024.0, 108.0)
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.94, 0.97, 0.94, 0.94), 44))
	hud_root.add_child(top_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 38)
	top_panel.add_child(row)
	row.add_child(_create_hud_value("DateValue", "res://Resources/Icons/main-ui/calendar.svg"))
	row.add_child(_create_hud_value("MoneyValue", "res://Resources/Icons/main-ui/coin.png"))
	row.add_child(_create_hud_value("DiamondValue", "res://Resources/Icons/main-ui/diamond.png"))

	var nav_panel := PanelContainer.new()
	nav_panel.name = "BottomNavigation"
	nav_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	nav_panel.position = Vector2(-400.0, -188.0)
	nav_panel.size = Vector2(800.0, 144.0)
	nav_panel.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0.86), 70))
	hud_root.add_child(nav_panel)
	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 24)
	nav_panel.add_child(nav_row)
	var family_button := _create_nav_button(
		"FAMILY TREE",
		"res://Resources/Icons/nav/fam-tree-btn-deact.webp"
	)
	family_button.pressed.connect(func() -> void: family_tree_requested.emit())
	nav_row.add_child(family_button)
	var map_button := _create_nav_button("MAP", "res://Resources/Icons/nav/map-btn.webp")
	map_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav_row.add_child(map_button)
	_refresh_hud_values()
	if not TimeManager.date_changed.is_connected(_on_date_changed):
		TimeManager.date_changed.connect(_on_date_changed)
	if not GameManager.family_money_changed.is_connected(_on_family_money_changed):
		GameManager.family_money_changed.connect(_on_family_money_changed)
	if not GameManager.diamonds_changed.is_connected(_on_diamonds_changed):
		GameManager.diamonds_changed.connect(_on_diamonds_changed)


func _create_hud_value(node_name: String, icon_path: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = node_name + "Row"
	row.custom_minimum_size = Vector2(270.0, 80.0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44.0, 44.0)
	icon.texture = load(icon_path) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("#063166"))
	row.add_child(label)
	return row


func _create_nav_button(label_text: String, icon_path: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(330.0, 118.0)
	button.text = label_text
	button.icon = load(icon_path) as Texture2D
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 82)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("#063166"))
	var transparent := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", transparent)
	button.add_theme_stylebox_override("hover", transparent)
	button.add_theme_stylebox_override("pressed", transparent)
	button.add_theme_stylebox_override("disabled", transparent)
	return button


func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0, 0, 0, 0.16)
	style.shadow_size = 10
	return style


func _refresh_hud_values() -> void:
	var date_label := hud_root.find_child("DateValue", true, false) as Label
	var money_label := hud_root.find_child("MoneyValue", true, false) as Label
	var diamond_label := hud_root.find_child("DiamondValue", true, false) as Label
	if date_label != null:
		date_label.text = TimeManager.get_date_string()
	if money_label != null:
		money_label.text = _format_number(GameManager.family_money)
	if diamond_label != null:
		diamond_label.text = _format_number(GameManager.diamonds)


func _on_date_changed(_date_text: String) -> void:
	_refresh_hud_values()


func _on_family_money_changed(_amount: int) -> void:
	_refresh_hud_values()


func _on_diamonds_changed(_amount: int) -> void:
	_refresh_hud_values()


func _format_number(value: int) -> String:
	var raw := str(abs(value))
	var result := ""
	while raw.length() > 3:
		result = "," + raw.right(3) + result
		raw = raw.left(raw.length() - 3)
	return ("-" if value < 0 else "") + raw + result


func _array_to_vector2i(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
