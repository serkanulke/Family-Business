extends Control
class_name BusinessModal

signal closed
signal assign_requested(business_instance_id: String, slot_index: int)
signal replace_requested(business_instance_id: String, slot_index: int)
signal upgrade_requested(business_instance_id: String)

const COLOR_TEXT := Color("#1E1E1E")
const COLOR_BROWN := Color("#6D4534")
const COLOR_GREEN := Color("#07884F")
const COLOR_RED := Color("#E8403E")
const COLOR_MODAL := Color("#FCEFDE")
const COLOR_SOFT := Color("#FDF5EA")
const COLOR_BORDER := Color("#F3DFD3")
const COLOR_STAFF := Color("#FEF9F5")
const COLOR_ASSIGN := Color("#63A479")
const COLOR_SELECTED := Color("#E2CBB5")

const PATH_BUILDING_IMAGE := "res://Resources/Buildings/Hospital/hospital.png"
const PATH_INCOME_TREND := "res://Resources/Icons/upper-chart.svg"
const PATH_EXPENSE_TREND := "res://Resources/Icons/down-chart.svg"
const PATH_EMPTY_SLOT := "res://Resources/Icons/empty-slot.svg"
const PATH_UPGRADE_ICON := "res://Resources/Icons/building_icon.svg"
const PATH_UPGRADE_COINS := "res://Resources/Icons/main-ui/coin.png"
const PATH_TIER_DIR := "res://Resources/Icons/performance-tier/"

const FONT_REGULAR := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_MEDIUM := "res://Resources/Fonts/Roboto-Medium.ttf"
const FONT_SEMIBOLD := "res://Resources/Fonts/Roboto-SemiBold.ttf"
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"

const BUSINESS_MODAL_DATA_ADAPTER := preload("res://Scripts/UI/Business/business_modal_data_adapter.gd")

@export var business_instance_id: String = ""

@onready var building_image: TextureRect = $ModalCard/OuterMargin/Content/BusinessHeader/BuildingImage
@onready var business_title: Label = $ModalCard/OuterMargin/Content/BusinessHeader/BusinessInfo/IconTitle/BusinessTitle
@onready var business_level: Label = $ModalCard/OuterMargin/Content/BusinessHeader/BusinessInfo/BusinessLevel

@onready var income_label: Label = $ModalCard/OuterMargin/Content/FinancialSummary/FinancialMargin/Columns/IncomeWrap/IncomeCard/IncomeLabel
@onready var income_value: Label = $ModalCard/OuterMargin/Content/FinancialSummary/FinancialMargin/Columns/IncomeWrap/IncomeCard/IncomeValueRow/IncomeValue
@onready var expense_label: Label = $ModalCard/OuterMargin/Content/FinancialSummary/FinancialMargin/Columns/ExpenseWrap/ExpenseCard/ExpenseLabel
@onready var expense_value: Label = $ModalCard/OuterMargin/Content/FinancialSummary/FinancialMargin/Columns/ExpenseWrap/ExpenseCard/ExpenseValueRow/ExpenseValue
@onready var net_label: Label = $ModalCard/OuterMargin/Content/FinancialSummary/FinancialMargin/Columns/NetWrap/NetCard/NetLabel
@onready var net_value: Label = $ModalCard/OuterMargin/Content/FinancialSummary/FinancialMargin/Columns/NetWrap/NetCard/NetValue
@onready var income_trend: TextureRect = $ModalCard/OuterMargin/Content/FinancialSummary/FinancialMargin/Columns/IncomeWrap/IncomeCard/IncomeValueRow/IncomeTrend
@onready var expense_trend: TextureRect = $ModalCard/OuterMargin/Content/FinancialSummary/FinancialMargin/Columns/ExpenseWrap/ExpenseCard/ExpenseValueRow/ExpenseTrend

@onready var section_label: Label = $ModalCard/OuterMargin/Content/SectionHeader/StaffPositionsLabel
@onready var staff_list: VBoxContainer = $ModalCard/OuterMargin/Content/StaffScroll/StaffList

