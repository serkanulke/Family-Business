extends Control
class_name BusinessModal

## UI-only adapter for the Business Manager layer.
## This scene does not mutate business data directly.
## It emits signals so the existing manager/controller can remain the source of truth.

signal closed
signal assign_requested(business_instance_id: String, slot_index: int)
signal replace_requested(business_instance_id: String, slot_index: int)
signal upgrade_requested(business_instance_id: String)

const COLOR_TEXT := Color("#1E1E1E")
const COLOR_BROWN := Color("#6D4534")
const COLOR_GREEN := Color("#047D48")
const COLOR_RED := Color("#E8403E")
const COLOR_SOFT := Color("#FDF1EA")
const COLOR_BORDER := Color("#F4E2D8")
const COLOR_STAFF := Color("#FFF9F4")
const COLOR_ASSIGN := Color("#63A579")

const PATH_BUILDING_IMAGE := "res://Resources/Buildings/Hospital/Hospital.png"
const PATH_BUSINESS_ICON := "res://Resources/Icons/hospital-sign.png"
const PATH_INCOME_TREND := "res://Resources/Icons/upper-chart.svg"
const PATH_EXPENSE_TREND := "res://Resources/Icons/down-chart.svg"
const PATH_EMPTY_SLOT := "res://Resources/Icons/empty-slot.svg"
const PATH_ARROW_RIGHT := "res://Resources/Icons/arrow-right.svg"
const PATH_UPGRADE_ICON := "res://Resources/Icons/building_icon.svg"

const FONT_REGULAR := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_MEDIUM := "res://Resources/Fonts/Roboto-Medium.ttf"
const FONT_SEMIBOLD := "res://Resources/Fonts/Roboto-SemiBold.ttf"
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"

@export var business_instance_id: String = ""

@onready var building_image: TextureRect = %BuildingImage
@onready var business_icon: TextureRect = %BusinessIcon
@onready var business_title: Label = %BusinessTitle
@onready var business_level: Label = %BusinessLevel
@onready var income_value: Label = %IncomeValue
@onready var expense_value: Label = %ExpenseValue
@onready var net_value: Label = %NetValue
@onready var income_trend: TextureRect = %IncomeTrend
@onready var expense_trend: TextureRect = %ExpenseTrend
@onready var staff_list: VBoxContainer = %StaffList
@onready var next_level: Label = %NextLevel
@onready var new_slot: Label = %NewSlot
@onready var potential_income: Label = %PotentialIncome
@onready var added_expense: Label = %AddedExpense
@onready var upgrade_button: Button = %UpgradeButton
@onready var close_button: Button = %CloseButton

var _business_data: Dictionary = {}


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	_apply_fonts()
	_load_default_assets()

	# Editor/standalone preview until real BusinessManager data is supplied.
	if _business_data.is_empty():
		configure_from_data(_preview_data())


## Preferred integration point:
## BusinessManager (or your screen controller) retrieves the business instance and
## passes its Dictionary here. This keeps this UI independent from save/data logic.
func configure_from_data(data: Dictionary) -> void:
	_business_data = data.duplicate(true)

	if data.has("id"):
		business_instance_id = str(data["id"])
	elif data.has("instance_id"):
		business_instance_id = str(data["instance_id"])

	business_title.text = str(_first(data, ["display_name", "name", "business_name"], "BUSINESS"))
	var level := int(_first(data, ["level"], 1))
	business_level.text = "Level %d" % level

	var monthly_income := float(_first(data, ["monthly_income", "revenue", "income"], 0.0))
	var monthly_expense := float(_first(data, ["monthly_expense", "upkeep", "expense"], 0.0))
	var net_profit := float(_first(data, ["net_profit", "profit"], monthly_income - monthly_expense))

	income_value.text = _money(monthly_income, true)
	expense_value.text = _money(-abs(monthly_expense), false)
	net_value.text = _money(net_profit, net_profit >= 0.0)
	net_value.add_theme_color_override("font_color", COLOR_GREEN if net_profit >= 0.0 else COLOR_RED)

	_set_texture_from_data(building_image, data, ["image_path", "building_image", "texture_path"])
	_set_texture_from_data(business_icon, data, ["icon_path", "business_icon"])

	_build_staff_rows(_as_array(_first(data, ["slots", "staff_slots"], [])))
	_apply_upgrade_data(_first(data, ["next_upgrade", "upgrade"], {}))


## Optional convenience method. Use only if BusinessManager is an Autoload in your project.
## Because the repository BusinessManager could not be read while this package was generated,
## this adapter supports common read APIs without hard-coding a mutation API.
func refresh_from_business_manager() -> bool:
	var manager := get_node_or_null("/root/BusinessManager")
	if manager == null:
		push_warning("BusinessManager Autoload not found. Pass data with configure_from_data().")
		return false

	var data: Variant = null

	if manager.has_method("get_business_instance"):
		data = manager.call("get_business_instance", business_instance_id)
	elif manager.has_method("get_business"):
		data = manager.call("get_business", business_instance_id)

	if data is Dictionary:
		configure_from_data(data)
		return true

	push_warning("BusinessManager found, but no compatible read method returned a Dictionary.")
	return false


