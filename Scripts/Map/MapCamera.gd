extends Camera2D
class_name MapCamera

const WORLD_BOUNDS := Rect2(0.0, 0.0, 6200.0, 4200.0)

@export_range(0.1, 5.0, 0.1) var drag_sensitivity := 2.0
@export_range(0.1, 4.0, 0.05) var fixed_zoom := 1.0

var _mouse_dragging := false
var _active_touch_index := -1


func _ready() -> void:
	enabled = true
	position_smoothing_enabled = false
	limit_smoothed = false
	limit_enabled = true
	limit_left = int(WORLD_BOUNDS.position.x)
	limit_top = int(WORLD_BOUNDS.position.y)
	limit_right = int(WORLD_BOUNDS.end.x)
	limit_bottom = int(WORLD_BOUNDS.end.y)
	zoom = Vector2.ONE * fixed_zoom
	call_deferred("_initialize_position")


func set_screen_active(active: bool) -> void:
	enabled = active
	set_process_unhandled_input(active)
	if active:
		make_current()
		_clamp_position_to_world()
	else:
		_mouse_dragging = false
		_active_touch_index = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_inside_tree():
		_clamp_position_to_world()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_dragging = event.pressed
		# Wheel input is intentionally ignored: Map zoom is fixed.
		return
	if event is InputEventMouseMotion and _mouse_dragging:
		pan_by_screen_delta(event.relative)
		return
	if event is InputEventScreenTouch:
		if event.pressed and _active_touch_index == -1:
			_active_touch_index = event.index
		elif not event.pressed and event.index == _active_touch_index:
			_active_touch_index = -1
		return
	if event is InputEventScreenDrag and event.index == _active_touch_index:
		pan_by_screen_delta(event.relative)


func pan_by_screen_delta(screen_delta: Vector2) -> void:
	position -= screen_delta * drag_sensitivity / fixed_zoom
	_clamp_position_to_world()


func _initialize_position() -> void:
	var half_view := _get_half_view_size()
	position = WORLD_BOUNDS.position + half_view
	_clamp_position_to_world()


func _clamp_position_to_world() -> void:
	# Restore the fixed zoom even if another input path or editor value changed it.
	zoom = Vector2.ONE * fixed_zoom
	var half_view := _get_half_view_size()
	var minimum := WORLD_BOUNDS.position + half_view
	var maximum := WORLD_BOUNDS.end - half_view
	position.x = WORLD_BOUNDS.get_center().x if minimum.x > maximum.x else clampf(position.x, minimum.x, maximum.x)
	position.y = WORLD_BOUNDS.get_center().y if minimum.y > maximum.y else clampf(position.y, minimum.y, maximum.y)


func _get_half_view_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	return viewport_size * 0.5 / fixed_zoom
