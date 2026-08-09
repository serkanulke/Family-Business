extends Control

signal candidate_selected(source_type: String, candidate_id)
signal cancelled

const SOURCE_FAMILY := "family"
const SOURCE_NPC := "npc"

const FILTER_ALL := "all"
const FILTER_YOUNG_ADULT := "young_adult"
const FILTER_ADULT := "adult"
const FILTER_ELDER := "elder"

const COLOR_TEXT := Color("#1E1E1E")
const COLOR_BROWN := Color("#6D4534")
const COLOR_GREEN := Color("#07884F")
const COLOR_RED := Color("#E8403E")
const COLOR_BORDER := Color("#F3DFD3")
const COLOR_CARD := Color("#FEF9F5")
const COLOR_STATS := Color("#FEF9F5")
const COLOR_BUTTON := Color("#63A479")
const COLOR_FILTER_SELECTED := Color("#E1CBB4")
const COLOR_FILTER_IDLE := Color(1, 1, 1, 0)

const FONT_REGULAR := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_MEDIUM := "res://Resources/Fonts/Roboto-Medium.ttf"
const FONT_SEMIBOLD := "res://Resources/Fonts/Roboto-SemiBold.ttf"
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"

const PATH_TIER_DIR := "res://Resources/Icons/performance-tier/"
const PATH_DEFAULT_AVATAR := "res://Resources/Characters/default_avatar.png"
const STAT_ICON_DIR := "res://Resources/Icons/stats/"

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

@export_enum("npc", "family") var default_source_type: String = SOURCE_NPC

var business_instance_id: String = ""
var business_type_id: String = ""
var slot_id: String = ""
var source_type: String = SOURCE_NPC
var age_filter: String = FILTER_ALL

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var all_button: Button = %AllButton
@onready var young_adult_button: Button = %YoungAdultButton
@onready var adult_button: Button = %AdultButton
@onready var elder_button: Button = %ElderButton
@onready var candidate_grid: GridContainer = %CandidateGrid
@onready var empty_label: Label = %EmptyLabel
@onready var error_label: Label = %ErrorLabel
@onready var backdrop_button: Button = $BackdropButton


func _ready() -> void:
	source_type = default_source_type
	backdrop_button.pressed.connect(_on_close_pressed)
	all_button.pressed.connect(func() -> void: _set_age_filter(FILTER_ALL))
	young_adult_button.pressed.connect(func() -> void: _set_age_filter(FILTER_YOUNG_ADULT))
	adult_button.pressed.connect(func() -> void: _set_age_filter(FILTER_ADULT))
	elder_button.pressed.connect(func() -> void: _set_age_filter(FILTER_ELDER))
	_apply_static_fonts()
	_update_filter_styles()
	_refresh()


func setup(
	new_business_instance_id: String,
	new_business_type_id: String,
	new_slot_id: String,
	new_source_type: String
) -> void:
	business_instance_id = new_business_instance_id
	business_type_id = new_business_type_id
	slot_id = new_slot_id
	if new_source_type in [SOURCE_FAMILY, SOURCE_NPC]:
		source_type = new_source_type
	age_filter = FILTER_ALL
	if is_node_ready():
		_refresh()


func show_assignment_error(message: String = "Assignment could not be completed.") -> void:
	error_label.text = message
	error_label.visible = true


func _set_age_filter(new_filter: String) -> void:
	if new_filter not in [FILTER_ALL, FILTER_YOUNG_ADULT, FILTER_ADULT, FILTER_ELDER]:
		return
	age_filter = new_filter
	error_label.visible = false
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return

	_clear_candidate_grid()
	_update_filter_styles()

	var slot_definition: Dictionary = {}
	if not business_type_id.is_empty() and not slot_id.is_empty():
		slot_definition = BusinessManager.get_slot_definition(business_type_id, slot_id)

	var slot_name := str(slot_definition.get("role_name", slot_definition.get("name", slot_id)))
	if slot_name.is_empty():
		slot_name = "POSITION"
	title_label.text = slot_name.to_upper()
	subtitle_label.text = (
		"Select a family member"
		if source_type == SOURCE_FAMILY
		else "Select the best candidate"
	)

	var required_stats := _required_stat_keys(slot_definition)
	var candidates: Array = _get_candidates()
	empty_label.visible = candidates.is_empty() and not business_type_id.is_empty()

	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		candidate_grid.add_child(_create_candidate_card(candidate_value, required_stats))


