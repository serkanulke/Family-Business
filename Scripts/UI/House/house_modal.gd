extends Control
class_name HouseModal


signal closed

const ASSIGNMENT_SHEET := preload("res://Scenes/UI/House/HouseAssignmentSheet.tscn")
const INFO_MODAL := preload("res://Scenes/UI/House/HouseInfoModal.tscn")
const FONT_REGULAR := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_MEDIUM := "res://Resources/Fonts/Roboto-Medium.ttf"
const FONT_SEMIBOLD := "res://Resources/Fonts/Roboto-SemiBold.ttf"
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"
const HOUSE_IMAGE := "res://Resources/Buildings/Houses/house_modal.png"
const INFO_ICON := "res://Resources/Icons/info_icon.svg"
const EMPTY_SLOT_ICON := "res://Resources/Icons/empty-slot.svg"
const COIN_ICON := "res://Resources/Icons/main-ui/coin.png"
const ARROW_ICON := "res://Resources/Icons/arrow-right.svg"
const BUILDING_ICON := "res://Resources/Icons/building_icon.svg"
const COLOR_TEXT := Color("#1E1E1E")
const COLOR_BROWN := Color("#6D4534")
const COLOR_GREEN := Color("#07884F")
const COLOR_ASSIGN := Color("#63A479")
const COLOR_RED := Color("#E8403E")
const COLOR_MODAL := Color("#FCEFDE")
const COLOR_SOFT := Color("#FDF5EA")
const COLOR_CARD := Color("#FFF8F5")
const COLOR_SUMMARY := Color("#FEF1E9")
const COLOR_BORDER := Color("#F4E2D8")
const COLOR_TIER := Color("#FFA126")

var house_instance_id: String = ""
var title_label: Label
var level_label: Label
var capacity_label: Label
var status_icon: TextureRect
var status_label: Label
var expense_label: Label
var perks_container: HFlowContainer
var household_list: VBoxContainer
var upgrade_card: PanelContainer
var next_level_label: Label
var capacity_gain_label: Label
var expense_gain_label: Label
var upgrade_button: Button
var upgrade_amount_label: Label
var upgrade_button_label: Label
var upgrade_coin_icon: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_connect_signals()
	visible = false


func open_for_house(new_house_instance_id: String) -> bool:
	if HouseManager.get_house_by_instance_id(new_house_instance_id).is_empty():
		return false
	house_instance_id = new_house_instance_id
	visible = true
	refresh_from_manager()
	return true


func close_modal() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func refresh_from_manager() -> void:
	if not is_node_ready():
		return
	var house := HouseManager.get_house_by_instance_id(house_instance_id)
	if house.is_empty():
		close_modal()
		return
	var definition := HouseManager.get_house_definition(str(house.get("house_definition_id", "family_house")))
	var level := int(house.get("level", 1))
	var occupancy := HouseManager.get_house_occupancy(house_instance_id)
	var capacity := HouseManager.get_house_capacity(house_instance_id)
	title_label.text = str(definition.get("display_name", "HOUSE"))
	level_label.text = "Level %d" % level
	capacity_label.text = "Capacity %d / %d" % [occupancy, capacity]
	var status := HouseManager.get_household_status(house_instance_id)
	status_label.text = str(status.get("display_name", "Neutral"))
	status_label.add_theme_color_override("font_color", Color(str(status.get("color", "#858C98"))))
	_set_texture(status_icon, str(status.get("icon_path", "")))
	expense_label.text = "-%s" % _money(HouseManager.get_house_monthly_expense(house_instance_id))
	_refresh_perks()
	_refresh_household_list(house)
	_refresh_upgrade(house, definition)


func _connect_signals() -> void:
	if not HouseManager.house_state_changed.is_connected(_on_house_state_changed):
		HouseManager.house_state_changed.connect(_on_house_state_changed)
	if not HouseManager.house_upgraded.is_connected(_on_house_upgraded):
		HouseManager.house_upgraded.connect(_on_house_upgraded)
	if not SaveManager.load_completed.is_connected(_on_load_completed):
		SaveManager.load_completed.connect(_on_load_completed)


