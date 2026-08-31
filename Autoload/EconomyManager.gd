extends Node


signal external_salaries_paid(
	total_amount: int,
	character_count: int,
	payment_date: String
)


signal family_businesses_settled(
	total_gross_income: int,
	total_fixed_expense: int,
	total_net_profit: int,
	business_count: int,
	payment_date: String
)

signal houses_settled(
	total_fixed_expense: int,
	house_count: int,
	payment_date: String
)


const NEW_CONSTRUCTION_MULTIPLIER := 1.40


var last_external_salary_payment_date: String = ""
var last_family_business_payment_date: String = ""
var last_family_business_breakdown: Array = []
var last_house_payment_date: String = ""
var last_house_expense: int = 0


func _ready() -> void:
	TimeManager.date_changed.connect(
		_on_date_changed
	)

	GameManager.new_game_started.connect(
		_on_new_game_started
	)


func get_new_construction_cost(
	base_level_one_cost: int
) -> int:
	if base_level_one_cost <= 0:
		return 0

	return int(
		round(
			float(base_level_one_cost)
			* NEW_CONSTRUCTION_MULTIPLIER
		)
	)


func _on_new_game_started(
	_starting_character: Dictionary
) -> void:
	last_external_salary_payment_date = ""
	last_family_business_payment_date = ""
	last_family_business_breakdown = []
	last_house_payment_date = ""
	last_house_expense = 0


func _on_date_changed(
	_date_text: String
) -> void:
	if TimeManager.current_day != 1:
		return

	pay_external_salaries()
	settle_family_businesses()
	settle_houses()


func settle_houses() -> bool:
	if TimeManager.current_day != 1:
		return false
	var current_date := TimeManager.get_iso_date_string()
	if last_house_payment_date == current_date:
		return false
	var total_expense := HouseManager.get_total_monthly_expense()
	if total_expense <= 0:
		last_house_payment_date = current_date
		last_house_expense = 0
		return false
	if not GameManager.spend_family_money(total_expense):
		return false
	last_house_payment_date = current_date
	last_house_expense = total_expense
	houses_settled.emit(total_expense, HouseManager.houses.size(), current_date)
	return true


func is_character_eligible_for_external_salary(
	character: Dictionary
) -> bool:
	if character.is_empty():
		return false

	if not bool(
		character.get(
			"is_alive",
			true
		)
	):
		return false

	if not bool(
		character.get(
			"is_player_family",
			false
		)
	):
		return false

	if bool(
		character.get(
			"is_retired",
			false
		)
	):
		return false

	if character.get(
		"job_id",
		null
	) == null:
		return false

	var company_id_value = character.get(
		"company_id",
		null
	)

	if company_id_value == null:
		return false

	var company_id := str(
		company_id_value
	)

	if company_id.is_empty():
		return false

	if CareerManager.is_character_assigned_to_family_business(
		int(
			character.get(
				"character_id",
				0
			)
		)
	):
		return false

	var salary := int(
		character.get(
			"salary",
			0
		)
	)

	return salary > 0


func get_external_salary_total() -> int:
	var total_salary := 0

	for character_value in CharacterManager.characters:
		if typeof(
			character_value
		) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = (
			character_value
		)

		if not is_character_eligible_for_external_salary(
			character
		):
			continue

		total_salary += int(
			character.get(
				"salary",
				0
			)
		)

	return total_salary


func get_external_salary_character_count() -> int:
	var character_count := 0

	for character_value in CharacterManager.characters:
		if typeof(
			character_value
		) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = (
			character_value
		)

		if is_character_eligible_for_external_salary(
			character
		):
			character_count += 1

	return character_count


func pay_external_salaries() -> bool:
	if TimeManager.current_day != 1:
		return false

	var current_date := (
		TimeManager.get_iso_date_string()
	)

	if (
		last_external_salary_payment_date
		== current_date
	):
		return false

	var total_salary := (
		get_external_salary_total()
	)

	var character_count := (
		get_external_salary_character_count()
	)

	last_external_salary_payment_date = (
		current_date
	)

	if total_salary <= 0:
		return false

	if not GameManager.add_family_money(
		total_salary
	):
		return false

	external_salaries_paid.emit(
		total_salary,
		character_count,
		current_date
	)

	print(
		"EXTERNAL SALARIES PAID | Date: ",
		current_date,
		" | Characters: ",
		character_count,
		" | Total: ",
		total_salary,
		" | Family Money: ",
		GameManager.family_money
	)

	return true



func get_family_business_monthly_breakdown() -> Array:
	return BusinessManager.get_all_business_monthly_breakdowns()


func get_family_business_monthly_totals() -> Dictionary:
	var breakdowns := get_family_business_monthly_breakdown()

	var total_gross_income := 0
	var total_fixed_expense := 0
	var total_net_profit := 0

	for breakdown_value in breakdowns:
		if typeof(breakdown_value) != TYPE_DICTIONARY:
			continue

		var breakdown: Dictionary = breakdown_value

		total_gross_income += int(
			breakdown.get(
				"gross_income",
				0
			)
		)

		total_fixed_expense += int(
			breakdown.get(
				"fixed_expense",
				0
			)
		)

		total_net_profit += int(
			breakdown.get(
				"net_profit",
				0
			)
		)

	return {
		"gross_income": total_gross_income,
		"fixed_expense": total_fixed_expense,
		"net_profit": total_net_profit,
		"business_count": breakdowns.size()
	}


func settle_family_businesses() -> bool:
	if TimeManager.current_day != 1:
		return false

	var current_date := (
		TimeManager.get_iso_date_string()
	)

	if (
		last_family_business_payment_date
		== current_date
	):
		return false

	var breakdowns := (
		get_family_business_monthly_breakdown()
	)

	if breakdowns.is_empty():
		last_family_business_payment_date = current_date
		last_family_business_breakdown = []
		return false

	var totals := get_family_business_monthly_totals()

	var total_gross_income := int(
		totals.get(
			"gross_income",
			0
		)
	)

	var total_fixed_expense := int(
		totals.get(
			"fixed_expense",
			0
		)
	)

	var total_net_profit := int(
		totals.get(
			"net_profit",
			0
		)
	)

	if total_net_profit > 0:
		if not GameManager.add_family_money(
			total_net_profit
		):
			return false

	elif total_net_profit < 0:
		var loss_amount: int = absi(
			total_net_profit
		)

		if not GameManager.spend_family_money(
			loss_amount
		):
			return false

	last_family_business_payment_date = current_date
	last_family_business_breakdown = breakdowns.duplicate(true)

	family_businesses_settled.emit(
		total_gross_income,
		total_fixed_expense,
		total_net_profit,
		breakdowns.size(),
		current_date
	)

	print(
		"FAMILY BUSINESSES SETTLED | Date: ",
		current_date,
		" | Businesses: ",
		breakdowns.size(),
		" | Gross: ",
		total_gross_income,
		" | Expense: ",
		total_fixed_expense,
		" | Net: ",
		total_net_profit,
		" | Family Money: ",
		GameManager.family_money
	)

	return true
