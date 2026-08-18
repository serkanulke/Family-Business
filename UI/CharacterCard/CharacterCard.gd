extends CanvasLayer
class_name CharacterCard


signal card_opened(character_id: int)
signal card_closed
signal item_slot_requested(slot_type: String, character_id: int)


const CANVAS_SIZE := Vector2(1080.0, 1920.0)
const MODAL_LOGICAL_SIZE := Vector2(1080.0, 1656.0)
const MODAL_HORIZONTAL_MARGIN := 40.0
const MODAL_VERTICAL_MARGIN := 160.0
const DIM_OPACITY := 0.76
const DEFAULT_COMPANY_LOGO_PATH := "res://Resources/Companies/johnson_hospital.png"
const DEFAULT_AVATAR_PATH := "res://Resources/Characters/default_avatar.png"
const ICON_FOLDER := "res://Resources/Icons/character-card/"
const STAT_ICON_FOLDER := "res://Resources/Icons/stats/"
const PORTRAIT_ICON_FOLDER := "res://Resources/Icons/character-portrait/"
const FONT_REGULAR_PATH := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_BOLD_PATH := "res://Resources/Fonts/Roboto-Bold.ttf"
const FONT_EXTRA_BOLD_PATH := "res://Resources/Fonts/Roboto-ExtraBold.ttf"

# Colors sampled from the supplied Character Card screenshot.
const COLOR_PAGE := Color("#FCEFDE")
const COLOR_CARD := Color("#FFF9F4")
const COLOR_SUMMARY := Color("#FEF5EA")
const COLOR_BORDER := Color("#F4E2D8")
const COLOR_TEXT := Color("#1E1E1E")
const COLOR_SECONDARY := Color("#6D4534")
const COLOR_PROGRESS_BG := Color("#F0F0F0")

const STAT_DEFINITIONS: Array[Dictionary] = [
	{"key": "happiness", "label": "Happiness", "icon": "happiness.svg", "color": Color("#FFCE72")},
	{"key": "attractiveness", "label": "Attractiveness", "icon": "attractiveness.svg", "color": Color("#FF84A3")},
	{"key": "health", "label": "Health", "icon": "health.svg", "color": Color("#E8403E")},
	{"key": "confidence", "label": "Confidence", "icon": "confidence.svg", "color": Color("#234C90")},
	{"key": "logic", "label": "Logic", "icon": "logic.svg", "color": Color("#2773C7")},
	{"key": "social", "label": "Social", "icon": "social.svg", "color": Color("#F99265")},
	{"key": "creativity", "label": "Creativity", "icon": "creativity.svg", "color": Color("#A21CB7")},
	{"key": "discipline", "label": "Discipline", "icon": "discipline.svg", "color": Color("#34C46F")}
]
const ITEM_SLOT_DEFINITIONS: Array[Dictionary] = [
	{"key": "accessory", "icon": "accessories.svg"},
	{"key": "outfit", "icon": "dresses.svg"},
	{"key": "vehicle", "icon": "cars.svg"}
]


@export var character_card_theme: Theme
@export_file("*.png") var default_company_logo_path := DEFAULT_COMPANY_LOGO_PATH

var character_id: int = 0
var character_data: Dictionary = {}
var modal_root: Control
var dim_background: ColorRect
var modal_container: Control
var character_card_panel: PanelContainer
var viewport_root: Control
var scroll_container: ScrollContainer
var portrait_texture: TextureRect
var character_name_label: Label
var gender_icon: TextureRect
var age_label: Label
var spouse_value_label: Label
var header_career_label: Label
var birth_value_label: Label
var life_stage_value_label: Label
var salary_value_label: Label
var lifestyle_class_panel: PanelContainer
var lifestyle_class_label: Label
var item_count_label: Label
var education_icon: TextureRect
var education_school_label: Label
var education_major_label: Label
var education_status_label: Label
var career_logo: TextureRect
var career_company_label: Label
var career_job_label: Label
var career_since_label: Label
var event_history_list: VBoxContainer
var stat_bars: Dictionary = {}
var stat_value_labels: Dictionary = {}
var lifestyle_stars: Array[TextureRect] = []
var item_buttons: Dictionary = {}
var resolved_career: Dictionary = {}
var resolved_lifestyle_score: int = 0


func _ready() -> void:
	_build_interface()
	if not modal_root.resized.is_connected(_layout_modal):
		modal_root.resized.connect(_layout_modal)
	call_deferred("_layout_modal")


func open_for_character(new_character_id: int) -> bool:
	var manager := _get_manager("CharacterManager")
	if manager == null:
		push_error("CharacterCard could not find CharacterManager.")
		return false
	var value = manager.call("get_character_by_id", new_character_id)
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		push_error("CharacterCard could not find character %d." % new_character_id)
		return false
	set_character_data(value)
	visible = true
	_layout_modal()
	if scroll_container != null:
		scroll_container.scroll_vertical = 0
	card_opened.emit(character_id)
	return true