func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.07, 0.10, 0.09, 0.86)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var card := PanelContainer.new()
	card.name = "HouseCard"
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 40
	card.offset_top = 182
	card.offset_right = -40
	card.offset_bottom = -177
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", _rounded_style(COLOR_MODAL, COLOR_MODAL, 40, 0))
	add_child(card)
	card.add_child(_modal_gradient())

	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 41)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	content.add_child(_build_header())
	content.add_child(_build_summary())
	content.add_child(_build_section_header())

	var scroll := ScrollContainer.new()
	scroll.name = "HouseholdScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_top", 5)
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_margin)
	household_list = VBoxContainer.new()
	household_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	household_list.add_theme_constant_override("separation", 26)
	list_margin.add_child(household_list)

	var footer := VBoxContainer.new()
	footer.name = "UpgradeFooter"
	footer.add_theme_constant_override("separation", 25)
	footer.custom_minimum_size = Vector2(0, 206)
	content.add_child(footer)
	upgrade_card = _build_upgrade_card()
	footer.add_child(upgrade_card)
	upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton"
	upgrade_button.custom_minimum_size = Vector2(0, 86)
	upgrade_button.add_theme_stylebox_override("normal", _rounded_style(COLOR_SOFT, Color("#E7CEBD"), 22, 1))
	upgrade_button.add_theme_stylebox_override("hover", _rounded_style(Color("#FFF9F0"), Color("#E7CEBD"), 22, 1))
	upgrade_button.add_theme_stylebox_override("pressed", _rounded_style(Color("#F9EDDF"), Color("#DDBFAA"), 22, 1))
	upgrade_button.add_theme_stylebox_override("focus", _rounded_style(COLOR_SOFT, Color("#E7CEBD"), 22, 1))
	upgrade_button.add_theme_stylebox_override("disabled", _rounded_style(Color("#F4E9DC"), Color("#DFCFC2"), 22, 1))
	upgrade_button.text = ""
	upgrade_button.pressed.connect(_upgrade_house)
	var button_center := CenterContainer.new()
	button_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_button.add_child(button_center)
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	button_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button_center.add_child(button_row)
	upgrade_button_label = Label.new()
	upgrade_button_label.text = "UPGRADE BUILDING"
	_set_label(upgrade_button_label, FONT_SEMIBOLD, 32, COLOR_BROWN)
	button_row.add_child(upgrade_button_label)
	upgrade_coin_icon = TextureRect.new()
	upgrade_coin_icon.custom_minimum_size = Vector2(30, 30)
	upgrade_coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	upgrade_coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	upgrade_coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_texture(upgrade_coin_icon, COIN_ICON)
	button_row.add_child(upgrade_coin_icon)
	upgrade_amount_label = Label.new()
	_set_label(upgrade_amount_label, FONT_SEMIBOLD, 30, COLOR_BROWN)
	button_row.add_child(upgrade_amount_label)
	footer.add_child(upgrade_button)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 136)
	header.add_theme_constant_override("separation", 24)
	var image_holder := MarginContainer.new()
	image_holder.custom_minimum_size = Vector2(210, 132)
	image_holder.add_theme_constant_override("margin_top", 10)
	image_holder.add_theme_constant_override("margin_right", 14)
	header.add_child(image_holder)
	var image := TextureRect.new()
	image.name = "HouseIllustration"
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_texture(image, HOUSE_IMAGE)
	image_holder.add_child(image)
	var info_margin := MarginContainer.new()
	info_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_margin.add_theme_constant_override("margin_top", 12)
	header.add_child(info_margin)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 7)
	info_margin.add_child(info)
	title_label = Label.new()
	_set_label(title_label, FONT_BOLD, 40, COLOR_TEXT)
	info.add_child(title_label)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 16)
	info.add_child(detail_row)
	level_label = Label.new()
	_set_label(level_label, FONT_REGULAR, 28, COLOR_TEXT)
	detail_row.add_child(level_label)
	var info_button := Button.new()
	info_button.name = "InfoButton"
	info_button.flat = true
	info_button.custom_minimum_size = Vector2(32, 32)
	if ResourceLoader.exists(INFO_ICON):
		info_button.icon = load(INFO_ICON)
	info_button.pressed.connect(_open_info_modal)
	detail_row.add_child(info_button)
	capacity_label = Label.new()
	_set_label(capacity_label, FONT_REGULAR, 28, COLOR_TEXT)
	detail_row.add_child(capacity_label)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "×"
	close.custom_minimum_size = Vector2(46, 46)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.add_theme_font_override("font", load(FONT_REGULAR))
	close.add_theme_font_size_override("font_size", 36)
	close.add_theme_color_override("font_color", COLOR_TEXT)
	close.add_theme_color_override("font_hover_color", COLOR_TEXT)
	close.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	var close_style := _rounded_style(Color.WHITE, Color.WHITE, 23, 0)
	for state in ["normal", "hover", "pressed", "focus"]:
		close.add_theme_stylebox_override(state, close_style)
	close.pressed.connect(close_modal)
	header.add_child(close)
	return header


