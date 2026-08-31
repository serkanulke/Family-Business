extends Control
class_name HouseAssignmentSheet


signal assignment_applied
signal cancelled

const FONT_REGULAR := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_MEDIUM := "res://Resources/Fonts/Roboto-Medium.ttf"
const FONT_SEMIBOLD := "res://Resources/Fonts/Roboto-SemiBold.ttf"
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"
const PATH_DEFAULT_AVATAR := "res://Resources/Characters/default_avatar.png"
const PATH_TIER_DIR := "res://Resources/Icons/performance-tier/"
const STAT_ICON_DIR := "res://Resources/Icons/stats/"

const COLOR_TEXT := Color("#1E1E1E")
const COLOR_BROWN := Color("#6D4534")
const COLOR_GREEN := Color("#63A479")
const COLOR_RED := Color("#E8403E")
const COLOR_PANEL := Color("#FFF2DE")
const COLOR_CARD := Color("#FEF9F5")
const COLOR_BORDER := Color("#F3DFD3")
const COLOR_HANDLE := Color("#D3B69B")
const COLOR_REMOVE_BUTTON := Color("#FDF5EA")
const COLOR_REMOVE_BORDER := Color("#E7CEBD")

const SHEET_TOP := 502.0
const REFERENCE_HEIGHT := 1920.0
const STAT_ORDER := [
	"happiness",
	"attractiveness",
	"health",
	"confidence",
	"logic",
	"social",
	"creativity",
	"discipline"
]
const STAT_ICONS := {
	"happiness": "happiness.svg",
	"attractiveness": "attractiveness.svg",
	"health": "health.svg",
	"confidence": "confidence.svg",
	"logic": "logic.svg",
	"social": "social.svg",
	"creativity": "creativity.svg",
	"discipline": "discipline.svg"
}

var house_instance_id: String = ""
var role_id: String = ""
var assignment_type: String = "role"
var current_character_id: int = 0
var sheet_panel: PanelContainer
var drag_handle: PanelContainer
var title_label: Label
var subtitle_label: Label
var candidate_scroll: ScrollContainer
var candidate_grid: GridContainer
var empty_center: CenterContainer
var empty_label: Label
var error_label: Label


func setup_role(new_house_instance_id: String, new_role_id: String) -> void:
	house_instance_id = new_house_instance_id
	role_id = new_role_id
	assignment_type = "role"
	current_character_id = HouseManager.get_role_character_id(house_instance_id, role_id)
	if is_node_ready():
		_refresh_candidates()


func setup_resident(new_house_instance_id: String) -> void:
	house_instance_id = new_house_instance_id
	role_id = ""
	assignment_type = "resident"
	current_character_id = 0
	if is_node_ready():
		_refresh_candidates()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh_candidates()


func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.04, 0.05, 0.05, 0.78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimmer)

	var blocker := Button.new()
	blocker.name = "BackdropButton"
	blocker.flat = true
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		blocker.add_theme_stylebox_override(state, empty_style)
	blocker.pressed.connect(_cancel)
	add_child(blocker)

	sheet_panel = PanelContainer.new()
	sheet_panel.name = "Sheet"
	sheet_panel.anchor_left = 0.0
	sheet_panel.anchor_top = SHEET_TOP / REFERENCE_HEIGHT
	sheet_panel.anchor_right = 1.0
	sheet_panel.anchor_bottom = 1.0
	sheet_panel.offset_left = 40.0
	sheet_panel.offset_right = -40.0
	sheet_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sheet_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sheet_panel.add_theme_stylebox_override("panel", _sheet_style())
	add_child(sheet_panel)

	var margin := MarginContainer.new()
	margin.name = "SheetMargin"
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_bottom", 24)
	sheet_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var handle_center := CenterContainer.new()
	handle_center.name = "HandleCenter"
	handle_center.custom_minimum_size = Vector2(0, 9)
	content.add_child(handle_center)
	drag_handle = PanelContainer.new()
	drag_handle.name = "DragHandle"
	drag_handle.custom_minimum_size = Vector2(201, 9)
	drag_handle.add_theme_stylebox_override("panel", _rounded_style(COLOR_HANDLE, 8))
	handle_center.add_child(drag_handle)

	var header := VBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 149)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 0)
	content.add_child(header)
	var header_top_spacer := Control.new()
	header_top_spacer.custom_minimum_size = Vector2(0, 12)
	header.add_child(header_top_spacer)
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label(title_label, FONT_BOLD, 34, COLOR_BROWN)
	header.add_child(title_label)
	var title_subtitle_spacer := Control.new()
	title_subtitle_spacer.custom_minimum_size = Vector2(0, 14)
	header.add_child(title_subtitle_spacer)
	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label(subtitle_label, FONT_REGULAR, 22, COLOR_BROWN)
	header.add_child(subtitle_label)

	error_label = Label.new()
	error_label.name = "ErrorLabel"
	error_label.visible = false
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_label(error_label, FONT_MEDIUM, 18, COLOR_RED)
	content.add_child(error_label)

	candidate_scroll = ScrollContainer.new()
	candidate_scroll.name = "CandidateScroll"
	candidate_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	candidate_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(candidate_scroll)
	candidate_grid = GridContainer.new()
	candidate_grid.name = "CandidateGrid"
	candidate_grid.columns = 2
	candidate_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidate_grid.add_theme_constant_override("h_separation", 24)
	candidate_grid.add_theme_constant_override("v_separation", 26)
	candidate_scroll.add_child(candidate_grid)

	empty_center = CenterContainer.new()
	empty_center.name = "EmptyCenter"
	empty_center.visible = false
	empty_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(empty_center)
	var empty_lift := MarginContainer.new()
	empty_lift.add_theme_constant_override("margin_bottom", 40)
	empty_center.add_child(empty_lift)
	empty_label = Label.new()
	empty_label.name = "EmptyLabel"
	empty_label.text = "No eligible family member is available."
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label(empty_label, FONT_REGULAR, 23, COLOR_BROWN)
	empty_lift.add_child(empty_label)


