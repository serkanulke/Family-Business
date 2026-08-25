extends Node2D
class_name MapProperty

signal selected(property_id: String)

const PROPERTY_TAG_SCENE := preload("res://UI/Map/MapPropertyTag.tscn")
const TAP_DRAG_THRESHOLD := 14.0

var property_data: Dictionary = {}
var visual: Sprite2D
var interaction_area: Area2D
var property_tag: MapPropertyTag
var _mouse_pressed := false
var _mouse_press_position := Vector2.ZERO
var _mouse_dragged := false
var _touch_states: Dictionary = {}


func configure(data: Dictionary) -> void:
	property_data = data.duplicate(true)
	name = str(property_data.get("id", "MapProperty"))
	_build_visual()
	_build_interaction()
	_build_tag()


func refresh_from_business_manager() -> void:
	if property_tag == null:
		return
	var category := str(property_data.get("category", ""))
	var display_name := str(property_data.get("display_name", "Property"))
	var purchasable := bool(property_data.get("purchasable", false))
	var show_tag := bool(property_data.get("tag_visibility", purchasable))
	if category == "city_decor" or not show_tag:
		property_tag.configure(display_name, "", false)
		return
	if category != "family_business":
		property_tag.configure(display_name, "For Sale", purchasable)
		return
	var property_id := str(property_data.get("id", ""))
	var business: Dictionary = BusinessManager.get_business_on_plot(property_id)
	if business.is_empty():
		property_tag.configure(display_name, "For Sale", purchasable)
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
	property_tag.configure(display_name, "%d / %d staff" % [occupied, slots.size()], true)


func _build_visual() -> void:
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
		var property_id := str(property_data.get("id", ""))
		var business: Dictionary = BusinessManager.get_business_on_plot(property_id)
		business_type_id = str(business.get("business_type_id", ""))

	if business_type_id.is_empty():
		return str(property_data.get("visual_path", ""))

	return BusinessManager.get_business_map_visual_path(business_type_id)


func _build_interaction() -> void:
	interaction_area = Area2D.new()
	interaction_area.name = "PropertyInteraction"
	interaction_area.input_pickable = bool(property_data.get("purchasable", false))
	interaction_area.monitoring = false
	interaction_area.monitorable = false
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
	var offset := _array_to_vector2(property_data.get("tag_offset", [0, -120]))
	if visual != null and not property_data.has("tag_offset"):
		offset = Vector2(0.0, -visual.texture.get_height() - 48.0)
	property_tag.position = offset + Vector2(-90.0, 0.0)
	property_tag.set_tag_scale(float(property_data.get("tag_scale", 1.0)))
	add_child(property_tag)
	refresh_from_business_manager()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
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
				selected.emit(str(property_data.get("id", "")))
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
				selected.emit(str(property_data.get("id", "")))
	elif event is InputEventScreenDrag and _touch_states.has(event.index):
		var state: Dictionary = _touch_states[event.index]
		var origin: Vector2 = state.get("origin", event.position)
		if event.position.distance_to(origin) > TAP_DRAG_THRESHOLD:
			state["dragged"] = true
			_touch_states[event.index] = state


func _array_to_vector2(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _array_to_vector2i(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ONE