func set_character_data(character: Dictionary) -> void:
	character_data = character.duplicate(true)
	character_id = int(character_data.get("character_id", 0))
	_refresh_character_content()


func refresh_current_character() -> void:
	if character_id <= 0:
		return
	var manager := _get_manager("CharacterManager")
	if manager == null:
		return
	var value = manager.call("get_character_by_id", character_id)
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		close_card()
		return
	set_character_data(value)


func close_card() -> void:
	if not visible:
		return
	visible = false
	card_closed.emit()


func request_item_slot(slot_type: String) -> void:
	var normalized := slot_type.strip_edges().to_lower()
	if normalized not in ["accessory", "outfit", "vehicle"]:
		push_error("CharacterCard received an unknown item slot: " + slot_type)
		return
	item_slot_requested.emit(normalized, character_id)


func get_lifestyle_star_count(score: int) -> int:
	var value := clampi(score, 0, 100)
	if value <= 0:
		return 0
	if value <= 34:
		return 1
	if value <= 59:
		return 2
	if value <= 79:
		return 3
	if value <= 94:
		return 4
	return 5


func get_display_snapshot() -> Dictionary:
	return {
		"character_id": character_id,
		"name": character_name_label.text,
		"age": age_label.text,
		"spouse": spouse_value_label.text,
		"job": String(resolved_career.get("job_name", "Unemployed")),
		"company": String(resolved_career.get("company_name", "")),
		"birth_date": birth_value_label.text,
		"life_stage": life_stage_value_label.text,
		"salary": salary_value_label.text,
		"lifestyle_stars": get_lifestyle_star_count(resolved_lifestyle_score),
		"lifestyle_class": lifestyle_class_label.text if lifestyle_class_panel.visible else "",
		"item_count": "0/3"
	}


