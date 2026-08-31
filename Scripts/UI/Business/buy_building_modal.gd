extends Control
class_name BuyBuildingModal

signal closed
signal purchase_completed(business_instance_id: String, property_id: String)

const LEVEL_ONE := 1
const PURCHASE_FAILED_TEXT := "Purchase could not be completed."
const PROPERTY_UNAVAILABLE_TEXT := "This building is no longer available."

@onready var building_image: TextureRect = $SafeArea/Center/ModalCard/CardMargin/Content/Header/BuildingImage
@onready var business_title: Label = $SafeArea/Center/ModalCard/CardMargin/Content/Header/HeaderInfo/BusinessTitle
@onready var business_level: Label = $SafeArea/Center/ModalCard/CardMargin/Content/Header/HeaderInfo/BusinessLevel
@onready var close_button: Button = $SafeArea/Center/ModalCard/CardMargin/Content/Header/CloseButton
@onready var potential_income_value: Label = $SafeArea/Center/ModalCard/CardMargin/Content/FinancialPanel/FinancialMargin/Columns/IncomeColumn/IncomeValueRow/PotentialIncomeValue
@onready var monthly_expense_value: Label = $SafeArea/Center/ModalCard/CardMargin/Content/FinancialPanel/FinancialMargin/Columns/ExpenseColumn/ExpenseValueRow/MonthlyExpenseValue
@onready var employee_slots_detail: Label = $SafeArea/Center/ModalCard/CardMargin/Content/EmployeePanel/EmployeeMargin/EmployeeRow/EmployeeText/EmployeeSlotsDetail
@onready var feedback_label: Label = $SafeArea/Center/ModalCard/CardMargin/Content/FeedbackLabel
@onready var buy_button: Button = $SafeArea/Center/ModalCard/CardMargin/Content/BuyButton
@onready var buy_button_amount: Label = $SafeArea/Center/ModalCard/CardMargin/Content/BuyButton/ButtonCenter/ButtonRow/BuyButtonAmount

var property_id: String = ""
var business_type_id: String = ""
var acquisition_cost: int = 0
var _purchase_in_progress: bool = false


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	if not GameManager.family_money_changed.is_connected(_on_family_money_changed):
		GameManager.family_money_changed.connect(_on_family_money_changed)
	_refresh_purchase_state()


func open_for_property(
	selected_property_id: String,
	selected_business_type_id: String
) -> bool:
	var normalized_property_id := selected_property_id.strip_edges()
	var normalized_business_type_id := selected_business_type_id.strip_edges()
	if normalized_property_id.is_empty() or normalized_business_type_id.is_empty():
		return false
	if not BusinessManager.get_business_on_plot(normalized_property_id).is_empty():
		return false

	var business_type := BusinessManager.get_business_type_by_id(
		normalized_business_type_id
	)
	var level_one := BusinessManager.get_level_definition(
		normalized_business_type_id,
		LEVEL_ONE
	)
	var level_slots := BusinessManager.get_level_slot_definitions(
		normalized_business_type_id,
		LEVEL_ONE
	)
	var cost := BusinessManager.get_business_acquisition_cost(
		normalized_business_type_id,
		false
	)
	if business_type.is_empty() or level_one.is_empty():
		return false
	if level_slots.is_empty() or cost <= 0:
		return false

	property_id = normalized_property_id
	business_type_id = normalized_business_type_id
	acquisition_cost = cost
	_purchase_in_progress = false
	_set_feedback("")

	business_title.text = str(
		business_type.get("display_name", business_type_id.capitalize())
	).to_upper()
	business_level.text = "Level %d" % LEVEL_ONE
	potential_income_value.text = "+%s" % _group_digits(
		BusinessManager.get_level_max_gross(business_type_id, LEVEL_ONE)
	)
	monthly_expense_value.text = "-%s" % _group_digits(
		abs(BusinessManager.get_level_fixed_monthly_expense(
			business_type_id,
			LEVEL_ONE
		))
	)
	_set_employee_slot_text(level_slots.size())
	buy_button_amount.text = _group_digits(acquisition_cost)
	_set_modal_visual(
		BusinessManager.get_business_modal_visual_path(business_type_id)
	)

	visible = true
	_refresh_purchase_state()
	return true


func close_modal() -> void:
	if not visible:
		return
	visible = false
	_purchase_in_progress = false
	closed.emit()


func _on_buy_pressed() -> void:
	if _purchase_in_progress:
		return
	if property_id.is_empty() or business_type_id.is_empty():
		_set_feedback(PURCHASE_FAILED_TEXT)
		return
	if not BusinessManager.get_business_on_plot(property_id).is_empty():
		_set_feedback(PROPERTY_UNAVAILABLE_TEXT)
		_refresh_purchase_state()
		return

	acquisition_cost = BusinessManager.get_business_acquisition_cost(
		business_type_id,
		false
	)
	if acquisition_cost <= 0:
		_set_feedback(PURCHASE_FAILED_TEXT)
		_refresh_purchase_state()
		return
	if not GameManager.can_afford(acquisition_cost):
		_set_feedback("")
		_refresh_purchase_state()
		return

	_purchase_in_progress = true
	_set_feedback("")
	_refresh_purchase_state()
	var created_business: Dictionary = BusinessManager.create_business_instance(
		business_type_id,
		property_id,
		false
	)
	_purchase_in_progress = false
	if created_business.is_empty():
		if not BusinessManager.get_business_on_plot(property_id).is_empty():
			_set_feedback(PROPERTY_UNAVAILABLE_TEXT)
		elif not GameManager.can_afford(acquisition_cost):
			_set_feedback("")
		else:
			_set_feedback(PURCHASE_FAILED_TEXT)
		_refresh_purchase_state()
		return

	var business_instance_id := str(
		created_business.get("business_instance_id", "")
	)
	if business_instance_id.is_empty():
		_set_feedback(PURCHASE_FAILED_TEXT)
		_refresh_purchase_state()
		return

	visible = false
	purchase_completed.emit(business_instance_id, property_id)


func _refresh_purchase_state() -> void:
	if buy_button == null:
		return
	var can_purchase := (
		not _purchase_in_progress
		and acquisition_cost > 0
		and GameManager.can_afford(acquisition_cost)
	)
	buy_button.disabled = not can_purchase


func _set_feedback(message: String) -> void:
	if feedback_label == null:
		return
	feedback_label.text = message
	feedback_label.visible = not message.is_empty()


func _set_employee_slot_text(slot_count: int) -> void:
	if slot_count == 1:
		employee_slots_detail.text = "1 employee slot available after purchase."
	else:
		employee_slots_detail.text = (
			"%d employee slots available after purchase." % slot_count
		)


func _set_modal_visual(path: String) -> void:
	building_image.texture = null
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	building_image.texture = load(path) as Texture2D


func _on_close_pressed() -> void:
	close_modal()


func _on_family_money_changed(_new_amount: int) -> void:
	if visible:
		_refresh_purchase_state()


func _group_digits(value: int) -> String:
	var raw := str(absi(value))
	var result := ""
	while raw.length() > 3:
		result = "," + raw.right(3) + result
		raw = raw.left(raw.length() - 3)
	return raw + result