func _refresh_candidates() -> void:
	if candidate_grid == null:
		return
	for child in candidate_grid.get_children():
		child.queue_free()
	error_label.visible = false
	var candidates := _get_display_candidates()
	var role_definition := HouseManager.get_role_definition(role_id) if assignment_type == "role" else {}
	var role_name := str(role_definition.get("display_name", role_id))
	title_label.text = (role_name if assignment_type == "role" else "Resident").to_upper()
	subtitle_label.text = (
		"Select the best family member for this role"
		if assignment_type == "role"
		else "Select a family member for this House"
	)
	candidate_scroll.visible = not candidates.is_empty()
	empty_center.visible = candidates.is_empty()
	var required_stats := _required_stat_keys(role_definition)
	for value in candidates:
		if value is Dictionary:
			candidate_grid.add_child(_candidate_card(value, required_stats))


func _get_display_candidates() -> Array:
	var candidates := (
		HouseManager.get_role_candidates(house_instance_id, role_id)
		if assignment_type == "role"
		else HouseManager.get_resident_candidates(house_instance_id)
	)
	if assignment_type != "role" or current_character_id <= 0:
		return candidates
	var current := CharacterManager.get_character_by_id(current_character_id)
	if current.is_empty():
		return candidates
	var current_card := current.duplicate(true)
	current_card["performance_tier"] = HouseManager.get_role_performance_tier(current_character_id, role_id)
	current_card["performance_score"] = HouseManager.get_role_performance_score(current_character_id, role_id)
	current_card["is_current_house_member"] = true
	candidates.push_front(current_card)
	return candidates


func _candidate_card(character: Dictionary, required_stats: Array[String]) -> Control:
	var character_id := int(character.get("character_id", 0))
	var is_current := bool(character.get("is_current_house_member", false))
	var panel := PanelContainer.new()
	panel.name = "CandidateCard_%d" % character_id
	panel.custom_minimum_size = Vector2(0, 658)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _card_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var portrait_center := CenterContainer.new()
	portrait_center.custom_minimum_size = Vector2(0, 120)
	content.add_child(portrait_center)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_path := CharacterManager.get_avatar_path(character)
	_set_texture(portrait, portrait_path if not portrait_path.is_empty() else PATH_DEFAULT_AVATAR)
	portrait_center.add_child(portrait)

	var portrait_name_spacer := Control.new()
	portrait_name_spacer.custom_minimum_size = Vector2.ZERO
	content.add_child(portrait_name_spacer)
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = _character_name(character)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_label(name_label, FONT_SEMIBOLD, 40, COLOR_TEXT)
	content.add_child(name_label)

	var age_label := Label.new()
	age_label.name = "AgeLabel"
	age_label.text = "%d · %s" % [
		maxi(CharacterManager.get_character_age(character), 0),
		_format_life_stage(str(character.get("life_stage", "")))
	]
	age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label(age_label, FONT_REGULAR, 24, COLOR_TEXT)
	content.add_child(age_label)

	var tier_center := CenterContainer.new()
	tier_center.name = "TierCenter"
	tier_center.custom_minimum_size = Vector2(0, 38)
	content.add_child(tier_center)
	if assignment_type == "role":
		var tier := str(character.get("performance_tier", "D")).to_upper()
		var tier_icon := TextureRect.new()
		tier_icon.name = "TierIcon_" + tier
		tier_icon.custom_minimum_size = Vector2(34, 34)
		tier_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tier_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_set_texture(tier_icon, PATH_TIER_DIR + tier + ".svg")
		tier_center.add_child(tier_icon)
	var tier_stats_spacer := Control.new()
	tier_stats_spacer.custom_minimum_size = Vector2(0, 9)
	content.add_child(tier_stats_spacer)

	var stats_center := CenterContainer.new()
	stats_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(stats_center)
	var stats_panel := PanelContainer.new()
	stats_panel.name = "StatsPanel"
	stats_panel.custom_minimum_size = Vector2(272, 224)
	stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stats_panel.add_theme_stylebox_override("panel", _stats_style())
	stats_center.add_child(stats_panel)
	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 24)
	stats_margin.add_theme_constant_override("margin_top", 24)
	stats_margin.add_theme_constant_override("margin_right", 24)
	stats_margin.add_theme_constant_override("margin_bottom", 24)
	stats_panel.add_child(stats_margin)
	var stats_grid := GridContainer.new()
	stats_grid.name = "StatsGrid"
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 40)
	stats_grid.add_theme_constant_override("v_separation", 16)
	stats_margin.add_child(stats_grid)
	for stat_name in STAT_ORDER:
		stats_grid.add_child(_stat_cell(stat_name, int(character.get(stat_name, 0)), required_stats.has(stat_name)))
	var stats_action_spacer := Control.new()
	stats_action_spacer.custom_minimum_size = Vector2(0, 8)
	content.add_child(stats_action_spacer)

	var action := Button.new()
	action.name = "RemoveButton" if is_current else "AssignButton"
	action.custom_minimum_size = Vector2(0, 70)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.text = "Remove from House" if is_current else "Assign"
	if is_current:
		_set_button(action, FONT_MEDIUM, 26, COLOR_BROWN, _remove_button_style())
		action.pressed.connect(_remove_current)
	else:
		_set_button(action, FONT_MEDIUM, 26, Color.WHITE, _action_style())
		action.pressed.connect(_assign_candidate.bind(character_id))
	content.add_child(action)
	return panel