@onready var upgrade_card: PanelContainer = $ModalCard/OuterMargin/Content/UpgradeCard
@onready var upgrade_icon: TextureRect = $ModalCard/OuterMargin/Content/UpgradeCard/UpgradeMargin/UpgradeRow/UpgradeBuildingInfo/UpgradeIcon
@onready var upgrade_label: Label = $ModalCard/OuterMargin/Content/UpgradeCard/UpgradeMargin/UpgradeRow/UpgradeBuildingInfo/UpgradeDetails/UpgradeLabel
@onready var next_level: Label = $ModalCard/OuterMargin/Content/UpgradeCard/UpgradeMargin/UpgradeRow/UpgradeBuildingInfo/UpgradeDetails/NextLevel
@onready var new_slot: Label = $ModalCard/OuterMargin/Content/UpgradeCard/UpgradeMargin/UpgradeRow/UpgradeInfo/NewSlot
@onready var potential_income: Label = $ModalCard/OuterMargin/Content/UpgradeCard/UpgradeMargin/UpgradeRow/UpgradeInfo/PotentialIncome
@onready var added_expense: Label = $ModalCard/OuterMargin/Content/UpgradeCard/UpgradeMargin/UpgradeRow/UpgradeInfo/AddedExpense
@onready var upgrade_button: Button = $ModalCard/OuterMargin/Content/UpgradeButton
@onready var upgrade_button_label: Label = $ModalCard/OuterMargin/Content/UpgradeButton/UpgradeButtonContent/UpgradeButtonRow/UpgradeButtonLabel
@onready var upgrade_button_amount: Label = $ModalCard/OuterMargin/Content/UpgradeButton/UpgradeButtonContent/UpgradeButtonRow/UpgradeButtonAmount
@onready var upgrade_button_coins: TextureRect = $ModalCard/OuterMargin/Content/UpgradeButton/UpgradeButtonContent/UpgradeButtonRow/UpgradeCoins
@onready var close_button: Button = $CloseButton

var _business_data: Dictionary = {}


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	_apply_static_fonts()
	_load_default_assets()
	if not GameManager.family_money_changed.is_connected(_on_family_money_changed):
		GameManager.family_money_changed.connect(_on_family_money_changed)

	# Standalone F6 preview only. Embedded instances wait for real manager data.
	if (
		_business_data.is_empty()
		and business_instance_id.is_empty()
		and get_tree().current_scene == self
	):
		configure_from_data(_preview_data())


func configure_from_data(data: Dictionary) -> void:
	_business_data = data.duplicate(true)

	business_instance_id = str(_first(
		data,
		["business_instance_id", "id", "instance_id"],
		business_instance_id
	))

	business_title.text = str(_first(
		data,
		["display_name", "name", "business_name"],
		"BUSINESS"
	)).to_upper()

	var level := int(_first(data, ["level"], 1))
	business_level.text = "Level %d" % level

	var monthly_income := float(_first(data, ["monthly_income", "revenue", "income"], 0.0))
	var monthly_expense := float(_first(data, ["monthly_expense", "upkeep", "expense"], 0.0))
	var net_profit := float(_first(data, ["net_profit", "profit"], monthly_income - monthly_expense))

	income_value.text = _money(monthly_income, true)
	expense_value.text = _money(-abs(monthly_expense), false)
	net_value.text = _money(net_profit, net_profit >= 0.0)
	net_value.add_theme_color_override("font_color", COLOR_GREEN if net_profit >= 0.0 else COLOR_RED)

	_set_texture_from_data(
		building_image,
		data,
		["image_path", "building_image", "texture_path"],
		true
	)
	_build_staff_rows(_as_array(_first(data, ["slots", "staff_slots"], [])))
	_apply_upgrade_data(_first(data, ["next_upgrade", "upgrade"], {}))


func open_for_business(id: String, data: Dictionary = {}) -> void:
	business_instance_id = id
	visible = true
	if not data.is_empty():
		configure_from_data(data)
	else:
		refresh_from_business_manager()


func refresh_from_business_manager() -> bool:
	if business_instance_id.is_empty():
		return false

	var data: Dictionary = BUSINESS_MODAL_DATA_ADAPTER.build(business_instance_id)
	if data.is_empty():
		return false

	configure_from_data(data)
	return true


func close_modal() -> void:
	visible = false
	closed.emit()


func _build_staff_rows(slots: Array) -> void:
	for child in staff_list.get_children():
		child.queue_free()

	if slots.is_empty() and business_instance_id == "hospital_preview":
		slots = _preview_data()["slots"]

	for i in range(slots.size()):
		var slot: Dictionary = slots[i] if slots[i] is Dictionary else {}
		staff_list.add_child(_create_staff_row(slot, i))


