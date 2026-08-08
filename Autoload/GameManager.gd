extends Node


signal lifespan_setting_changed(value: String)

signal new_game_started(
	starting_character: Dictionary
)

signal family_money_changed(
	new_amount: int
)

const VALID_LIFESPAN_SETTINGS: Array[String] = [
	"short",
	"normal",
	"long"
]

const STARTING_FAMILY_MONEY := 15000


var lifespan_setting: String = "normal"

var family_money: int = 0

func set_lifespan_setting(value: String) -> void:
	var normalized_value := value.strip_edges().to_lower()

	if not VALID_LIFESPAN_SETTINGS.has(normalized_value):
		push_error(
			"Invalid lifespan setting: "
			+ value
		)
		return

	if lifespan_setting == normalized_value:
		return

	lifespan_setting = normalized_value
	lifespan_setting_changed.emit(lifespan_setting)

	print(
		"Lifespan setting changed: ",
		lifespan_setting
	)

func has_lifespan_setting() -> bool:
	return not lifespan_setting.is_empty()

func start_new_game(
	first_name: String,
	gender: String
) -> Dictionary:
	var cleaned_name := first_name.strip_edges()

	if cleaned_name.is_empty():
		push_error(
			"Starting character name cannot be empty."
		)
		return {}

	var normalized_gender := (
		gender.strip_edges().to_lower()
	)

	if normalized_gender not in [
		"female",
		"male"
	]:
		push_error(
			"Invalid starting character gender: "
			+ gender
		)
		return {}

	TimeManager.reset_time()

	set_family_money(
		STARTING_FAMILY_MONEY
	)

	CharacterManager.reset_characters_for_new_game()

	var starting_character := (
		CharacterManager.create_starting_character(
			cleaned_name,
			normalized_gender
		)
	)

	if starting_character.is_empty():
		push_error(
			"Starting character could not be created."
		)
		return {}

	if starting_character.get(
		"job_id",
		null
	) != null:
		CareerManager.assign_company_for_existing_job(
			starting_character
		)

	new_game_started.emit(
		starting_character
	)

	print(
		"New game started.",
		" | Character ID: ",
		starting_character.get(
			"character_id",
			0
		),
		" | Name: ",
		starting_character.get(
			"first_name",
			""
		),
		" | Money: ",
		family_money,
		" | Date: ",
		TimeManager.get_iso_date_string()
	)

	return starting_character

func set_family_money(
	amount: int
) -> void:
	family_money = maxi(
		amount,
		0
	)

	family_money_changed.emit(
		family_money
	)


func can_afford(
	amount: int
) -> bool:
	if amount <= 0:
		return true

	return family_money >= amount


func spend_family_money(
	amount: int
) -> bool:
	if amount < 0:
		push_error(
			"Money amount cannot be negative."
		)
		return false

	if amount == 0:
		return true

	if not can_afford(amount):
		return false

	set_family_money(
		family_money - amount
	)

	return true
