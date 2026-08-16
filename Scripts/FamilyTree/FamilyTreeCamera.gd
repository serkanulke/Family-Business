class_name FamilyTreeCamera
extends Camera2D


@export_range(0.1, 3.0, 0.01) var min_zoom: float = 0.9
@export_range(0.1, 3.0, 0.01) var max_zoom: float = 1.2
@export_range(0.1, 3.0, 0.01) var default_zoom: float = 1.0

@export_range(0.01, 0.5, 0.01) var mouse_zoom_step: float = 0.05

@export var default_position: Vector2 = Vector2(
	540.0,
	960.0
)

var active_touches: Dictionary = {}
var last_pinch_distance: float = 0.0
var mouse_dragging: bool = false


func _ready() -> void:
	_validate_zoom_limits()
	reset_view()


func _unhandled_input(
	event: InputEvent
) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(
			event
		)
		return

	if event is InputEventScreenDrag:
		_handle_screen_drag(
			event
		)
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(
			event
		)
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(
			event
		)


func _handle_screen_touch(
	event: InputEventScreenTouch
) -> void:
	if event.pressed:
		active_touches[
			event.index
		] = event.position
	else:
		active_touches.erase(
			event.index
		)

	if active_touches.size() == 2:
		last_pinch_distance = (
			_get_current_pinch_distance()
		)
	else:
		last_pinch_distance = 0.0


func _handle_screen_drag(
	event: InputEventScreenDrag
) -> void:
	active_touches[
		event.index
	] = event.position

	if active_touches.size() == 1:
		_pan_by_screen_delta(
			event.relative
		)
		return

	if active_touches.size() != 2:
		return

	var current_distance: float = (
		_get_current_pinch_distance()
	)

	if (
		last_pinch_distance <= 0.0
		or current_distance <= 0.0
	):
		last_pinch_distance = current_distance
		return

	var pinch_factor: float = (
		current_distance
		/ last_pinch_distance
	)

	set_zoom_level(
		get_zoom_level()
		* pinch_factor
	)

	last_pinch_distance = current_distance


func _handle_mouse_button(
	event: InputEventMouseButton
) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		mouse_dragging = event.pressed
		return

	if not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		set_zoom_level(
			get_zoom_level()
			+ mouse_zoom_step
		)
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		set_zoom_level(
			get_zoom_level()
			- mouse_zoom_step
		)


func _handle_mouse_motion(
	event: InputEventMouseMotion
) -> void:
	if not mouse_dragging:
		return

	_pan_by_screen_delta(
		event.relative
	)


func _pan_by_screen_delta(
	screen_delta: Vector2
) -> void:
	var current_zoom: float = maxf(
		get_zoom_level(),
		0.001
	)

	position -= (
		screen_delta
		/ current_zoom
	)


func _get_current_pinch_distance() -> float:
	if active_touches.size() != 2:
		return 0.0

	var touch_positions: Array = (
		active_touches.values()
	)

	var first_position: Vector2 = (
		touch_positions[0]
	)

	var second_position: Vector2 = (
		touch_positions[1]
	)

	return first_position.distance_to(
		second_position
	)


func set_zoom_level(
	value: float
) -> void:
	var clamped_zoom: float = clamp_zoom_level(
		value
	)

	zoom = Vector2(
		clamped_zoom,
		clamped_zoom
	)


func get_zoom_level() -> float:
	return zoom.x


func clamp_zoom_level(
	value: float
) -> float:
	_validate_zoom_limits()

	return clampf(
		value,
		min_zoom,
		max_zoom
	)


func reset_view() -> void:
	position = default_position
	set_zoom_level(
		default_zoom
	)


func _validate_zoom_limits() -> void:
	if min_zoom > max_zoom:
		var old_min: float = min_zoom
		min_zoom = max_zoom
		max_zoom = old_min

	default_zoom = clampf(
		default_zoom,
		min_zoom,
		max_zoom
	)