func _build_summary() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Summary"
	panel.custom_minimum_size = Vector2(0, 119)
	panel.add_theme_stylebox_override("panel", _rounded_style(COLOR_SUMMARY, COLOR_BORDER, 22, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 39)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 39)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var columns := HBoxContainer.new()
	margin.add_child(columns)
	var status_column := _summary_column("HOUSEHOLD STATUS")
	status_column.custom_minimum_size = Vector2(258, 0)
	status_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	columns.add_child(status_column)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	status_column.add_child(status_row)
	status_icon = TextureRect.new()
	status_icon.custom_minimum_size = Vector2(26, 26)
	status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_row.add_child(status_icon)
	status_label = Label.new()
	_set_label(status_label, FONT_SEMIBOLD, 28, COLOR_GREEN)
	status_row.add_child(status_label)
	columns.add_child(_summary_vertical_line(21))
	var expense_column := _summary_column("MONTHLY EXPENSE")
	expense_column.custom_minimum_size = Vector2(273, 0)
	expense_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	columns.add_child(expense_column)
	expense_label = Label.new()
	_set_label(expense_label, FONT_MEDIUM, 28, COLOR_RED)
	expense_column.add_child(expense_label)
	columns.add_child(_summary_vertical_line(20))
	var perk_column := _summary_column("HOUSE PERKS")
	columns.add_child(perk_column)
	perks_container = HFlowContainer.new()
	perks_container.add_theme_constant_override("h_separation", 8)
	perks_container.add_theme_constant_override("v_separation", 6)
	perk_column.add_child(perks_container)
	return panel


func _summary_column(heading: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 15)
	var label := Label.new()
	label.text = heading
	_set_label(label, FONT_SEMIBOLD, 21, COLOR_TEXT)
	var heading_margin := MarginContainer.new()
	heading_margin.add_theme_constant_override("margin_top", 5)
	heading_margin.add_child(label)
	box.add_child(heading_margin)
	return box


func _build_section_header() -> Control:
	var outer := MarginContainer.new()
	outer.custom_minimum_size = Vector2(0, 40)
	outer.add_theme_constant_override("margin_top", 6)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = "HOUSEHOLD"
	_set_label(label, FONT_SEMIBOLD, 24, COLOR_BROWN)
	row.add_child(label)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.color = COLOR_BROWN
	line.modulate.a = 0.65
	row.add_child(line)
	outer.add_child(row)
	return outer


