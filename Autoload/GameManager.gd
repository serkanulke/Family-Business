extends Node


signal lifespan_setting_changed(value: String)

signal new_game_started(
	starting_character: Dictionary
)

const VALID_LIFESPAN_SETTINGS: Array[String] = [
	"short",
	"normal",
	"long"
]



var lifespan_setting: String = "normal"


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
		" | Date: ",
		TimeManager.get_iso_date_string()
	)

	return starting_character

#func _ready() -> void:
	#call_deferred(
		#"run_new_game_test"
	#)
	#
#func run_new_game_test() -> void:
	#var starting_character := start_new_game(
		#"Test Character",
		#"female"
	#)
#
	#print(
		#"New game test character: ",
		#starting_character
	#)
	#
	#print(
	#"Character count after new game: ",
	#CharacterManager.characters.size()
#)

#func _ready() -> void:
	#call_deferred(
		#"run_baby_creation_test"
	#)
#
#
#func run_baby_creation_test() -> void:
	#TimeManager.reset_time()
	#CharacterManager.reset_characters_for_new_game()
#
	#var mother := (
		#CharacterManager.create_starting_character(
			#"Test Mother",
			#"female"
		#)
	#)
#
	#var father := (
		#CharacterManager.create_starting_character(
			#"Test Father",
			#"male"
		#)
	#)
#
	#mother["genetics"] = {
		#"hair_color": "blonde",
		#"skin_tone": "light",
		#"eye_color": "hazel"
	#}
#
	#father["genetics"] = {
		#"hair_color": "black",
		#"skin_tone": "dark",
		#"eye_color": "blue"
	#}
#
	#mother["logic"] = 100
	#father["logic"] = 100
	#father["creativity"] = 100
#
	#var baby := (
		#CharacterManager.create_baby_character(
			#"Test Baby",
			#"female",
			#int(mother["character_id"]),
			#int(father["character_id"])
		#)
	#)
#
	#print(
		#"Generated baby: ",
		#baby
	#)
#
	#print(
		#"Mother children: ",
		#mother["children_ids"]
	#)
#
	#print(
		#"Father children: ",
		#father["children_ids"]
	#)
#
	#print(
		#"Total character count: ",
		#CharacterManager.characters.size()
	#)