func _stat_cell(stat_name: String, stat_value: int, highlighted: bool) -> Control:
	var row := HBoxContainer.new()
	row.name = "Stat_" + stat_name
	row.custom_minimum_size = Vector2(96, 32)
	row.add_theme_constant_override("separation", 32)
	var icon := TextureRect.new()
	icon.name = "Icon_" + stat_name
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_texture(icon, STAT_ICON_DIR + str(STAT_ICONS.get(stat_name, "")))
	row.add_child(icon)
	var value_label := Label.new()
	value_label.name = "Value_" + stat_name
	value_label.text = str(stat_value)
	_set_label(value_label, FONT_MEDIUM, 24, COLOR_RED if highlighted else COLOR_TEXT)
	row.add_child(value_label)
	return row


func _required_stat_keys(role_definition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var required_value = role_definition.get("required_stats", [])
	if required_value is Array:
		for value in required_value:
			result.append(str(value).to_lower())
	return result


func _assign_candidate(character_id: int) -> void:
	var applied := (
		HouseManager.assign_character_to_role(house_instance_id, role_id, character_id)
		if assignment_type == "role"
		else HouseManager.assign_character_as_resident(house_instance_id, character_id)
	)
	if not applied:
		error_label.text = "Assignment could not be completed. Check capacity and eligibility."
		error_label.visible = true
		return
	assignment_applied.emit()
	queue_free()


func _remove_current() -> void:
	if current_character_id <= 0 or not HouseManager.remove_character_from_house(current_character_id):
		error_label.text = "The current household member could not be removed."
		error_label.visible = true
		return
	assignment_applied.emit()
	queue_free()


func _cancel() -> void:
	cancelled.emit()
	queue_free()


func _sheet_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.corner_radius_top_left = 40
	style.corner_radius_top_right = 40
	style.anti_aliasing = true
	return style


func _card_style() -> StyleBoxFlat:
	var style := _rounded_style(COLOR_CARD, 20)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	return style


func _stats_style() -> StyleBoxFlat:
	var style := _rounded_style(COLOR_CARD, 16)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	return style


func _action_style() -> StyleBoxFlat:
	return _rounded_style(COLOR_GREEN, 14)


func _remove_button_style() -> StyleBoxFlat:
	var style := _rounded_style(COLOR_REMOVE_BUTTON, 14)
	style.border_color = COLOR_REMOVE_BORDER
	style.set_border_width_all(1)
	return style


func _rounded_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


func _character_name(character: Dictionary) -> String:
	var full_name := (str(character.get("first_name", "")) + " " + str(character.get("last_name", ""))).strip_edges()
	return full_name if not full_name.is_empty() else "Family Member"


func _format_life_stage(value: String) -> String:
	return value.replace("_", " ").capitalize()


func _set_texture(target: TextureRect, path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var resource := load(path)
	if resource is Texture2D:
		target.texture = resource


func _set_button(button: Button, font_path: String, size: int, color: Color, style: StyleBoxFlat) -> void:
	if ResourceLoader.exists(font_path):
		button.add_theme_font_override("font", load(font_path))
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_focus_color", color)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)


func _set_label(label: Label, font_path: String, size: int, color: Color) -> void:
	if ResourceLoader.exists(font_path):
		label.add_theme_font_override("font", load(font_path))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