func _build_upgrade_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "NextUpgradeCard"
	panel.custom_minimum_size = Vector2(0, 94)
	panel.add_theme_stylebox_override("panel", _rounded_style(COLOR_SOFT, COLOR_BORDER, 22, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 23)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	var building_icon := TextureRect.new()
	building_icon.name = "BuildingIcon"
	building_icon.custom_minimum_size = Vector2(66, 66)
	building_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	building_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_texture(building_icon, BUILDING_ICON)
	row.add_child(building_icon)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(336, 0)
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(left)
	var heading := Label.new()
	heading.text = "NEXT UPGRADE"
	_set_label(heading, FONT_SEMIBOLD, 24, COLOR_TEXT)
	left.add_child(heading)
	next_level_label = Label.new()
	_set_label(next_level_label, FONT_REGULAR, 25, COLOR_TEXT)
	left.add_child(next_level_label)
	row.add_child(_upgrade_vertical_line())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	capacity_gain_label = Label.new()
	_set_label(capacity_gain_label, FONT_REGULAR, 23, COLOR_TEXT)
	right.add_child(capacity_gain_label)
	expense_gain_label = Label.new()
	_set_label(expense_gain_label, FONT_REGULAR, 23, COLOR_RED)
	right.add_child(expense_gain_label)
	return panel


func _refresh_perks() -> void:
	for child in perks_container.get_children():
		child.queue_free()
	var perks := HouseManager.get_active_household_perks(house_instance_id)
	if perks.is_empty():
		return
	for value in perks:
		if not value is Dictionary:
			continue
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", _pill_style(Color("#F8E9DD"), Color("#EAD4C5"), 15, 1, 10, 4))
		var label := Label.new()
		label.text = str(value.get("display_name", "Perk"))
		_set_label(label, FONT_MEDIUM, 21, COLOR_BROWN)
		pill.add_child(label)
		perks_container.add_child(pill)


func _refresh_household_list(house: Dictionary) -> void:
	for child in household_list.get_children():
		child.queue_free()
	for value in HouseManager.get_role_definitions(str(house.get("house_definition_id", "family_house"))):
		if value is Dictionary:
			household_list.add_child(_role_card(value))
	var residents_value = house.get("resident_character_ids", [])
	if residents_value is Array:
		for character_id_value in residents_value:
			household_list.add_child(_resident_card(int(character_id_value)))
	if HouseManager.get_house_occupancy(house_instance_id) < HouseManager.get_house_capacity(house_instance_id):
		household_list.add_child(_empty_resident_card())


func _role_card(role: Dictionary) -> Control:
	var role_id := str(role.get("role_id", ""))
	var character_id := HouseManager.get_role_character_id(house_instance_id, role_id)
	var panel := PanelContainer.new()
	panel.name = "RoleCard_%s" % role_id
	panel.custom_minimum_size = Vector2(0, 162)
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _rounded_style(COLOR_CARD, COLOR_BORDER, 22, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	panel.add_child(row)
	var details_margin := MarginContainer.new()
	details_margin.custom_minimum_size = Vector2(289, 0)
	details_margin.add_theme_constant_override("margin_left", 23)
	details_margin.add_theme_constant_override("margin_top", 22)
	details_margin.add_theme_constant_override("margin_right", 12)
	details_margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(details_margin)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 15)
	details_margin.add_child(details)
	var role_name := Label.new()
	role_name.text = str(role.get("display_name", role_id))
	_set_label(role_name, FONT_SEMIBOLD, 26, COLOR_TEXT)
	details.add_child(role_name)
	var requires := Label.new()
	requires.text = "REQUIRES"
	_set_label(requires, FONT_SEMIBOLD, 18, COLOR_BROWN)
	details.add_child(requires)
	details.add_child(_role_stat_pills(role))
	row.add_child(_role_vertical_line())
	var occupant := HBoxContainer.new()
	occupant.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	occupant.add_theme_constant_override("separation", 0)
	row.add_child(occupant)
	if character_id > 0:
		_add_character_summary(occupant, character_id, role_id)
	else:
		_add_empty_summary(occupant, "Empty Position")
	var action := _action_button("Replace" if character_id > 0 else "Assign", character_id <= 0)
	action.pressed.connect(_open_role_sheet.bind(role_id))
	row.add_child(action)
	return panel


func _resident_card(character_id: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 160)
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _rounded_style(COLOR_CARD, COLOR_BORDER, 22, 1))
	var row := HBoxContainer.new()
	panel.add_child(row)
	var occupant := HBoxContainer.new()
	occupant.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	occupant.add_theme_constant_override("separation", 18)
	row.add_child(occupant)
	_add_character_summary(occupant, character_id, "")
	var remove := _action_button("Remove", false)
	remove.pressed.connect(_remove_resident.bind(character_id))
	row.add_child(remove)
	return panel


func _empty_resident_card() -> Control:
	var panel := PanelContainer.new()
	panel.name = "EmptyResidentCard"
	panel.custom_minimum_size = Vector2(0, 160)
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _rounded_style(COLOR_CARD, COLOR_BORDER, 22, 1))
	var row := HBoxContainer.new()
	panel.add_child(row)
	var summary := HBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(summary)
	_add_empty_summary(summary, "Empty Resident Slot")
	var assign := _action_button("Assign", true)
	assign.pressed.connect(_open_resident_sheet)
	row.add_child(assign)
	return panel


func _add_character_summary(parent: HBoxContainer, character_id: int, role_id: String) -> void:
	var character := CharacterManager.get_character_by_id(character_id)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 23)
	margin.add_theme_constant_override("margin_bottom", 22)
	parent.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(116, 116)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_texture(portrait, CharacterManager.get_avatar_path(character))
	row.add_child(portrait)
	var details := VBoxContainer.new()
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 6)
	row.add_child(details)
	var name_label := Label.new()
	name_label.text = str(character.get("first_name", "Family Member"))
	_set_label(name_label, FONT_SEMIBOLD, 27, COLOR_TEXT)
	details.add_child(name_label)
	if role_id.is_empty():
		var subtitle := Label.new()
		subtitle.text = str(character.get("life_stage", "")).replace("_", " ").capitalize()
		_set_label(subtitle, FONT_REGULAR, 21, COLOR_BROWN)
		details.add_child(subtitle)
	else:
		details.add_child(_role_tier_row(HouseManager.get_role_performance_tier(character_id, role_id)))


