extends Control
class_name BuyHouseModal


signal closed
signal purchase_completed(house_instance_id: String, property_id: String)

const FONT_REGULAR := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_SEMIBOLD := "res://Resources/Fonts/Roboto-SemiBold.ttf"
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"
const HOUSE_IMAGE := "res://Resources/Buildings/Houses/house_modal.png"
const HEADER_BACKGROUND := "res://Resources/Icons/business-modal-header-bg.svg"
const CAPACITY_ICON := "res://Resources/Icons/employee_slots_icon.svg"
const COIN_ICON := "res://Resources/Icons/main-ui/coin.png"
const COLOR_TEXT := Color("#1E1E1E")
const COLOR_MUTED := Color("#4A4642")
const COLOR_BROWN := Color("#6D4534")
const COLOR_PANEL := Color("#FCEFDE")
const COLOR_SOFT := Color("#FFF5ED")
const COLOR_BORDER := Color("#F4DED3")
const COLOR_RED := Color("#E8403E")
const COLOR_GREEN := Color("#63A479")
const COLOR_DISABLED_TEXT := Color("#E3CDB5")

var property_id: String = ""
var acquisition_cost: int = 0
var buy_button: Button
var buy_button_label: Label
var buy_button_amount: Label
var buy_button_coin: TextureRect
var close_button: Button
var capacity_value: Label
var monthly_expense_value: Label
var capacity_detail: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	if not GameManager.family_money_changed.is_connected(_on_family_money_changed):
		GameManager.family_money_changed.connect(_on_family_money_changed)
	visible = false


func open_for_property(new_property_id: String) -> bool:
	if new_property_id.is_empty() or HouseManager.is_property_owned(new_property_id):
		return false
	property_id = new_property_id
	var level_one := HouseManager.get_level_definition(1)
	acquisition_cost = int(level_one.get("ready_made_purchase_price", 0))
	var capacity := int(level_one.get("capacity", 0))
	capacity_value.text = str(capacity)
	monthly_expense_value.text = "-%s" % _money(abs(int(level_one.get("fixed_monthly_expense", 0))))
	capacity_detail.text = "%d household slots available after purchase." % capacity
	buy_button_amount.text = _money(acquisition_cost)
	visible = true
	_refresh_purchase_state()
	return true


func close_modal() -> void:
	if visible:
		visible = false
		closed.emit()


func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.047, 0.067, 0.071, 0.79)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "ModalCard"
	panel.custom_minimum_size = Vector2(670, 0)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, 38))
	center.add_child(panel)

	var header_layer := Control.new()
	header_layer.name = "HeaderBackgroundLayer"
	header_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(header_layer)
	var header_background := NinePatchRect.new()
	header_background.name = "HeaderBackground"
	header_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_background.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_background.offset_bottom = 174
	header_background.patch_margin_left = 38
	header_background.patch_margin_top = 38
	header_background.patch_margin_right = 38
	_set_texture(header_background, HEADER_BACKGROUND)
	header_layer.add_child(header_background)

	var margin := MarginContainer.new()
	margin.name = "CardMargin"
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 27)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	content.add_child(_build_header())
	content.add_child(_build_summary())
	content.add_child(_build_capacity_panel())
	content.add_child(_build_buy_button())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 130)
	header.add_theme_constant_override("separation", 18)
	var image := TextureRect.new()
	image.name = "HouseImage"
	image.custom_minimum_size = Vector2(180, 120)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_texture(image, HOUSE_IMAGE)
	header.add_child(image)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 8)
	header.add_child(info)
	var title := Label.new()
	title.text = "HOUSE"
	_set_label(title, FONT_BOLD, 38, COLOR_TEXT)
	info.add_child(title)
	var level := Label.new()
	level.text = "Level 1"
	_set_label(level, FONT_REGULAR, 25, COLOR_TEXT)
	info.add_child(level)
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(48, 48)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 28)
	close_button.add_theme_color_override("font_color", COLOR_TEXT)
	var close_style := _style(Color(1, 1, 1, 0.94), 30)
	for state in ["normal", "hover", "pressed", "focus"]:
		close_button.add_theme_stylebox_override(state, close_style)
	close_button.pressed.connect(close_modal)
	header.add_child(close_button)
	return header


