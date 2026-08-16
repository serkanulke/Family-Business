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

@export var bounds_padding: Vector2 = Vector2(
	220.0,
	260.0
)

var active_touches: Dictionary = {}
var last_pinch_distance: float = 0.0
var mouse_dragging: bool = false

var content_bounds: Rect2 = Rect2()
var has_content_bounds: bool = false


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

	_clamp_position_to_content()


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

	_clamp_position_to_content()


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

	_clamp_position_to_content()


func set_content_bounds(
	bounds: Rect2
) -> void:
	if (
		bounds.size.x <= 0.0
		or bounds.size.y <= 0.0
	):
		clear_content_bounds()
		return

	content_bounds = bounds.grow_individual(
		bounds_padding.x,
		bounds_padding.y,
		bounds_padding.x,
		bounds_padding.y
	)

	has_content_bounds = true
	_clamp_position_to_content()


func clear_content_bounds() -> void:
	content_bounds = Rect2()
	has_content_bounds = false


func _clamp_position_to_content() -> void:
	if not has_content_bounds:
		return

	var viewport_size: Vector2 = get_viewport_rect().size

	if (
		viewport_size.x <= 0.0
		or viewport_size.y <= 0.0
	):
		return

	var current_zoom: float = maxf(
		get_zoom_level(),
		0.001
	)

	var half_visible_world_size: Vector2 = (
		viewport_size
		/ current_zoom
		* 0.5
	)

	var bounds_left: float = content_bounds.position.x
	var bounds_right: float = content_bounds.end.x
	var bounds_top: float = content_bounds.position.y
	var bounds_bottom: float = content_bounds.end.y

	var minimum_x: float = (
		bounds_left
		+ half_visible_world_size.x
	)

	var maximum_x: float = (
		bounds_right
		- half_visible_world_size.x
	)

	var minimum_y: float = (
		bounds_top
		+ half_visible_world_size.y
	)

	var maximum_y: float = (
		bounds_bottom
		- half_visible_world_size.y
	)

	var clamped_x: float
	var clamped_y: float

	if minimum_x > maximum_x:
		clamped_x = (
			bounds_left
			+ bounds_right
		) * 0.5
	else:
		clamped_x = clampf(
			position.x,
			minimum_x,
			maximum_x
		)

	if minimum_y > maximum_y:
		clamped_y = (
			bounds_top
			+ bounds_bottom
		) * 0.5
	else:
		clamped_y = clampf(
			position.y,
			minimum_y,
			maximum_y
		)

	position = Vector2(
		clamped_x,
		clamped_y
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