func _build_interface() -> void:
	modal_root = get_node_or_null("CharacterCardModal") as Control
	if modal_root == null:
		modal_root = Control.new()
		modal_root.name = "CharacterCardModal"
		modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(modal_root)
	modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_background = ColorRect.new()
	dim_background.name = "DimBackground"
	dim_background.color = Color(0.0, 0.0, 0.0, DIM_OPACITY)
	dim_background.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_background.gui_input.connect(_block_background_input)
	modal_root.add_child(dim_background)

	modal_container = Control.new()
	modal_container.name = "ModalContainer"
	modal_container.custom_minimum_size = MODAL_LOGICAL_SIZE
	modal_container.size = MODAL_LOGICAL_SIZE
	modal_container.pivot_offset = MODAL_LOGICAL_SIZE * 0.5
	modal_container.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_root.add_child(modal_container)

	character_card_panel = PanelContainer.new()
	character_card_panel.name = "CharacterCardPanel"
	character_card_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	character_card_panel.clip_contents = true
	character_card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	character_card_panel.add_theme_stylebox_override(
		"panel",
		_make_style(COLOR_PAGE, 42, Color.TRANSPARENT, 0)
	)
	modal_container.add_child(character_card_panel)

	viewport_root = Control.new()
	viewport_root.name = "ViewportRoot"
	viewport_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_root.custom_minimum_size = MODAL_LOGICAL_SIZE
	viewport_root.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport_root.theme = character_card_theme
	character_card_panel.add_child(viewport_root)
	scroll_container = ScrollContainer.new()
	scroll_container.name = "ContentScroll"
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport_root.add_child(scroll_container)
	var page_margin := _make_margin(31, 32, 31, 34)
	page_margin.name = "PageMargin"
	page_margin.custom_minimum_size = Vector2(1080.0, 0.0)
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(page_margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.custom_minimum_size = Vector2(1018.0, 0.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 32)
	page_margin.add_child(content)
	_build_profile_card(content)
	_build_attributes_card(content)
	_build_lifestyle_items_row(content)
	_build_education_career_row(content)
	_build_event_history_card(content)


func _layout_modal() -> void:
	if modal_container == null:
		return
	var viewport_size := modal_root.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = CANVAS_SIZE
	var width_scale := (
		(viewport_size.x - MODAL_HORIZONTAL_MARGIN * 2.0)
		/ MODAL_LOGICAL_SIZE.x
	)
	var height_scale := (
		(viewport_size.y - MODAL_VERTICAL_MARGIN * 2.0)
		/ MODAL_LOGICAL_SIZE.y
	)
	var modal_scale := clampf(minf(width_scale, height_scale), 0.1, 1.0)
	modal_container.size = MODAL_LOGICAL_SIZE
	modal_container.pivot_offset = MODAL_LOGICAL_SIZE * 0.5
	modal_container.scale = Vector2(modal_scale, modal_scale)
	modal_container.position = (viewport_size - MODAL_LOGICAL_SIZE) * 0.5


func _block_background_input(_event: InputEvent) -> void:
	# The dim layer blocks pointer and touch input without closing the modal.
	get_viewport().set_input_as_handled()


func _build_profile_card(parent: VBoxContainer) -> void:
	var card := _make_card("ProfileCard", 446.0)
	parent.add_child(card)
	var canvas := Control.new()
	canvas.name = "ProfileContent"
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(canvas)
	var portrait_panel := PanelContainer.new()
	portrait_panel.name = "PortraitFrame"
	portrait_panel.position = Vector2(28.0, 24.0)
	portrait_panel.size = Vector2(236.0, 236.0)
	portrait_panel.clip_contents = true
	portrait_panel.add_theme_stylebox_override("panel", _make_style(Color("#F2E7F2"), 118, Color.WHITE, 10))
	canvas.add_child(portrait_panel)
	portrait_texture = _make_texture_rect(DEFAULT_AVATAR_PATH, Vector2(216.0, 216.0))
	portrait_texture.name = "Portrait"
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_panel.add_child(portrait_texture)
	var identity := VBoxContainer.new()
	identity.name = "Identity"
	identity.position = Vector2(291.0, 27.0)
	identity.size = Vector2(650.0, 213.0)
	identity.add_theme_constant_override("separation", 7)
	canvas.add_child(identity)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 16)
	identity.add_child(name_row)
	character_name_label = _make_label("Character", 58, COLOR_TEXT, "extra_bold")
	name_row.add_child(character_name_label)
	gender_icon = _make_texture_rect(ICON_FOLDER + "female.svg", Vector2(39.0, 53.0))
	name_row.add_child(gender_icon)
	age_label = _make_label("0 years old", 33, COLOR_SECONDARY, "bold")
	identity.add_child(age_label)
	spouse_value_label = _add_identity_row(identity, "relationship-status.svg", "Single")
	header_career_label = _add_identity_row(identity, "job-status.svg", "Unemployed")
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.position = Vector2(950.0, 8.0)
	close_button.size = Vector2(56.0, 56.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_override("font", _load_font(FONT_REGULAR_PATH))
	close_button.add_theme_font_size_override("font_size", 43)
	close_button.add_theme_color_override("font_color", COLOR_TEXT)
	var close_style := _make_style(Color.WHITE, 28, Color.TRANSPARENT, 0)
	close_button.add_theme_stylebox_override("normal", close_style)
	close_button.add_theme_stylebox_override("hover", close_style)
	close_button.add_theme_stylebox_override("pressed", close_style)
	close_button.pressed.connect(close_card)
	canvas.add_child(close_button)
	var summary := PanelContainer.new()
	summary.name = "Summary"
	summary.position = Vector2(29.0, 282.0)
	summary.size = Vector2(960.0, 132.0)
	summary.add_theme_stylebox_override("panel", _make_style(COLOR_SUMMARY, 20, COLOR_BORDER, 2))
	canvas.add_child(summary)
	var summary_margin := _make_margin(28, 22, 28, 22)
	summary.add_child(summary_margin)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 22)
	summary_margin.add_child(summary_row)
	birth_value_label = _add_summary_entry(summary_row, "birth.svg", "Birth", "—")
	summary_row.add_child(_make_vertical_separator())
	life_stage_value_label = _add_summary_entry(summary_row, "age-state.svg", "Age Stage", "—")
	summary_row.add_child(_make_vertical_separator())
	salary_value_label = _add_summary_entry(summary_row, "salary.svg", "Salary", "0 /month")


func _add_identity_row(parent: VBoxContainer, icon_file: String, initial_text: String) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 42.0)
	row.add_theme_constant_override("separation", 17)
	parent.add_child(row)
	row.add_child(_make_texture_rect(ICON_FOLDER + icon_file, Vector2(38.0, 38.0)))
	var label := _make_label(initial_text, 31, COLOR_TEXT, "regular")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	return label


func _add_summary_entry(parent: HBoxContainer, icon_file: String, caption: String, value: String) -> Label:
	var entry := HBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_theme_constant_override("separation", 17)
	parent.add_child(entry)
	entry.add_child(_make_texture_rect(ICON_FOLDER + icon_file, Vector2(43.0, 43.0)))
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(labels)
	labels.add_child(_make_label(caption, 25, COLOR_SECONDARY, "regular"))
	var label := _make_label(value, 29, COLOR_TEXT, "bold")
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	labels.add_child(label)
	return label


func _build_attributes_card(parent: VBoxContainer) -> void:
	var card := _make_card("AttributesCard", 542.0)
	parent.add_child(card)
	var box := _make_card_box("Attributes", 68)
	card.add_child(box)
	var body := box.get_node("Body") as MarginContainer
	_set_margins(body, 50, 38, 50, 36)
	var grid := GridContainer.new()
	grid.name = "AttributesGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 68)
	grid.add_theme_constant_override("v_separation", 28)
	body.add_child(grid)
	for definition in STAT_DEFINITIONS:
		_add_stat_row(grid, definition)


