extends Node


signal lifespan_setting_changed(value: String)
signal same_sex_marriage_setting_changed(value: bool)
signal distant_relative_marriage_setting_changed(value: bool)
signal ex_spouse_remarriage_setting_changed(value: bool)

signal new_game_started(
	starting_character: Dictionary
)

signal family_money_changed(
	new_amount: int
)

signal diamonds_changed(
	new_amount: int
)

signal family_name_changed(
	new_name: String
)

const VALID_LIFESPAN_SETTINGS: Array[String] = [
	"short",
	"normal",
	"long"
]

const STARTING_FAMILY_MONEY := 15000
const STARTING_DIAMONDS := 0


var lifespan_setting: String = "normal"
var allow_same_sex_marriage: bool = true
var allow_distant_relative_marriage: bool = false
var allow_ex_spouse_remarriage: bool = false

var family_money: int = 0
var diamonds: int = 0
var family_name: String = ""


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


func set_same_sex_marriage_enabled(
	value: bool
) -> void:
	if allow_same_sex_marriage == value:
		return

	allow_same_sex_marriage = value
	same_sex_marriage_setting_changed.emit(
		allow_same_sex_marriage
	)


func set_distant_relative_marriage_enabled(
	value: bool
) -> void:
	if allow_distant_relative_marriage == value:
		return

	allow_distant_relative_marriage = value
	distant_relative_marriage_setting_changed.emit(
		allow_distant_relative_marriage
	)


func set_ex_spouse_remarriage_enabled(
	value: bool
) -> void:
	if allow_ex_spouse_remarriage == value:
		return

	allow_ex_spouse_remarriage = value
	ex_spouse_remarriage_setting_changed.emit(
		allow_ex_spouse_remarriage
	)


func set_family_name(
	value: String
) -> void:
	var cleaned_name := value.strip_edges()

	if family_name == cleaned_name:
		return

	family_name = cleaned_name

	family_name_changed.emit(
		family_name
	)


func start_new_game(
	first_name: String,
	gender: String,
	new_family_name: String = ""
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

	set_diamonds(
		STARTING_DIAMONDS
	)

	set_family_name(
		new_family_name
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
		" | Family: ",
		family_name,
		" | Money: ",
		family_money,
		" | Diamonds: ",
		diamonds,
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


func set_diamonds(
	amount: int
) -> void:
	diamonds = maxi(
		amount,
		0
	)

	diamonds_changed.emit(
		diamonds
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


func add_family_money(
	amount: int
) -> bool:
	if amount < 0:
		push_error(
			"Money amount cannot be negative."
		)
		return false

	if amount == 0:
		return true

	set_family_money(
		family_money + amount
	)

	return true