func _create_staff_row(slot: Dictionary, slot_index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 166)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _staff_style())
	panel.clip_contents = true

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	panel.add_child(row)

	# Left: position + required stat chips.
	var job_margin := MarginContainer.new()
	job_margin.custom_minimum_size = Vector2(310, 0)
	job_margin.add_theme_constant_override("margin_left", 22)
	job_margin.add_theme_constant_override("margin_top", 19)
	job_margin.add_theme_constant_override("margin_right", 20)
	job_margin.add_theme_constant_override("margin_bottom", 18)
	row.add_child(job_margin)

	var job_box := VBoxContainer.new()
	job_box.alignment = BoxContainer.ALIGNMENT_CENTER
	job_box.add_theme_constant_override("separation", 0)
	job_margin.add_child(job_box)

	var role_label := Label.new()
	role_label.text = str(_first(slot, ["role_name", "name", "title", "slot_name"], "Position"))
	role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_label_font(role_label, FONT_SEMIBOLD, 28, COLOR_TEXT)
	job_box.add_child(role_label)

	var role_spacer := Control.new()
	role_spacer.custom_minimum_size = Vector2(0, 24)
	job_box.add_child(role_spacer)

	var requires := Label.new()
	requires.text = "REQUIRES"
	_set_label_font(requires, FONT_SEMIBOLD, 16, COLOR_BROWN)
	job_box.add_child(requires)

	var requires_spacer := Control.new()
	requires_spacer.custom_minimum_size = Vector2(0, 8)
	job_box.add_child(requires_spacer)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	job_box.add_child(chips)

	var required_stats := _as_array(_first(slot, ["required_stats", "requirements"], []))
	var displayed_stats: Array = []
	for stat in required_stats:
		if displayed_stats.size() >= 2:
			break
		displayed_stats.append(stat)
	for stat in displayed_stats:
		chips.add_child(_create_chip(str(stat)))
	if required_stats.size() > 2:
		chips.add_child(_create_chip("+%d" % (required_stats.size() - 2)))

	row.add_child(_staff_middle_separator())

	# Middle: portrait and worker/empty-position information.
	var staff_margin := MarginContainer.new()
	staff_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staff_margin.add_theme_constant_override("margin_left", 22)
	staff_margin.add_theme_constant_override("margin_top", 17)
	staff_margin.add_theme_constant_override("margin_right", 18)
	staff_margin.add_theme_constant_override("margin_bottom", 17)
	row.add_child(staff_margin)

	var staff_row := HBoxContainer.new()
	staff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	staff_row.add_theme_constant_override("separation", 22)
	staff_margin.add_child(staff_row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(112, 112)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	staff_row.add_child(portrait)

	var assigned_character_id = _first(slot, ["assigned_character_id"], null)
	var assigned_npc_id = _first(slot, ["assigned_npc_id"], null)
	var is_filled := assigned_character_id != null or (assigned_npc_id != null and not str(assigned_npc_id).is_empty())
	var worker_name := str(_first(slot, ["worker_name", "staff_name", "assignee_name"], ""))

	if is_filled:
		var portrait_path := str(_first(slot, ["portrait_path"], ""))
		if not portrait_path.is_empty():
			_try_set_texture(portrait, portrait_path)
		else:
			_try_set_texture(portrait, "res://Resources/Characters/default_avatar.png")
	else:
		_try_set_texture(portrait, PATH_EMPTY_SLOT)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 0)
	staff_row.add_child(details)

	var staff_name := Label.new()
	staff_name.text = worker_name if is_filled and not worker_name.is_empty() else ("Assigned" if is_filled else "Empty Position")
	staff_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	staff_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_label_font(staff_name, FONT_SEMIBOLD, 28, COLOR_TEXT)
	details.add_child(staff_name)

	var staff_name_spacer := Control.new()
	staff_name_spacer.custom_minimum_size = Vector2(0, 24)
	details.add_child(staff_name_spacer)

	if is_filled:
		var performance_row := HBoxContainer.new()
		performance_row.add_theme_constant_override("separation", 7)
		details.add_child(performance_row)

		var tier := str(_first(slot, ["performance_grade", "performance_tier", "performance"], ""))
		if not tier.is_empty():
			var tier_icon := TextureRect.new()
			tier_icon.custom_minimum_size = Vector2(27, 27)
			tier_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tier_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_try_set_texture(tier_icon, PATH_TIER_DIR + tier.to_upper() + ".svg")
			performance_row.add_child(tier_icon)

		var performance_label := Label.new()
		performance_label.text = "Performance"
		_set_label_font(performance_label, FONT_REGULAR, 16, COLOR_TEXT)
		performance_row.add_child(performance_label)
	else:
		var potential_label := Label.new()
		potential_label.text = "Potential Income"
		_set_label_font(potential_label, FONT_REGULAR, 16, Color("#4B4642"))
		details.add_child(potential_label)

		var potential_spacer := Control.new()
		potential_spacer.custom_minimum_size = Vector2(0, 8)
		details.add_child(potential_spacer)

	var amount := Label.new()
	var slot_income := float(_first(
		slot,
		["income", "revenue"] if is_filled else ["potential_income", "base_gross_contribution"],
		0.0
	))
	amount.text = _money(slot_income, true)
	_set_label_font(amount, FONT_MEDIUM, 24, COLOR_GREEN)
	details.add_child(amount)

	# Right: Assign / Replace action block.
	var action := Button.new()
	action.custom_minimum_size = Vector2(126, 0)
	action.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action.text = "➜\nReplace" if is_filled else "➜\nAssign"
	action.alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.add_theme_font_size_override("font_size", 18)
	action.add_theme_color_override("font_color", COLOR_BROWN if is_filled else Color.WHITE)
	_try_set_button_font(action, FONT_MEDIUM)

	var button_style := _action_style(is_filled)
	action.add_theme_stylebox_override("normal", button_style)
	action.add_theme_stylebox_override("hover", button_style)
	action.add_theme_stylebox_override("pressed", button_style)
	action.add_theme_stylebox_override("focus", button_style)

	if is_filled:
		action.pressed.connect(func() -> void: replace_requested.emit(business_instance_id, slot_index))
	else:
		action.pressed.connect(func() -> void: assign_requested.emit(business_instance_id, slot_index))

	row.add_child(action)
	return panel