func _add_stat_row(parent: GridContainer, definition: Dictionary) -> void:
	var key := String(definition["key"])
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(425.0, 83.0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	column.add_child(top)
	top.add_child(_make_texture_rect(STAT_ICON_FOLDER + String(definition["icon"]), Vector2(42.0, 42.0)))
	var title := _make_label(String(definition["label"]), 31, COLOR_TEXT, "regular")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var value_label := _make_label("0", 29, COLOR_TEXT, "regular")
	top.add_child(value_label)
	stat_value_labels[key] = value_label
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0.0, 18.0)
	progress.max_value = 100.0
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", _make_style(COLOR_PROGRESS_BG, 9, Color.TRANSPARENT, 0))
	progress.add_theme_stylebox_override("fill", _make_style(definition["color"], 9, Color.TRANSPARENT, 0))
	column.add_child(progress)
	stat_bars[key] = progress


func _build_lifestyle_items_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "LifestyleItemsRow"
	row.custom_minimum_size = Vector2(0.0, 262.0)
	row.add_theme_constant_override("separation", 32)
	parent.add_child(row)
	_build_lifestyle_card(row)
	_build_items_card(row)


func _build_lifestyle_card(parent: HBoxContainer) -> void:
	var card := _make_card("LifestyleCard", 262.0)
	card.custom_minimum_size.x = 338.0
	parent.add_child(card)
	var box := _make_card_box("Lifestyle", 68)
	card.add_child(box)
	var body := box.get_node("Body") as MarginContainer
	_set_margins(body, 29, 31, 24, 24)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 23)
	body.add_child(column)
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 8)
	column.add_child(stars)
	for star_index in range(5):
		var star := _make_texture_rect(ICON_FOLDER + "star-passive.svg", Vector2(37.0, 37.0))
		stars.add_child(star)
		lifestyle_stars.append(star)
	lifestyle_class_panel = PanelContainer.new()
	lifestyle_class_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lifestyle_class_panel.add_theme_stylebox_override("panel", _make_style(COLOR_BORDER, 9, Color.TRANSPARENT, 0))
	column.add_child(lifestyle_class_panel)
	var class_margin := _make_margin(14, 7, 14, 7)
	lifestyle_class_panel.add_child(class_margin)
	lifestyle_class_label = _make_label("", 25, COLOR_TEXT, "regular")
	class_margin.add_child(lifestyle_class_label)


func _build_items_card(parent: HBoxContainer) -> void:
	var card := _make_card("ItemsCard", 262.0)
	card.custom_minimum_size.x = 648.0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var box := _make_card_box("Items", 68, true)
	card.add_child(box)
	var body := box.get_node("Body") as MarginContainer
	_set_margins(body, 29, 31, 29, 30)
	var slots := HBoxContainer.new()
	slots.name = "ItemSlots"
	slots.add_theme_constant_override("separation", 31)
	body.add_child(slots)
	for definition in ITEM_SLOT_DEFINITIONS:
		_add_empty_item_slot(slots, definition)


func _add_empty_item_slot(parent: HBoxContainer, definition: Dictionary) -> void:
	var slot_key := String(definition["key"])
	var button := Button.new()
	button.name = "%sSlot" % slot_key.capitalize()
	button.custom_minimum_size = Vector2(176.0, 129.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _make_style(COLOR_CARD, 18, COLOR_BORDER, 2))
	button.add_theme_stylebox_override("hover", _make_style(COLOR_SUMMARY, 18, COLOR_BORDER, 2))
	button.add_theme_stylebox_override("pressed", _make_style(COLOR_SUMMARY, 18, COLOR_BORDER, 2))
	button.pressed.connect(request_item_slot.bind(slot_key))
	parent.add_child(button)
	item_buttons[slot_key] = button
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(center)
	var icon := _make_texture_rect(ICON_FOLDER + String(definition["icon"]), Vector2(57.0, 57.0))
	icon.modulate = Color(1.0, 1.0, 1.0, 0.66)
	center.add_child(icon)


func _build_education_career_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "EducationCareerRow"
	row.custom_minimum_size = Vector2(0.0, 234.0)
	row.add_theme_constant_override("separation", 32)
	parent.add_child(row)
	_build_education_card(row)
	_build_career_card(row)


