extends Camera2D
class_name MapCamera

@export var min_zoom := 0.48
@export var max_zoom := 1.35
@export var zoom_step := 0.10
@export var bounds_padding := Vector2(300.0, 300.0)

var content_bounds := Rect2(-540.0, -960.0, 1080.0, 1920.0)
var _touches: Dictionary = {}
var _previous_pinch_distance := 0.0
var _mouse_dragging := false


func _ready() -> void:
	position_smoothing_enabled = false
	zoom = Vector2.ONE * 0.72
	limit_enabled = false


func set_content_bounds(new_bounds: Rect2) -> void:
	if new_bounds.size.x <= 0.0 or new_bounds.size.y <= 0.0:
		return
	content_bounds = new_bounds.grow_individual(
		bounds_padding.x,
		bounds_padding.y,
		bounds_padding.x,
		bounds_padding.y
	)
	_clamp_position()


func focus_content() -> void:
	position = content_bounds.get_center()
	_clamp_position()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _mouse_dragging:
		position -= event.relative / zoom.x
		_clamp_position()


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
	else:
		_touches.erase(event.index)
	_previous_pinch_distance = _get_pinch_distance()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() == 1:
		position -= event.relative / zoom.x
		_clamp_position()
		return

	if _touches.size() < 2:
		return
	var distance := _get_pinch_distance()
	if _previous_pinch_distance > 0.0 and distance > 0.0:
		var ratio := distance / _previous_pinch_distance
		_set_zoom_value(zoom.x * ratio)
	_previous_pinch_distance = distance


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
		_mouse_dragging = event.pressed
		return
	if not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_zoom_value(zoom.x + zoom_step)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_zoom_value(zoom.x - zoom_step)


func _set_zoom_value(value: float) -> void:
	var clamped := clampf(value, min_zoom, max_zoom)
	zoom = Vector2.ONE * clamped
	_clamp_position()


func _get_pinch_distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var positions: Array = _touches.values()
	return (positions[0] as Vector2).distance_to(positions[1] as Vector2)


func _clamp_position() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var half_view := viewport_size * 0.5 / zoom.x
	var min_position := content_bounds.position + half_view
	var max_position := content_bounds.end - half_view
	if min_position.x > max_position.x:
		position.x = content_bounds.get_center().x
	else:
		position.x = clampf(position.x, min_position.x, max_position.x)
	if min_position.y > max_position.y:
		position.y = content_bounds.get_center().y
	else:
		position.y = clampf(position.y, min_position.y, max_position.y)