func _add_empty_summary(parent: HBoxContainer, text_value: String) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	parent.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(116, 116)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_texture(icon, EMPTY_SLOT_ICON)
	row.add_child(icon)
	var label := Label.new()
	label.text = text_value
	_set_label(label, FONT_SEMIBOLD, 26, COLOR_TEXT)
	row.add_child(label)


func _refresh_upgrade(house: Dictionary, definition: Dictionary) -> void:
	var level := int(house.get("level", 1))
	var max_level := int(definition.get("max_level", 5))
	if level >= max_level:
		upgrade_card.visible = false
		upgrade_button.disabled = true
		upgrade_button_label.text = "MAXIMUM HOUSE LEVEL"
		upgrade_amount_label.text = ""
		_apply_upgrade_button_state()
		return
	upgrade_card.visible = true
	var current := HouseManager.get_level_definition(level)
	var next := HouseManager.get_level_definition(level + 1)
	var cost := int(next.get("upgrade_price", 0))
	next_level_label.text = "Level %d" % (level + 1)
	capacity_gain_label.text = "+%d New Slots" % (int(next.get("capacity", 0)) - int(current.get("capacity", 0)))
	expense_gain_label.text = "+%s Expense" % _money(int(next.get("fixed_monthly_expense", 0)) - int(current.get("fixed_monthly_expense", 0)))
	upgrade_button.disabled = not GameManager.can_afford(cost)
	upgrade_button_label.text = "UPGRADE BUILDING"
	upgrade_amount_label.text = _money(cost)
	_apply_upgrade_button_state()


func _apply_upgrade_button_state() -> void:
	var content_color := Color("#E3CDB5") if upgrade_button.disabled else COLOR_BROWN
	upgrade_button_label.add_theme_color_override("font_color", content_color)
	upgrade_amount_label.add_theme_color_override("font_color", content_color)
	upgrade_coin_icon.modulate = Color(1, 1, 1, 0.42) if upgrade_button.disabled else Color.WHITE


func _open_role_sheet(role_id: String) -> void:
	var sheet := ASSIGNMENT_SHEET.instantiate() as HouseAssignmentSheet
	sheet.setup_role(house_instance_id, role_id)
	sheet.assignment_applied.connect(refresh_from_manager)
	add_child(sheet)


func _open_resident_sheet() -> void:
	var sheet := ASSIGNMENT_SHEET.instantiate() as HouseAssignmentSheet
	sheet.setup_resident(house_instance_id)
	sheet.assignment_applied.connect(refresh_from_manager)
	add_child(sheet)


func _open_info_modal() -> void:
	var info := INFO_MODAL.instantiate() as HouseInfoModal
	add_child(info)


func _remove_resident(character_id: int) -> void:
	HouseManager.remove_character_from_house(character_id)


func _upgrade_house() -> void:
	HouseManager.upgrade_house(house_instance_id)


func _on_house_state_changed(changed_house_instance_id: String, _reason: String) -> void:
	if visible and changed_house_instance_id == house_instance_id:
		refresh_from_manager()


func _on_house_upgraded(changed_house_instance_id: String, _new_level: int, _cost: int) -> void:
	if visible and changed_house_instance_id == house_instance_id:
		refresh_from_manager()


func _on_load_completed(_save_id: int) -> void:
	if visible:
		refresh_from_manager()


func _role_stat_pills(role: Dictionary) -> Control:
	var flow := HBoxContainer.new()
	flow.add_theme_constant_override("separation", 10)
	var value = role.get("required_stats", [])
	if value is Array:
		var visible_count := mini(value.size(), 2)
		for index in range(visible_count):
			var pill := PanelContainer.new()
			pill.add_theme_stylebox_override("panel", _pill_style(Color("#FCF4EC"), Color("#EAD9CC"), 15, 1, 9, 5))
			var label := Label.new()
			label.text = str(value[index]).capitalize()
			_set_label(label, FONT_MEDIUM, 16, COLOR_BROWN)
			pill.add_child(label)
			flow.add_child(pill)
		if value.size() > visible_count:
			var more := PanelContainer.new()
			more.add_theme_stylebox_override("panel", _pill_style(Color("#FCF4EC"), Color("#EAD9CC"), 15, 1, 9, 5))
			var more_label := Label.new()
			more_label.text = "+%d" % (value.size() - visible_count)
			_set_label(more_label, FONT_MEDIUM, 16, COLOR_BROWN)
			more.add_child(more_label)
			flow.add_child(more)
	return flow


