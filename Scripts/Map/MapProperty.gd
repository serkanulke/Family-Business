extends Node2D
class_name MapProperty

signal selected(property_id: String)

const PROPERTY_TAG_SCENE := preload("res://UI/Map/MapPropertyTag.tscn")
const TAP_DRAG_THRESHOLD := 14.0

enum VisualMode {
	RUNTIME_GENERATED,
	AUTHORED_EXISTING,
}

@export var property_id: String = ""
@export_enum("family_business", "house", "land", "city_decor") var category := "family_business"
@export var business_type_id: String = ""
@export var footprint := Vector2i.ONE
@export var purchasable := true
@export var display_name: String = ""
@export var visual_mode := VisualMode.RUNTIME_GENERATED
@export_node_path("Sprite2D") var authored_visual_path := NodePath("Sprite2D")

var property_data: Dictionary = {}
var visual: Sprite2D
var interaction_area: Area2D
var property_tag: MapPropertyTag
var _mouse_pressed := false
var _mouse_press_position := Vector2.ZERO
var _mouse_dragged := false
var _touch_states: Dictionary = {}


func _ready() -> void:
	if property_data.is_empty() and not property_id.is_empty():
		configure({
			"property_id": property_id,
			"category": category,
			"business_type_id": business_type_id,
			"footprint": [footprint.x, footprint.y],
			"purchasable": purchasable,
			"display_name": display_name,
			"visual_mode": visual_mode,
			"authored_visual_path": authored_visual_path,
		})


func configure(data: Dictionary) -> void:
	property_data = data.duplicate(true)
	if not property_data.has("property_id"):
		property_data["property_id"] = str(property_data.get("id", ""))
	if int(property_data.get("visual_mode", VisualMode.RUNTIME_GENERATED)) == VisualMode.RUNTIME_GENERATED:
		var runtime_name := get_property_id()
		if not runtime_name.is_empty():
			name = runtime_name
	_build_visual()
	_build_interaction()
	_build_tag()


func get_property_id() -> String:
	return str(property_data.get("property_id", property_data.get("id", property_id)))


func get_property_data() -> Dictionary:
	return property_data.duplicate(true)


func refresh_from_business_manager() -> void:
	if property_tag == null:
		return
	var category := str(property_data.get("category", ""))
	var resolved_display_name := _resolve_display_name()
	var purchasable := bool(property_data.get("purchasable", false))
	var show_tag := bool(property_data.get("tag_visibility", purchasable))
	if category == "city_decor" or not show_tag:
		property_tag.configure(resolved_display_name, "", false, false)
		return
	if category == "house":
		var house := HouseManager.get_house_on_property(get_property_id())
		if house.is_empty():
			property_tag.configure(resolved_display_name, "For Sale", purchasable, false)
		else:
			var house_instance_id := str(house.get("house_instance_id", ""))
			property_tag.configure(
				resolved_display_name,
				"%d / %d household" % [
					HouseManager.get_house_occupancy(house_instance_id),
					HouseManager.get_house_capacity(house_instance_id)
				],
				true,
				false
			)
		return
	if category != "family_business":
		property_tag.configure(resolved_display_name, "For Sale", purchasable, false)
		return
	var business: Dictionary = BusinessManager.get_business_on_plot(get_property_id())
	if business.is_empty():
		property_tag.configure(resolved_display_name, "For Sale", purchasable, false)
		return
	var slots_value = business.get("slots", [])
	var slots: Array = slots_value if slots_value is Array else []
	var occupied := 0
	for slot_value in slots:
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		if slot.get("assigned_character_id", null) != null:
			occupied += 1
		else:
			var npc_id_value = slot.get("assigned_npc_id", null)
			if npc_id_value != null and not str(npc_id_value).is_empty():
				occupied += 1
	property_tag.configure(
		resolved_display_name,
		"%d / %d staff" % [occupied, slots.size()],
		true,
		occupied < slots.size()
	)


func _build_visual() -> void:
	if int(property_data.get("visual_mode", VisualMode.RUNTIME_GENERATED)) == VisualMode.AUTHORED_EXISTING:
		var authored_path: NodePath = property_data.get("authored_visual_path", authored_visual_path)
		var authored_node := get_node_or_null(authored_path)
		if authored_node is Sprite2D:
			visual = authored_node as Sprite2D
		else:
			push_warning("Authored MapProperty visual is unavailable: " + str(authored_path))
		return

	var visual_path := _resolve_visual_path()
	if visual_path.is_empty() or not ResourceLoader.exists(visual_path):
		push_warning("Map property visual is unavailable: " + visual_path)
		return
	var texture := load(visual_path) as Texture2D
	if texture == null:
		return
	visual = Sprite2D.new()
	visual.name = "BuildingVisual"
	visual.texture = texture
	visual.centered = true
	var offset_value = property_data.get("sprite_offset", [0, 0])
	var sprite_offset := _array_to_vector2(offset_value)
	visual.position = Vector2(sprite_offset.x, -texture.get_height() * 0.5 + sprite_offset.y)
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(visual)