func _build_education_card(parent: HBoxContainer) -> void:
	var card := _make_card("EducationCard", 234.0)
	card.custom_minimum_size.x = 493.0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var box := _make_card_box("Education", 68)
	card.add_child(box)
	var body := box.get_node("Body") as MarginContainer
	_set_margins(body, 29, 31, 23, 28)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	body.add_child(row)
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(105.0, 105.0)
	icon_panel.add_theme_stylebox_override("panel", _make_style(Color.WHITE, 15, COLOR_BORDER, 1))
	row.add_child(icon_panel)
	education_icon = _make_texture_rect("", Vector2(84.0, 84.0))
	icon_panel.add_child(education_icon)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 2)
	row.add_child(detail)
	education_school_label = _make_label("No school", 29, COLOR_TEXT, "bold")
	education_school_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_child(education_school_label)
	education_major_label = _make_label("", 25, COLOR_TEXT, "regular")
	detail.add_child(education_major_label)
	education_status_label = _make_label("", 24, COLOR_SECONDARY, "regular")
	detail.add_child(education_status_label)


func _build_career_card(parent: HBoxContainer) -> void:
	var card := _make_card("CareerCard", 234.0)
	card.custom_minimum_size.x = 493.0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var box := _make_card_box("Career", 68)
	card.add_child(box)
	var body := box.get_node("Body") as MarginContainer
	_set_margins(body, 29, 31, 23, 28)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	body.add_child(row)
	var logo_panel := PanelContainer.new()
	logo_panel.custom_minimum_size = Vector2(105.0, 105.0)
	logo_panel.add_theme_stylebox_override("panel", _make_style(Color.WHITE, 15, COLOR_BORDER, 1))
	row.add_child(logo_panel)
	career_logo = _make_texture_rect(default_company_logo_path, Vector2(84.0, 84.0))
	logo_panel.add_child(career_logo)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 2)
	row.add_child(detail)
	career_company_label = _make_label("No current company", 29, COLOR_TEXT, "bold")
	career_company_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_child(career_company_label)
	career_job_label = _make_label("Unemployed", 25, COLOR_TEXT, "regular")
	detail.add_child(career_job_label)
	career_since_label = _make_label("", 24, COLOR_SECONDARY, "regular")
	detail.add_child(career_since_label)


func _build_event_history_card(parent: VBoxContainer) -> void:
	var card := _make_card("EventHistoryCard", 404.0)
	parent.add_child(card)
	var box := _make_card_box("Event History", 68)
	card.add_child(box)
	var body := box.get_node("Body") as MarginContainer
	_set_margins(body, 29, 8, 29, 15)
	event_history_list = VBoxContainer.new()
	event_history_list.name = "EventHistoryList"
	event_history_list.add_theme_constant_override("separation", 0)
	body.add_child(event_history_list)


func _make_card_box(title: String, header_height: int, show_item_count: bool = false) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 0)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0.0, header_height)
	var header_margin := _make_margin(29, 0, 29, 0)
	header_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_margin)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	header_margin.add_child(title_row)
	var title_label := _make_label(title, 25, COLOR_TEXT, "bold")
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title_label)
	if show_item_count:
		item_count_label = _make_label("(0/3)", 25, COLOR_TEXT, "bold")
		item_count_label.name = "ItemCount"
		title_row.add_child(item_count_label)
	box.add_child(header)
	var separator := HSeparator.new()
	var line_style := StyleBoxLine.new()
	line_style.color = COLOR_BORDER
	line_style.thickness = 1
	separator.add_theme_stylebox_override("separator", line_style)
	box.add_child(separator)
	var body := MarginContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	return box


func _refresh_character_content() -> void:
	if viewport_root == null:
		return
	character_name_label.text = _get_character_display_name(character_data)
	var gender := _string_value(character_data.get("gender", "")).strip_edges().to_lower()
	gender_icon.texture = _load_texture(ICON_FOLDER + "female.svg" if gender == "female" else PORTRAIT_ICON_FOLDER + "male-icon.svg")
	age_label.text = "%d years old" % maxi(_get_character_age(character_data), 0)
	portrait_texture.texture = _resolve_portrait_texture(character_data)
	spouse_value_label.text = _resolve_spouse_text(character_data)
	resolved_career = _resolve_career(character_data)
	_apply_career(resolved_career)
	birth_value_label.text = _format_date(_string_value(character_data.get("birth_date", "")))
	life_stage_value_label.text = _humanize(_string_value(character_data.get("life_stage", "")))
	salary_value_label.text = _format_monthly_amount(int(resolved_career.get("salary", 0)))
	for definition in STAT_DEFINITIONS:
		var key := String(definition["key"])
		var value := clampi(int(character_data.get(key, 0)), 0, 100)
		(stat_bars.get(key) as ProgressBar).value = value
		(stat_value_labels.get(key) as Label).text = str(value)
	resolved_lifestyle_score = _resolve_lifestyle_score(character_data)
	_apply_lifestyle_stars(resolved_lifestyle_score)
	var class_text := _resolve_lifestyle_class_label(character_data)
	lifestyle_class_panel.visible = not class_text.is_empty()
	lifestyle_class_label.text = class_text
	item_count_label.text = "(0/3)"
	_apply_education(character_data)
	_rebuild_event_history(character_data)