func _get_candidates() -> Array:
	if business_type_id.is_empty() or slot_id.is_empty():
		return []

	if source_type == SOURCE_FAMILY:
		return BusinessManager.get_family_candidates_for_slot(
			business_type_id,
			slot_id,
			age_filter
		)

	var npc_manager := _get_npc_manager()
	if npc_manager == null:
		return []
	return npc_manager.get_candidates_for_slot(business_type_id, slot_id, age_filter)


func _get_npc_manager() -> Node:
	var manager := get_node_or_null("/root/NPCManager")
	if manager == null:
		manager = get_node_or_null("/root/NpcManager")
	return manager


func _clear_candidate_grid() -> void:
	for child in candidate_grid.get_children():
		child.queue_free()


func _create_candidate_card(candidate: Dictionary, required_stats: Array[String]) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 690)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _card_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var portrait_center := CenterContainer.new()
	portrait_center.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(portrait_center)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(118, 118)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_center.add_child(portrait)
	var portrait_path := str(candidate.get("portrait_path", ""))
	_set_texture(portrait, portrait_path if not portrait_path.is_empty() else PATH_DEFAULT_AVATAR)

	var name_label := Label.new()
	name_label.text = _get_candidate_name(candidate)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.y = 58
	_set_label_font(name_label, FONT_SEMIBOLD, 29, COLOR_TEXT)
	vbox.add_child(name_label)

	var age_label := Label.new()
	age_label.text = "%d · %s" % [
		int(candidate.get("age", 0)),
		_format_life_stage(str(candidate.get("life_stage", "")))
	]
	age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label_font(age_label, FONT_REGULAR, 20, COLOR_TEXT)
	vbox.add_child(age_label)

	var tier_center := CenterContainer.new()
	tier_center.custom_minimum_size = Vector2(0, 38)
	vbox.add_child(tier_center)
	var tier := str(candidate.get("performance_tier", "")).to_upper()
	if not tier.is_empty():
		var tier_icon := TextureRect.new()
		tier_icon.custom_minimum_size = Vector2(34, 34)
		tier_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tier_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_set_texture(tier_icon, PATH_TIER_DIR + tier + ".svg")
		tier_center.add_child(tier_icon)

	var income_label := Label.new()
	income_label.text = "%s /mo" % _money(int(candidate.get("business_income", 0)), true)
	income_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label_font(income_label, FONT_SEMIBOLD, 22, COLOR_GREEN)
	vbox.add_child(income_label)

	var income_caption := Label.new()
	income_caption.text = "Business Income"
	income_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label_font(income_caption, FONT_REGULAR, 14, COLOR_TEXT)
	vbox.add_child(income_caption)

	var stats_panel := PanelContainer.new()
	stats_panel.custom_minimum_size = Vector2(0, 205)
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.add_theme_stylebox_override("panel", _stats_style())
	vbox.add_child(stats_panel)

	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 16)
	stats_margin.add_theme_constant_override("margin_top", 14)
	stats_margin.add_theme_constant_override("margin_right", 16)
	stats_margin.add_theme_constant_override("margin_bottom", 14)
	stats_panel.add_child(stats_margin)

	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.add_theme_constant_override("h_separation", 22)
	stats_grid.add_theme_constant_override("v_separation", 11)
	stats_margin.add_child(stats_grid)

	var stats_value = candidate.get("stats", {})
	var stats: Dictionary = stats_value if typeof(stats_value) == TYPE_DICTIONARY else {}
	for stat_name in STAT_ORDER:
		stats_grid.add_child(_create_stat_cell(
			stat_name,
			int(stats.get(stat_name, 0)),
			required_stats.has(stat_name)
		))

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(0, 70)
	action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_button.text = "Assign" if source_type == SOURCE_FAMILY else "Hire"
	_set_button_font(action_button, FONT_MEDIUM, 26, Color.WHITE)
	var action_style := _action_button_style()
	action_button.add_theme_stylebox_override("normal", action_style)
	action_button.add_theme_stylebox_override("hover", action_style)
	action_button.add_theme_stylebox_override("pressed", action_style)
	action_button.add_theme_stylebox_override("focus", action_style)
	vbox.add_child(action_button)

	var candidate_id = (
		candidate.get("character_id", 0)
		if source_type == SOURCE_FAMILY
		else candidate.get("npc_id", "")
	)
	action_button.pressed.connect(
		func() -> void:
			candidate_selected.emit(source_type, candidate_id)
	)

	return panel


