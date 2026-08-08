extends Node


signal external_salaries_paid(
	total_amount: int,
	character_count: int,
	payment_date: String
)


const NEW_CONSTRUCTION_MULTIPLIER := 1.40


var last_external_salary_payment_date: String = ""


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


func _on_date_changed(
	_date_text: String
) -> void:
	if TimeManager.current_day != 1:
		return

	pay_external_salaries()


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