func _resolve_portrait_texture(character: Dictionary) -> Texture2D:
	var manager := _get_manager("CharacterManager")
	if manager != null and manager.has_method("get_avatar_texture"):
		var value = manager.call("get_avatar_texture", character)
		if value is Texture2D:
			return value
	return _load_texture(DEFAULT_AVATAR_PATH)


func _resolve_spouse_text(character: Dictionary) -> String:
	var partner_id = character.get("partner_id", null)
	if partner_id == null:
		return "Single"
	var manager := _get_manager("CharacterManager")
	if manager == null:
		return "—"
	var value = manager.call("get_character_by_id", int(partner_id))
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		return "—"
	return "Married to " + _get_character_display_name(value)


func _resolve_career(character: Dictionary) -> Dictionary:
	if bool(character.get("is_retired", false)):
		return {"job_name": "Retired", "company_name": "", "logo_path": "", "salary": 0, "has_company": false}
	var family_business := _resolve_family_business_career(character)
	if not family_business.is_empty():
		return family_business
	var manager := _get_manager("CareerManager")
	var job_id = character.get("job_id", null)
	var company_id := _string_value(character.get("company_id", ""))
	var job: Dictionary = {}
	var company: Dictionary = {}
	if manager != null:
		if job_id != null:
			var job_value = manager.call("get_job_by_id", int(job_id))
			if typeof(job_value) == TYPE_DICTIONARY:
				job = job_value
		if not company_id.is_empty():
			var company_value = manager.call("get_company_by_id", company_id)
			if typeof(company_value) == TYPE_DICTIONARY:
				company = company_value
	if job.is_empty():
		return {"job_name": "Unemployed", "company_name": "", "logo_path": "", "salary": 0, "has_company": false}
	return {
		"job_name": String(job.get("job_name", "Unemployed")),
		"company_name": String(company.get("company_name", "")),
		"logo_path": String(company.get("logo_path", "")),
		"salary": int(character.get("salary", 0)),
		"has_company": not company.is_empty()
	}


func _resolve_family_business_career(character: Dictionary) -> Dictionary:
	var manager := _get_manager("BusinessManager")
	if manager == null or not manager.has_method("get_character_assignment"):
		return {}
	var assignment_value = manager.call("get_character_assignment", int(character.get("character_id", 0)))
	if typeof(assignment_value) != TYPE_DICTIONARY or (assignment_value as Dictionary).is_empty():
		return {}
	var assignment: Dictionary = assignment_value
	var business_value = manager.call("get_business_by_instance_id", String(assignment.get("business_instance_id", "")))
	if typeof(business_value) != TYPE_DICTIONARY:
		return {}
	var business: Dictionary = business_value
	var type_value = manager.call("get_business_type_by_id", String(business.get("business_type_id", "")))
	if typeof(type_value) != TYPE_DICTIONARY:
		return {}
	var business_type: Dictionary = type_value
	var slot_value = manager.call("get_slot_definition", String(business.get("business_type_id", "")), String(assignment.get("slot_id", "")))
	var slot: Dictionary = slot_value if typeof(slot_value) == TYPE_DICTIONARY else {}
	return {"job_name": String(slot.get("role_name", "Family business role")), "company_name": String(business_type.get("display_name", "Family Business")), "logo_path": "", "salary": 0, "has_company": true}


func _apply_career(career: Dictionary) -> void:
	var job_name := String(career.get("job_name", "Unemployed"))
	var company_name := String(career.get("company_name", ""))
	var has_company := bool(career.get("has_company", false))
	header_career_label.text = "%s at %s" % [job_name, company_name] if has_company else job_name
	career_company_label.text = company_name if has_company else job_name
	career_job_label.text = job_name if has_company else ""
	career_logo.texture = _load_texture(_resolve_company_logo_path(String(career.get("logo_path", ""))))
	career_logo.visible = has_company
	var since_year := _resolve_career_since_year(character_data)
	career_since_label.text = "Since: %s" % since_year if not since_year.is_empty() else ""


func _apply_education(character: Dictionary) -> void:
	var school_id = character.get("school_id", null)
	var major_id = character.get("major_id", null)
	var education_manager := _get_manager("EducationManager")
	var character_manager := _get_manager("CharacterManager")
	var school: Dictionary = {}
	var major: Dictionary = {}
	if education_manager != null and school_id != null:
		var value = education_manager.call("get_school_by_id", int(school_id))
		if typeof(value) == TYPE_DICTIONARY:
			school = value
	if character_manager != null and major_id != null:
		var majors_value = character_manager.get("majors")
		if typeof(majors_value) == TYPE_ARRAY:
			major = _find_dictionary_by_int_id(majors_value, "major_id", int(major_id))
	education_school_label.text = String(school.get("school_name", "No school"))
	education_major_label.text = String(major.get("major_name", ""))
	education_status_label.text = _humanize(String(character.get("education_status", "")))
	education_icon.texture = _load_texture(String(school.get("icon_path", "")))
	education_icon.visible = education_icon.texture != null