func _create_stat_cell(stat_name: String, stat_value: int, highlighted: bool) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(31, 31)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_file := str(STAT_ICONS.get(stat_name, ""))
	if not icon_file.is_empty():
		_set_texture(icon, STAT_ICON_DIR + icon_file)
	row.add_child(icon)

	var value_label := Label.new()
	value_label.text = str(stat_value)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_label_font(
		value_label,
		FONT_MEDIUM,
		20,
		COLOR_RED if highlighted else COLOR_TEXT
	)
	row.add_child(value_label)
	return row


func _required_stat_keys(slot_definition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var value = slot_definition.get("required_stats", {})
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value.keys():
		result.append(str(key).to_lower())
	return result


func _update_filter_styles() -> void:
	if not is_node_ready():
		return
	_apply_filter_style(all_button, age_filter == FILTER_ALL)
	_apply_filter_style(young_adult_button, age_filter == FILTER_YOUNG_ADULT)
	_apply_filter_style(adult_button, age_filter == FILTER_ADULT)
	_apply_filter_style(elder_button, age_filter == FILTER_ELDER)


func _apply_filter_style(button: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_FILTER_SELECTED if selected else COLOR_FILTER_IDLE
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 8
	style.content_margin_right = 8
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	_set_button_font(button, FONT_SEMIBOLD, 21, COLOR_BROWN)


func _apply_static_fonts() -> void:
	_set_label_font(title_label, FONT_BOLD, 34, COLOR_BROWN)
	_set_label_font(subtitle_label, FONT_REGULAR, 22, COLOR_BROWN)
	_set_label_font(empty_label, FONT_REGULAR, 20, COLOR_BROWN)
	_set_label_font(error_label, FONT_MEDIUM, 18, COLOR_RED)


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD
	style.border_color = COLOR_BORDER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	return style


func _stats_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_STATS
	style.border_color = COLOR_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	return style


func _action_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BUTTON
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style


func _get_candidate_name(candidate: Dictionary) -> String:
	return (
		str(candidate.get("first_name", ""))
		+ " "
		+ str(candidate.get("last_name", ""))
	).strip_edges()


func _format_life_stage(value: String) -> String:
	match value:
		FILTER_YOUNG_ADULT:
			return "Young Adult"
		FILTER_ADULT:
			return "Adult"
		FILTER_ELDER:
			return "Elder"
		_:
			return value.capitalize()


func _set_texture(target: TextureRect, path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var resource := load(path)
	if resource is Texture2D:
		target.texture = resource


func _set_label_font(label: Label, path: String, size: int, color: Color) -> void:
	if ResourceLoader.exists(path):
		var font := load(path)
		if font:
			label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


func _set_button_font(button: Button, path: String, size: int, color: Color) -> void:
	if ResourceLoader.exists(path):
		var font := load(path)
		if font:
			button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", color)


func _money(value: int, show_plus: bool) -> String:
	var amount := int(value)
	var abs_text := _group_digits(abs(amount))
	if amount < 0:
		return "-%s" % abs_text
	if show_plus and amount > 0:
		return "+%s" % abs_text
	return abs_text


func _group_digits(value: int) -> String:
	var raw := str(value)
	var result := ""
	while raw.length() > 3:
		result = "," + raw.right(3) + result
		raw = raw.left(raw.length() - 3)
	return raw + result


func _on_close_pressed() -> void:
	cancelled.emit()
	queue_free()