func _build_summary() -> Control:
	var panel := PanelContainer.new()
	panel.name = "HouseSummary"
	panel.custom_minimum_size = Vector2(0, 110)
	panel.add_theme_stylebox_override("panel", _bordered_style(COLOR_SOFT, COLOR_BORDER, 22))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	margin.add_child(columns)
	columns.add_child(_summary_column("CAPACITY", false))
	var separator := VSeparator.new()
	separator.add_theme_stylebox_override("separator", _separator_style())
	columns.add_child(separator)
	columns.add_child(_summary_column("MONTHLY EXPENSE", true))
	return panel


func _summary_column(heading: String, is_expense: bool) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label(title, FONT_SEMIBOLD, 20, COLOR_TEXT)
	column.add_child(title)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label(value, FONT_SEMIBOLD, 29, COLOR_RED if is_expense else COLOR_BROWN)
	column.add_child(value)
	if is_expense:
		monthly_expense_value = value
	else:
		capacity_value = value
	return column


func _build_capacity_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "CapacityPanel"
	panel.custom_minimum_size = Vector2(0, 96)
	panel.add_theme_stylebox_override("panel", _bordered_style(COLOR_SOFT, COLOR_BORDER, 22))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(57, 57)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_texture(icon, CAPACITY_ICON)
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 3)
	row.add_child(text)
	var label := Label.new()
	label.text = "HOUSEHOLD CAPACITY"
	_set_label(label, FONT_SEMIBOLD, 21, COLOR_TEXT)
	text.add_child(label)
	capacity_detail = Label.new()
	capacity_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_label(capacity_detail, FONT_REGULAR, 20, COLOR_MUTED)
	text.add_child(capacity_detail)
	return panel


func _build_buy_button() -> Control:
	buy_button = Button.new()
	buy_button.name = "BuyButton"
	buy_button.custom_minimum_size = Vector2(0, 82)
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.text = ""
	buy_button.add_theme_stylebox_override("normal", _style(COLOR_GREEN, 22))
	buy_button.add_theme_stylebox_override("hover", _style(COLOR_GREEN, 22))
	buy_button.add_theme_stylebox_override("pressed", _style(Color("#4F9166"), 22))
	buy_button.add_theme_stylebox_override("disabled", _bordered_style(Color("#FDF5EA"), Color("#E7CEBD"), 22))
	buy_button.pressed.connect(_purchase)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy_button.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	buy_button_label = Label.new()
	buy_button_label.text = "BUY HOUSE"
	_set_label(buy_button_label, FONT_BOLD, 29, Color.WHITE)
	row.add_child(buy_button_label)
	buy_button_coin = TextureRect.new()
	buy_button_coin.custom_minimum_size = Vector2(34, 34)
	buy_button_coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	buy_button_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_texture(buy_button_coin, COIN_ICON)
	row.add_child(buy_button_coin)
	buy_button_amount = Label.new()
	_set_label(buy_button_amount, FONT_BOLD, 29, Color.WHITE)
	row.add_child(buy_button_amount)
	return buy_button


func _refresh_purchase_state() -> void:
	if buy_button == null:
		return
	buy_button.disabled = acquisition_cost <= 0 or not GameManager.can_afford(acquisition_cost)
	var content_color := COLOR_DISABLED_TEXT if buy_button.disabled else Color.WHITE
	buy_button_label.add_theme_color_override("font_color", content_color)
	buy_button_amount.add_theme_color_override("font_color", content_color)
	buy_button_coin.modulate = Color(1, 1, 1, 0.42) if buy_button.disabled else Color.WHITE


func _purchase() -> void:
	if buy_button.disabled:
		return
	var house := HouseManager.purchase_ready_made_house(property_id)
	if house.is_empty():
		_refresh_purchase_state()
		return
	var new_instance_id := str(house.get("house_instance_id", ""))
	visible = false
	purchase_completed.emit(new_instance_id, property_id)


func _on_family_money_changed(_new_amount: int) -> void:
	if visible:
		_refresh_purchase_state()


func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style


func _bordered_style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := _style(color, radius)
	style.border_color = border
	style.set_border_width_all(2)
	return style


func _separator_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BORDER
	style.content_margin_left = 1.5
	style.content_margin_right = 1.5
	return style


func _set_label(label: Label, font_path: String, size: int, color: Color) -> void:
	if ResourceLoader.exists(font_path):
		label.add_theme_font_override("font", load(font_path))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


func _set_texture(target: Control, path: String) -> void:
	if ResourceLoader.exists(path):
		target.set("texture", load(path))


func _money(value: int) -> String:
	var raw := str(absi(value))
	var result := ""
	while raw.length() > 3:
		result = "," + raw.right(3) + result
		raw = raw.left(raw.length() - 3)
	return raw + result