func _resolve_lifestyle_score(character: Dictionary) -> int:
	# TODO: GDD thresholds are confirmed, but no canonical Lifestyle value exists in the repository yet.
	var manager := _get_manager("CharacterManager")
	if manager != null and manager.has_method("get_lifestyle_score"):
		return clampi(int(manager.call("get_lifestyle_score", character)), 0, 100)
	return 0


func _resolve_lifestyle_class_label(character: Dictionary) -> String:
	# TODO: Connect when the project gains a canonical class-label resolver.
	var manager := _get_manager("CharacterManager")
	if manager != null and manager.has_method("get_lifestyle_class_label"):
		return _string_value(manager.call("get_lifestyle_class_label", character)).strip_edges()
	return ""


func _apply_lifestyle_stars(score: int) -> void:
	var active_count := get_lifestyle_star_count(score)
	for index in range(lifestyle_stars.size()):
		var icon_file := "star-active.svg" if index < active_count else "star-passive.svg"
		lifestyle_stars[index].texture = _load_texture(ICON_FOLDER + icon_file)


func _resolve_career_since_year(character: Dictionary) -> String:
	var events_value = character.get("event_log", [])
	if typeof(events_value) != TYPE_ARRAY:
		return ""
	var company_id := _string_value(character.get("company_id", ""))
	var job_id = character.get("job_id", null)
	var events: Array = events_value
	for index in range(events.size() - 1, -1, -1):
		if typeof(events[index]) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = events[index]
		if _string_value(event.get("company_id", "")) != company_id:
			continue
		if job_id != null and event.has("job_id") and int(event.get("job_id", -1)) != int(job_id):
			continue
		var year := _extract_year(_string_value(event.get("date", "")))
		if not year.is_empty():
			return year
	return ""


func _rebuild_event_history(character: Dictionary) -> void:
	for child in event_history_list.get_children():
		event_history_list.remove_child(child)
		child.queue_free()
	var value = character.get("event_log", [])
	if typeof(value) != TYPE_ARRAY:
		return
	var events: Array = value
	for index in range(events.size() - 1, -1, -1):
		_add_event_history_entry(events[index], index > 0)


func _add_event_history_entry(event_value: Variant, show_separator: bool) -> void:
	if typeof(event_value) != TYPE_DICTIONARY:
		return
	var event: Dictionary = event_value
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 63.0)
	row.add_theme_constant_override("separation", 18)
	event_history_list.add_child(row)
	var year_label := _make_label(_extract_year(_string_value(event.get("date", ""))), 27, COLOR_SECONDARY, "regular")
	year_label.custom_minimum_size = Vector2(92.0, 0.0)
	row.add_child(year_label)
	var event_icon := _make_texture_rect(_resolve_event_icon_path(event), Vector2(35.0, 35.0))
	event_icon.visible = event_icon.texture != null
	row.add_child(event_icon)
	var description := _make_label(_resolve_event_description(event), 27, COLOR_SECONDARY, "regular")
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(description)
	if show_separator:
		var separator := HSeparator.new()
		var style := StyleBoxLine.new()
		style.color = COLOR_BORDER
		style.thickness = 1
		separator.add_theme_stylebox_override("separator", style)
		event_history_list.add_child(separator)


func _resolve_event_description(event: Dictionary) -> String:
	var description := _string_value(event.get("description", "")).strip_edges()
	if not description.is_empty():
		return description
	var title := _string_value(event.get("title", "")).strip_edges()
	if not title.is_empty():
		return title
	var event_type := _string_value(event.get("event_type", "event"))
	var school_name := _resolve_school_name(event.get("school_id", null))
	var major_name := _resolve_major_name(event.get("major_id", null))
	match event_type:
		"education_started":
			return "Started %s at %s" % [major_name, school_name] if not major_name.is_empty() else "Started at " + school_name
		"major_selected":
			return "Started " + major_name if not major_name.is_empty() else "Selected a major"
		"education_graduated":
			return "Graduated from " + school_name if not school_name.is_empty() else "Graduated"
	return _humanize(event_type)


func _resolve_event_icon_path(event: Dictionary) -> String:
	var event_type := _string_value(event.get("event_type", ""))
	if event_type in ["education_started", "major_selected", "education_graduated"]:
		var school_id = event.get("school_id", null)
		var manager := _get_manager("EducationManager")
		if manager != null and school_id != null:
			var value = manager.call("get_school_by_id", int(school_id))
			if typeof(value) == TYPE_DICTIONARY:
				var path := String((value as Dictionary).get("icon_path", ""))
				if ResourceLoader.exists(path):
					return path
	if event.has("job_id") or event.has("company_id"):
		return ICON_FOLDER + "job-status.svg"
	if event_type in ["married", "marriage", "partnered"]:
		return ICON_FOLDER + "relationship-status.svg"
	return ""