func _apply_upgrade_data(value: Variant) -> void:
	if not value is Dictionary or value.is_empty():
		upgrade_card.visible = false
		upgrade_button.visible = false
		return

	upgrade_card.visible = true
	upgrade_button.visible = true
	var data: Dictionary = value
	var level := int(_first(data, ["level", "next_level"], 0))
	var upgrade_name := str(_first(data, ["name", "display_name", "upgrade_name"], ""))
	var suffix := " (%s)" % upgrade_name if not upgrade_name.is_empty() else ""
	next_level.text = "Level %d%s" % [level, suffix]

	var slot_text := str(_first(data, ["new_slot_text", "new_slot", "slot_unlock"], "+ New Slot"))
	new_slot.text = slot_text

	var potential := float(_first(data, ["potential_income", "income_increase", "revenue_increase"], 0.0))
	var expense := float(_first(data, ["monthly_expense", "expense_increase", "upkeep_increase"], 0.0))
	var cost := float(_first(data, ["cost", "upgrade_cost"], 0.0))

	potential_income.text = "%s Potential Income" % _money(potential, true)
	added_expense.text = "%s Expense" % _money(expense, true)
	upgrade_button_amount.text = _money(cost, false)
	upgrade_button.disabled = cost <= 0.0 or not GameManager.can_afford(int(round(cost)))
	_apply_upgrade_button_state()


func _on_close_pressed() -> void:
	close_modal()


func _on_upgrade_pressed() -> void:
	upgrade_requested.emit(business_instance_id)


func _load_default_assets() -> void:
	_try_set_texture(income_trend, PATH_INCOME_TREND)
	_try_set_texture(expense_trend, PATH_EXPENSE_TREND)
	_try_set_texture(upgrade_icon, PATH_UPGRADE_ICON)
	_try_set_texture(upgrade_button_coins, PATH_UPGRADE_COINS)


