extends PanelContainer
class_name ItemFilterBar


signal filter_changed(filter_key: String)


const COLOR_BAR := Color("#FFF9F4")
const COLOR_SELECTED := Color("#E7CFB6")
const COLOR_TEXT := Color("#6D4534")
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"

var selected_filter := "all"
var filters: Array[Dictionary] = [
	{"key": "all", "label": "All"},
	{"key": "ring", "label": "Ring"},
	{"key": "glasses", "label": "Glasses"},
	{"key": "watch", "label": "Watch"},
	{"key": "necklace", "label": "Necklace"},
]
var buttons: Dictionary = {}
var row: HBoxContainer


func _ready() -> void:
	_build_interface()


func set_filters(new_filters: Array[Dictionary]) -> void:
	filters = new_filters.duplicate(true)
	if is_node_ready():
		_build_buttons()


func set_selected_filter(filter_key: String, emit_change: bool = false) -> void:
	var normalized := filter_key.strip_edges().to_lower()
	if not buttons.has(normalized):
		normalized = "all"
	selected_filter = normalized
	_refresh_button_styles()
	if emit_change:
		filter_changed.emit(selected_filter)


func get_display_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"selected_filter": selected_filter,
		"filter_count": filters.size(),
	}


func _build_interface() -> void:
	add_theme_stylebox_override("panel", _make_style(COLOR_BAR, 18))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)
	_build_buttons()


func _build_buttons() -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()
	buttons.clear()
	for definition in filters:
		var key := str(definition.get("key", "")).to_lower()
		var button := Button.new()
		button.name = "%sFilter" % key.capitalize()
		button.text = str(definition.get("label", key.capitalize()))
		button.custom_minimum_size = Vector2(0.0, 60.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", load(FONT_BOLD) as Font)
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_color_override("font_color", COLOR_TEXT)
		button.add_theme_color_override("font_hover_color", COLOR_TEXT)
		button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
		button.pressed.connect(set_selected_filter.bind(key, true))
		row.add_child(button)
		buttons[key] = button
	_refresh_button_styles()


func _refresh_button_styles() -> void:
	for key in buttons:
		var button := buttons[key] as Button
		var color := COLOR_SELECTED if key == selected_filter else Color.TRANSPARENT
		var style := _make_style(color, 14)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("focus", style)


func _make_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