func _resolve_visual_path() -> String:
	if str(property_data.get("category", "")) != "family_business":
		return str(property_data.get("visual_path", ""))

	var business_type_id := str(property_data.get("business_type_id", ""))
	if business_type_id.is_empty():
		var business: Dictionary = BusinessManager.get_business_on_plot(get_property_id())
		business_type_id = str(business.get("business_type_id", ""))

	if business_type_id.is_empty():
		return str(property_data.get("visual_path", ""))

	return BusinessManager.get_business_map_visual_path(business_type_id)


func _build_interaction() -> void:
	interaction_area = Area2D.new()
	interaction_area.name = "PropertyInteraction"
	# Property selection is owned by the floating Property Tag. The authored
	# footprint remains for geometry/debugging, but never opens a modal.
	interaction_area.input_pickable = false
	interaction_area.monitoring = false
	interaction_area.monitorable = false
	interaction_area.position = _get_visual_south_anchor()
	add_child(interaction_area)
	var collision := CollisionPolygon2D.new()
	collision.name = "FootprintCollision"
	var footprint := _array_to_vector2i(property_data.get("footprint", [1, 1]))
	collision.polygon = MapCoordinateHelper.get_footprint_polygon(footprint)
	interaction_area.add_child(collision)
	interaction_area.input_event.connect(_on_input_event)


func _build_tag() -> void:
	property_tag = PROPERTY_TAG_SCENE.instantiate() as MapPropertyTag
	property_tag.name = "PropertyTag"
	property_tag.z_index = 20
	var tag_size := property_tag.custom_minimum_size
	var tag_position := _get_visual_top_anchor() + Vector2(-tag_size.x * 0.5, -tag_size.y + 20.0)
	if property_data.has("tag_offset"):
		tag_position = (
			_get_visual_south_anchor()
			+ _array_to_vector2(property_data["tag_offset"])
			+ Vector2(-tag_size.x * 0.5, 0.0)
		)
	property_tag.position = tag_position
	property_tag.set_tag_scale(float(property_data.get("tag_scale", 1.0)))
	var category := str(property_data.get("category", ""))
	var tag_selects_property := (
		category in ["family_business", "house", "land"]
		and bool(property_data.get("purchasable", false))
	)
	property_tag.set_interaction_enabled(tag_selects_property)
	if tag_selects_property and not property_tag.tapped.is_connected(_on_tag_tapped):
		property_tag.tapped.connect(_on_tag_tapped)
	add_child(property_tag)
	refresh_from_business_manager()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if interaction_area == null or not interaction_area.input_pickable:
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_mouse_pressed = true
			_mouse_dragged = false
			_mouse_press_position = event.position
		elif _mouse_pressed:
			var is_tap: bool = (
				not _mouse_dragged
				and event.position.distance_to(_mouse_press_position) <= TAP_DRAG_THRESHOLD
			)
			_mouse_pressed = false
			if is_tap:
				selected.emit(get_property_id())
	elif event is InputEventMouseMotion and _mouse_pressed:
		_mouse_dragged = (
			_mouse_dragged
			or event.position.distance_to(_mouse_press_position) > TAP_DRAG_THRESHOLD
		)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_states[event.index] = {
				"origin": event.position,
				"dragged": false
			}
		elif _touch_states.has(event.index):
			var state: Dictionary = _touch_states[event.index]
			var origin: Vector2 = state.get("origin", event.position)
			var is_tap: bool = (
				not bool(state.get("dragged", false))
				and event.position.distance_to(origin)
				<= TAP_DRAG_THRESHOLD
			)
			_touch_states.erase(event.index)
			if is_tap:
				selected.emit(get_property_id())
	elif event is InputEventScreenDrag and _touch_states.has(event.index):
		var state: Dictionary = _touch_states[event.index]
		var origin: Vector2 = state.get("origin", event.position)
		if event.position.distance_to(origin) > TAP_DRAG_THRESHOLD:
			state["dragged"] = true
			_touch_states[event.index] = state


func _on_tag_tapped() -> void:
	if bool(property_data.get("purchasable", false)):
		selected.emit(get_property_id())


func _array_to_vector2(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _array_to_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ONE


func _get_visual_south_anchor() -> Vector2:
	if visual == null or visual.texture == null:
		return Vector2.ZERO
	var rect := visual.get_rect()
	var local_south := Vector2(rect.get_center().x, rect.end.y)
	return to_local(visual.to_global(local_south))


func _get_visual_top_anchor() -> Vector2:
	if visual == null or visual.texture == null:
		return Vector2(0.0, -120.0)
	var rect := visual.get_rect()
	var local_top := Vector2(rect.get_center().x, rect.position.y)
	return to_local(visual.to_global(local_top))


func _resolve_display_name() -> String:
	var configured_name := str(property_data.get("display_name", ""))
	if not configured_name.is_empty():
		return configured_name
	if str(property_data.get("category", "")) == "family_business":
		var type_id := str(property_data.get("business_type_id", ""))
		var business_type: Dictionary = BusinessManager.get_business_type_by_id(type_id)
		var type_name := str(business_type.get("display_name", ""))
		if not type_name.is_empty():
			return type_name
	return str(property_data.get("category", "Property")).capitalize()