func _apply_static_fonts() -> void:
	_set_label_font(business_title, FONT_BOLD, 40, COLOR_TEXT)
	_set_label_font(business_level, FONT_REGULAR, 28, COLOR_TEXT)
	_set_label_font(income_label, FONT_SEMIBOLD, 20, COLOR_TEXT)
	_set_label_font(expense_label, FONT_SEMIBOLD, 20, COLOR_TEXT)
	_set_label_font(net_label, FONT_SEMIBOLD, 20, COLOR_TEXT)
	_set_label_font(income_value, FONT_SEMIBOLD, 28, COLOR_GREEN)
	_set_label_font(expense_value, FONT_SEMIBOLD, 28, COLOR_RED)
	_set_label_font(net_value, FONT_SEMIBOLD, 28, COLOR_GREEN)
	_set_label_font(section_label, FONT_SEMIBOLD, 22, COLOR_BROWN)
	_set_label_font(upgrade_label, FONT_SEMIBOLD, 20, COLOR_TEXT)
	_set_label_font(next_level, FONT_REGULAR, 20, COLOR_TEXT)
	_set_label_font(new_slot, FONT_REGULAR, 20, COLOR_TEXT)
	_set_label_font(potential_income, FONT_REGULAR, 20, COLOR_GREEN)
	_set_label_font(added_expense, FONT_REGULAR, 20, COLOR_RED)
	_set_label_font(upgrade_button_label, FONT_SEMIBOLD, 32, COLOR_BROWN)
	_set_label_font(upgrade_button_amount, FONT_SEMIBOLD, 32, COLOR_BROWN)
	_try_set_button_font(upgrade_button, FONT_SEMIBOLD)
	upgrade_button.add_theme_font_size_override("font_size", 32)
	_try_set_button_font(close_button, FONT_REGULAR)


func _apply_upgrade_button_state() -> void:
	var content_color := Color("#E3CDB5") if upgrade_button.disabled else COLOR_BROWN
	upgrade_button_label.add_theme_color_override("font_color", content_color)
	upgrade_button_amount.add_theme_color_override("font_color", content_color)
	upgrade_button_coins.modulate = Color(1, 1, 1, 0.42) if upgrade_button.disabled else Color.WHITE


func _on_family_money_changed(_new_amount: int) -> void:
	if visible and not business_instance_id.is_empty():
		refresh_from_business_manager()


func _set_label_font(label: Label, path: String, font_size: int, color: Color) -> void:
	if ResourceLoader.exists(path):
		var font := load(path)
		if font:
			label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
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
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 50
	style.corner_radius_top_right = 50
	style.corner_radius_bottom_left = 50
	style.corner_radius_bottom_right = 50
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text_value.capitalize() if not text_value.begins_with("+") else text_value
	_set_label_font(label, FONT_MEDIUM, 16, COLOR_BROWN)
	panel.add_child(label)
	return panel


func _staff_middle_separator() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(2, 0)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.color = COLOR_BORDER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(line)
	return margin


func _staff_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_STAFF
	style.border_color = COLOR_BORDER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	return style


func _action_style(is_replace: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SOFT if is_replace else COLOR_ASSIGN
	style.border_color = COLOR_BORDER if is_replace else COLOR_ASSIGN
	style.border_width_left = 1
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	return style


func _try_set_texture(target: TextureRect, path: String) -> void:
	if ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			target.texture = resource


func _set_texture_from_data(
	target: TextureRect,
	data: Dictionary,
	keys: Array,
	clear_if_unavailable: bool = false
) -> void:
	if clear_if_unavailable:
		target.texture = null

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
		"business_instance_id": "hospital_preview",
		"display_name": "HOSPITAL",
		"level": 3,
		"monthly_income": 420000,
		"monthly_expense": 180000,
		"net_profit": 240000,
		"image_path": PATH_BUILDING_IMAGE,
		"slots": [
			{
				"role_name": "Chief Physician",
				"required_stats": ["logic", "health"],
				"assigned_npc_id": "preview_worker",
				"worker_name": "Rolando Anderson",
				"portrait_path": "res://Resources/Characters/NPC/Worker/worker_female_01.png",
				"performance_grade": "S",
				"income": 200000,
				"potential_income": 200000
			},
			{"role_name": "Surgeon", "required_stats": ["logic", "health", "discipline"], "assigned_character_id": null, "assigned_npc_id": null, "potential_income": 100000},
			{"role_name": "Doctor", "required_stats": ["logic", "health"], "assigned_character_id": null, "assigned_npc_id": null, "potential_income": 80000},
			{"role_name": "Nurse", "required_stats": ["social", "health"], "assigned_character_id": null, "assigned_npc_id": null, "potential_income": 60000},
			{"role_name": "Cleaner", "required_stats": ["discipline", "health"], "assigned_character_id": null, "assigned_npc_id": null, "potential_income": 20000}
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
