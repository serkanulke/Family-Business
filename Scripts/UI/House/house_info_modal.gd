extends Control
class_name HouseInfoModal


signal closed

const FONT_REGULAR := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_SEMIBOLD := "res://Resources/Fonts/Roboto-SemiBold.ttf"
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"
const HEADER_BACKGROUND := "res://Resources/Icons/business-modal-header-bg.svg"
const COLOR_TEXT := Color("#1E1E1E")
const COLOR_BROWN := Color("#6D4534")
const COLOR_MUTED := Color("#4A4642")
const COLOR_PANEL := Color("#FCEFDE")
const COLOR_SOFT := Color("#FFF9F5")
const COLOR_BORDER := Color("#F3DFD3")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func _build_ui() -> void:
	var blocker := ColorRect.new()
	blocker.name = "Dimmer"
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.color = Color(0.03, 0.05, 0.05, 0.78)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.name = "InfoCard"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-430, -590)
	panel.size = Vector2(860, 1180)
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _rounded_style(COLOR_PANEL, COLOR_PANEL, 38, 0))
	add_child(panel)

	var gradient_layer := Control.new()
	gradient_layer.name = "HeaderBackgroundLayer"
	gradient_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(gradient_layer)
	var gradient := NinePatchRect.new()
	gradient.name = "HeaderBackground"
	gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gradient.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gradient.offset_bottom = 174
	gradient.patch_margin_left = 38
	gradient.patch_margin_top = 38
	gradient.patch_margin_right = 38
	_set_texture(gradient, HEADER_BACKGROUND)
	gradient_layer.add_child(gradient)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 22)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 92)
	header.add_theme_constant_override("separation", 18)
	content.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 5)
	header.add_child(title_box)
	var title := Label.new()
	title.text = "HOUSE SYSTEM"
	_set_label(title, FONT_BOLD, 38, COLOR_TEXT)
	title_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "How your household, roles, and home capacity work"
	_set_label(subtitle, FONT_REGULAR, 21, COLOR_MUTED)
	title_box.add_child(subtitle)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(52, 52)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 30)
	close_button.add_theme_color_override("font_color", COLOR_TEXT)
	var close_style := _rounded_style(Color(1, 1, 1, 0.94), Color(1, 1, 1, 0.94), 30, 0)
	for state in ["normal", "hover", "pressed", "focus"]:
		close_button.add_theme_stylebox_override(state, close_style)
	close_button.pressed.connect(_close)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.name = "ExplanationScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list_margin := MarginContainer.new()
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_margin.add_theme_constant_override("margin_right", 8)
	scroll.add_child(list_margin)
	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 16)
	list_margin.add_child(sections)

	_add_section(sections, "CAPACITY", "House capacity is shared by household roles and residents. Each family member occupies one slot.")
	_add_section(sections, "HOUSEHOLD ROLES", "Adult family members can take household roles. Their relevant stats determine how well they perform that role. As the household grows, good role performance becomes more important.")
	_add_section(sections, "ROLE PERFORMANCE", "Each role uses its own relevant stats, so the same family member may perform differently in different roles.")
	_add_section(sections, "HOUSEHOLD STATUS", "Your household's overall organization is reflected by its status, from Chaotic to Orderly. Household Status can affect which household and lifestyle events become available.")
	_add_section(sections, "HOUSEHOLD PERKS", "The Head of Household's traits can give the household special perks. Perks can unlock unique household and lifestyle events.")
	_add_section(sections, "UNHOUSED FAMILY MEMBERS", "Family members who are not assigned to any home lose Happiness over time.")


func _add_section(parent: VBoxContainer, heading: String, body: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _rounded_style(COLOR_SOFT, COLOR_BORDER, 22, 2))
	parent.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 19)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)
	var heading_label := Label.new()
	heading_label.text = heading
	_set_label(heading_label, FONT_SEMIBOLD, 23, COLOR_BROWN)
	box.add_child(heading_label)
	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_label(body_label, FONT_REGULAR, 22, COLOR_TEXT)
	box.add_child(body_label)


func _rounded_style(
	fill: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _set_label(label: Label, font_path: String, size: int, color: Color) -> void:
	if ResourceLoader.exists(font_path):
		label.add_theme_font_override("font", load(font_path))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


func _set_texture(target: Control, path: String) -> void:
	if ResourceLoader.exists(path):
		target.set("texture", load(path))


func _close() -> void:
	closed.emit()
	queue_free()
