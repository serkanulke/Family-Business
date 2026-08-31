extends PanelContainer
class_name MapPropertyTag

signal tapped

const TAP_DRAG_THRESHOLD := 14.0
const NORMAL_TITLE_COLOR := Color("1e1e1e")
const NORMAL_STATE_COLOR := Color("6d4534")
const WARNING_TITLE_COLOR := Color("7d2525")
const WARNING_STATE_COLOR := Color("b3261e")

@export var normal_style: StyleBox
@export var warning_style: StyleBox

@onready var title_label: Label = $Margin/Rows/Title
@onready var state_label: Label = $Margin/Rows/State

var is_warning_state := false
var _mouse_pressed := false
var _mouse_origin := Vector2.ZERO
var _mouse_dragged := false
var _touch_states: Dictionary = {}


func configure(
	title: String,
	state_text: String,
	should_show: bool = true,
	show_warning: bool = false
) -> void:
	title_label.text = title
	state_label.text = state_text
	_set_warning_state(show_warning)
	visible = should_show


func set_tag_scale(value: float) -> void:
	scale = Vector2.ONE * maxf(value, 0.1)


func set_interaction_enabled(enabled: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_mouse_pressed = false
	_touch_states.clear()


func _gui_input(event: InputEvent) -> void:
	if mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if event.pressed:
			_mouse_pressed = true
			_mouse_dragged = false
			_mouse_origin = event.position
		elif _mouse_pressed:
			var is_tap: bool = (
				not _mouse_dragged
				and event.position.distance_to(_mouse_origin) <= TAP_DRAG_THRESHOLD
			)
			_mouse_pressed = false
			if is_tap:
				tapped.emit()
	elif event is InputEventMouseMotion and _mouse_pressed:
		accept_event()
		_mouse_dragged = (
			_mouse_dragged
			or event.position.distance_to(_mouse_origin) > TAP_DRAG_THRESHOLD
		)
	elif event is InputEventScreenTouch:
		accept_event()
		if event.pressed:
			_touch_states[event.index] = {
				"origin": event.position,
				"dragged": false,
			}
		elif _touch_states.has(event.index):
			var state: Dictionary = _touch_states[event.index]
			var origin: Vector2 = state.get("origin", event.position)
			var is_tap: bool = (
				not bool(state.get("dragged", false))
				and event.position.distance_to(origin) <= TAP_DRAG_THRESHOLD
			)
			_touch_states.erase(event.index)
			if is_tap:
				tapped.emit()
	elif event is InputEventScreenDrag and _touch_states.has(event.index):
		accept_event()
		var state: Dictionary = _touch_states[event.index]
		var origin: Vector2 = state.get("origin", event.position)
		if event.position.distance_to(origin) > TAP_DRAG_THRESHOLD:
			state["dragged"] = true
			_touch_states[event.index] = state


func _set_warning_state(show_warning: bool) -> void:
	is_warning_state = show_warning
	var panel_style := warning_style if show_warning else normal_style
	if panel_style != null:
		add_theme_stylebox_override("panel", panel_style)
	title_label.add_theme_color_override(
		"font_color",
		WARNING_TITLE_COLOR if show_warning else NORMAL_TITLE_COLOR
	)
	state_label.add_theme_color_override(
		"font_color",
		WARNING_STATE_COLOR if show_warning else NORMAL_STATE_COLOR
	)