func _role_tier_row(tier: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(24, 24)
	badge.add_theme_stylebox_override("panel", _rounded_style(COLOR_TIER, COLOR_TIER, 12, 0))
	var tier_label := Label.new()
	tier_label.text = tier
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_set_label(tier_label, FONT_SEMIBOLD, 16, Color.WHITE)
	badge.add_child(tier_label)
	row.add_child(badge)
	var family_label := Label.new()
	family_label.text = "Family Member"
	_set_label(family_label, FONT_REGULAR, 21, COLOR_TEXT)
	row.add_child(family_label)
	return row


func _action_button(label_text: String, enabled_style: bool) -> Button:
	var action := Button.new()
	action.name = "%sAction" % label_text.replace(" ", "")
	action.custom_minimum_size = Vector2(120, 0)
	action.text = ""
	var fill := COLOR_ASSIGN if enabled_style else COLOR_SOFT
	var style := _right_segment_style(fill, COLOR_BORDER, 22, 0 if enabled_style else 1)
	for state in ["normal", "hover", "pressed", "focus"]:
		action.add_theme_stylebox_override(state, style)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	var arrow := TextureRect.new()
	arrow.custom_minimum_size = Vector2(24, 24)
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.modulate = Color.WHITE if enabled_style else COLOR_BROWN
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_texture(arrow, ARROW_ICON)
	column.add_child(arrow)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label(label, FONT_SEMIBOLD, 23, Color.WHITE if enabled_style else COLOR_BROWN)
	column.add_child(label)
	return action


func _vertical_line() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(2, 0)
	line.color = COLOR_BORDER
	margin.add_child(line)
	return margin


func _summary_vertical_line(right_margin: int) -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", right_margin)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(1, 0)
	line.color = COLOR_BORDER
	margin.add_child(line)
	return margin


func _role_vertical_line() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 23)
	margin.add_theme_constant_override("margin_bottom", 23)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(1, 0)
	line.color = COLOR_BORDER
	margin.add_child(line)
	return margin


func _upgrade_vertical_line() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(1, 0)
	line.color = COLOR_BORDER
	margin.add_child(line)
	return margin


func _modal_gradient() -> Control:
	var background := ColorRect.new()
	background.name = "ModalGradient"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 rect_size = vec2(1000.0, 1561.0);
uniform float radius = 40.0;
float rounded_sdf(vec2 p, vec2 size, float r) {
	vec2 q = abs(p - size * 0.5) - (size * 0.5 - vec2(r));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}
void fragment() {
	vec2 pixel = UV * rect_size;
	if (rounded_sdf(pixel, rect_size, radius) > 0.0) { discard; }
	float t = clamp(UV.y / 0.13, 0.0, 1.0);
	vec3 c0 = vec3(0.863, 0.937, 0.965);
	vec3 c2 = vec3(0.988, 0.937, 0.871);
	vec3 color = mix(c0, c2, t);
	COLOR = vec4(color, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	background.material = material
	return background


func _rounded_style(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _right_segment_style(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	return style


func _pill_style(bg: Color, border: Color, radius: int, border_width: int, horizontal_padding: int, vertical_padding: int) -> StyleBoxFlat:
	var style := _rounded_style(bg, border, radius, border_width)
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = vertical_padding
	style.content_margin_bottom = vertical_padding
	return style


func _set_texture(target: TextureRect, path: String) -> void:
	target.texture = null
	if not path.is_empty() and ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			target.texture = resource


func _set_label(label: Label, font_path: String, size: int, color: Color) -> void:
	if ResourceLoader.exists(font_path):
		label.add_theme_font_override("font", load(font_path))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


func _money(value: int) -> String:
	var raw := str(absi(value))
	var result := ""
	while raw.length() > 3:
		result = "," + raw.right(3) + result
		raw = raw.left(raw.length() - 3)
	return raw + result