func _resolve_school_name(school_id: Variant) -> String:
	if school_id == null:
		return ""
	var manager := _get_manager("EducationManager")
	if manager == null:
		return ""
	var value = manager.call("get_school_by_id", int(school_id))
	return String((value as Dictionary).get("school_name", "")) if typeof(value) == TYPE_DICTIONARY else ""


func _resolve_major_name(major_id: Variant) -> String:
	if major_id == null:
		return ""
	var manager := _get_manager("CharacterManager")
	if manager == null:
		return ""
	var value = manager.get("majors")
	if typeof(value) != TYPE_ARRAY:
		return ""
	return String(_find_dictionary_by_int_id(value, "major_id", int(major_id)).get("major_name", ""))


func _get_character_display_name(character: Dictionary) -> String:
	var first_name := _string_value(character.get("first_name", "")).strip_edges()
	return first_name if not first_name.is_empty() else "Unnamed"


func _get_character_age(character: Dictionary) -> int:
	var manager := _get_manager("CharacterManager")
	if manager != null and manager.has_method("get_character_age"):
		return int(manager.call("get_character_age", character))
	var parts := _string_value(character.get("birth_date", "")).split("-")
	if parts.size() != 3:
		return 0
	var current := Time.get_date_dict_from_system()
	var age := int(current["year"]) - int(parts[0])
	if int(current["month"]) < int(parts[1]) or (int(current["month"]) == int(parts[1]) and int(current["day"]) < int(parts[2])):
		age -= 1
	return maxi(age, 0)


func _resolve_company_logo_path(path: String) -> String:
	if ResourceLoader.exists(path):
		return path
	if ResourceLoader.exists(default_company_logo_path):
		return default_company_logo_path
	return DEFAULT_COMPANY_LOGO_PATH


func _find_dictionary_by_int_id(entries: Array, key: String, target_id: int) -> Dictionary:
	for value in entries:
		if typeof(value) == TYPE_DICTIONARY and int((value as Dictionary).get(key, -1)) == target_id:
			return value
	return {}


func _format_monthly_amount(amount: int) -> String:
	var absolute := absi(amount)
	var text := str(absolute)
	if absolute >= 1000 and absolute % 1000 == 0:
		text = "%dk" % (absolute / 1000)
	elif absolute >= 1000:
		text = "%.1fk" % (float(absolute) / 1000.0)
	if amount < 0:
		text = "-" + text
	return text + " /month"


func _format_date(date_text: String) -> String:
	var parts := date_text.split("-")
	if parts.size() != 3:
		return date_text if not date_text.is_empty() else "—"
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var month := int(parts[1]) - 1
	return "%d %s %d" % [int(parts[2]), months[month], int(parts[0])] if month >= 0 and month < months.size() else date_text


func _extract_year(date_text: String) -> String:
	var parts := date_text.split("-")
	return parts[0] if parts.size() > 0 and parts[0].length() == 4 else ""


func _humanize(value: String) -> String:
	var normalized := value.strip_edges().replace("_", " ")
	return normalized.capitalize() if not normalized.is_empty() else "—"


func _string_value(value: Variant, fallback: String = "") -> String:
	return fallback if value == null else String(value)


func _get_manager(manager_name: String) -> Node:
	return get_node_or_null("/root/" + manager_name)


func _load_texture(path: String) -> Texture2D:
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _load_font(path: String) -> FontFile:
	return load(path) as FontFile if ResourceLoader.exists(path) else null


func _make_texture_rect(path: String, minimum_size: Vector2) -> TextureRect:
	var texture := TextureRect.new()
	texture.custom_minimum_size = minimum_size
	texture.texture = _load_texture(path)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture


func _make_label(text_value: String, size: int, color: Color, weight: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	var path := FONT_REGULAR_PATH
	if weight == "bold":
		path = FONT_BOLD_PATH
	elif weight == "extra_bold":
		path = FONT_EXTRA_BOLD_PATH
	label.add_theme_font_override("font", _load_font(path))
	return label


func _make_card(card_name: String, height: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = card_name
	card.custom_minimum_size = Vector2(0.0, height)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_style(COLOR_CARD, 28, COLOR_BORDER, 2))
	return card


func _make_margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	_set_margins(margin, left, top, right, bottom)
	return margin


func _set_margins(margin: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)


func _make_vertical_separator() -> VSeparator:
	var separator := VSeparator.new()
	separator.custom_minimum_size = Vector2(2.0, 0.0)
	var style := StyleBoxLine.new()
	style.color = COLOR_BORDER
	style.thickness = 2
	style.vertical = true
	separator.add_theme_stylebox_override("separator", style)
	return separator


func _make_style(background: Color, radius: int, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.anti_aliasing = true
	return style