func open_for_business(id: String, data: Dictionary = {}) -> void:
	business_instance_id = id
	visible = true
	if not data.is_empty():
		configure_from_data(data)
	else:
		refresh_from_business_manager()


func close_modal() -> void:
	visible = false
	closed.emit()


func _build_staff_rows(slots: Array) -> void:
	for child in staff_list.get_children():
		child.queue_free()

	if slots.is_empty():
		slots = _preview_data()["slots"]

	for i in slots.size():
		var slot: Dictionary = slots[i] if slots[i] is Dictionary else {}
		staff_list.add_child(_create_staff_row(slot, i))


func _create_staff_row(slot: Dictionary, slot_index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 170)
	panel.add_theme_stylebox_override("panel", _staff_style())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	panel.add_child(row)

	var job_margin := MarginContainer.new()
	job_margin.custom_minimum_size = Vector2(317, 0)
	job_margin.add_theme_constant_override("margin_left", 24)
	job_margin.add_theme_constant_override("margin_top", 22)
	job_margin.add_theme_constant_override("margin_right", 24)
	job_margin.add_theme_constant_override("margin_bottom", 22)
	row.add_child(job_margin)

	var job_box := VBoxContainer.new()
	job_box.add_theme_constant_override("separation", 12)
	job_margin.add_child(job_box)

	var role_label := Label.new()
	role_label.text = str(_first(slot, ["role_name", "name", "title", "slot_name"], "Position"))
	_set_label_font(role_label, FONT_SEMIBOLD, 28, COLOR_TEXT)
	job_box.add_child(role_label)

	var requires := Label.new()
	requires.text = "REQUIRES"
	_set_label_font(requires, FONT_SEMIBOLD, 16, COLOR_BROWN)
	job_box.add_child(requires)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	job_box.add_child(chips)

	var required_stats := _as_array(_first(slot, ["required_stats", "requirements"], []))
	if required_stats.is_empty():
		required_stats = ["Logic", "Health", "+1"]
	for stat in required_stats:
		chips.add_child(_create_chip(str(stat)))

	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 2
	sep.add_theme_color_override("separator", COLOR_BORDER)
	row.add_child(sep)

	var staff_margin := MarginContainer.new()
	staff_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staff_margin.add_theme_constant_override("margin_left", 24)
	staff_margin.add_theme_constant_override("margin_top", 20)
	staff_margin.add_theme_constant_override("margin_right", 24)
	staff_margin.add_theme_constant_override("margin_bottom", 20)
	row.add_child(staff_margin)

	var staff_row := HBoxContainer.new()
	staff_row.add_theme_constant_override("separation", 24)
	staff_margin.add_child(staff_row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	staff_row.add_child(portrait)

	var assigned_character_id := str(_first(slot, ["assigned_character_id"], ""))
	var assigned_npc_id := str(_first(slot, ["assigned_npc_id"], ""))
	var is_filled := not assigned_character_id.is_empty() or not assigned_npc_id.is_empty()
	var worker_name := str(_first(slot, ["worker_name", "staff_name", "assignee_name"], ""))

	if not is_filled:
		_try_set_texture(portrait, PATH_EMPTY_SLOT)
	elif slot.has("portrait_path"):
		_try_set_texture(portrait, str(slot["portrait_path"]))

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	staff_row.add_child(details)

	var staff_name := Label.new()
	staff_name.text = worker_name if not worker_name.is_empty() else ("Assigned" if is_filled else "Empty Position")
	_set_label_font(staff_name, FONT_SEMIBOLD, 28, COLOR_TEXT)
	details.add_child(staff_name)

	var performance_row := HBoxContainer.new()
	performance_row.add_theme_constant_override("separation", 8)
	details.add_child(performance_row)

	var performance := Label.new()
	var performance_value := str(_first(slot, ["performance_grade", "performance"], ""))
	performance.text = ("%s Performance" % performance_value) if not performance_value.is_empty() else ("Performance" if is_filled else "Potential Income")
	_set_label_font(performance, FONT_REGULAR, 16, COLOR_TEXT)
	performance_row.add_child(performance)

	var amount := Label.new()
	var slot_income := float(_first(slot, ["income", "revenue", "potential_income"], 0.0))
	amount.text = _money(slot_income, true)
	_set_label_font(amount, FONT_MEDIUM, 24, COLOR_GREEN)
	details.add_child(amount)

	var action := Button.new()
	action.custom_minimum_size = Vector2(121, 0)
	action.text = "Replace" if is_filled else "Assign"
	action.add_theme_font_size_override("font_size", 18)
	action.add_theme_color_override("font_color", COLOR_BROWN if is_filled else Color.WHITE)

	var button_style := _action_style(is_filled)
	action.add_theme_stylebox_override("normal", button_style)
	action.add_theme_stylebox_override("hover", button_style)
	action.add_theme_stylebox_override("pressed", button_style)

	if is_filled:
		action.pressed.connect(func(): replace_requested.emit(business_instance_id, slot_index))
	else:
		action.pressed.connect(func(): assign_requested.emit(business_instance_id, slot_index))

	row.add_child(action)
	return panel


func _apply_upgrade_data(value: Variant) -> void:
	if not value is Dictionary or value.is_empty():
		return

	var data: Dictionary = value
	var level := int(_first(data, ["level", "next_level"], 0))
	var name := str(_first(data, ["name", "display_name", "upgrade_name"], ""))
	next_level.text = "Level %d%s" % [level, (" (%s)" % name) if not name.is_empty() else ""]

	var slot_text := str(_first(data, ["new_slot_text", "new_slot", "slot_unlock"], ""))
	new_slot.text = slot_text if not slot_text.is_empty() else "+ New Slot"

	var potential := float(_first(data, ["potential_income", "income_increase", "revenue_increase"], 0.0))
	var expense := float(_first(data, ["monthly_expense", "expense_increase", "upkeep_increase"], 0.0))
	var cost := float(_first(data, ["cost", "upgrade_cost"], 0.0))

	potential_income.text = "%s Potential Income" % _money(potential, true)
	added_expense.text = "%s Monthly Expense" % _money(expense, true)
	upgrade_button.text = "UPGRADE BUILDING     %s" % _money(cost, false)


func _on_close_pressed() -> void:
	close_modal()


func _on_upgrade_pressed() -> void:
	upgrade_requested.emit(business_instance_id)


func _load_default_assets() -> void:
	_try_set_texture(building_image, PATH_BUILDING_IMAGE)
	_try_set_texture(business_icon, PATH_BUSINESS_ICON)
	_try_set_texture(income_trend, PATH_INCOME_TREND)
	_try_set_texture(expense_trend, PATH_EXPENSE_TREND)


func _apply_fonts() -> void:
	_set_label_font(business_title, FONT_BOLD, 40, COLOR_TEXT)
	_set_label_font(business_level, FONT_REGULAR, 28, COLOR_TEXT)
	_set_label_font(income_value, FONT_SEMIBOLD, 28, COLOR_GREEN)
	_set_label_font(expense_value, FONT_SEMIBOLD, 28, COLOR_RED)
	_set_label_font(net_value, FONT_SEMIBOLD, 28, COLOR_GREEN)
	_try_set_button_font(upgrade_button, FONT_SEMIBOLD)


func _set_label_font(label: Label, path: String, size: int, color: Color) -> void:
	if ResourceLoader.exists(path):
		var font := load(path)
		if font:
			label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


func _try_set_button_font(button: Button, path: String) -> void:
	if ResourceLoader.exists(path):
		var font := load(path)
		if font:
			button.add_theme_font_override("font", font)


func _create_chip(text_value: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SOFT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.corner_radius_top_left = 50
	style.corner_radius_top_right = 50
	style.corner_radius_bottom_left = 50
	style.corner_radius_bottom_right = 50
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text_value
	_set_label_font(label, FONT_SEMIBOLD, 16, COLOR_BROWN)
	panel.add_child(label)
	return panel


func _staff_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_STAFF
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	return style


func _action_style(is_replace: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SOFT if is_replace else COLOR_ASSIGN
	style.border_color = COLOR_BORDER if is_replace else COLOR_GREEN
	style.border_width_left = 2 if is_replace else 1
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_right = 24
	return style


func _try_set_texture(target: TextureRect, path: String) -> void:
	if ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			target.texture = resource


func _set_texture_from_data(target: TextureRect, data: Dictionary, keys: Array[String]) -> void:
	for key in keys:
		if data.has(key) and not str(data[key]).is_empty():
			_try_set_texture(target, str(data[key]))
			return


func _money(value: float, show_plus: bool) -> String:
	var amount := int(round(value))
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


func _first(data: Dictionary, keys: Array, fallback: Variant) -> Variant:
	for key in keys:
		if data.has(key):
			return data[key]
	return fallback


func _as_array(value: Variant) -> Array:
	return value if value is Array else []


func _preview_data() -> Dictionary:
	return {
		"id": "hospital_preview",
		"name": "HOSPITAL",
		"level": 3,
		"monthly_income": 420000,
		"monthly_expense": 180000,
		"net_profit": 240000,
		"slots": [
			{
				"role_name": "Chief Physician",
				"required_stats": ["Logic", "Health", "+1"],
				"assigned_character_id": "",
				"assigned_npc_id": "",
				"potential_income": 200000
			}
		],
		"next_upgrade": {
			"level": 4,
			"name": "Medical Complex",
			"new_slot_text": "+ New Surgeon Slot",
			"potential_income": 220000,
			"monthly_expense": 30000,
			"cost": 500000
		}
	}
