extends Node

const FAMILY_TREE_SCREEN_SCENE := preload(
	"res://Scenes/FamilyTree/FamilyTreeScreen.tscn"
)

var family_tree_screen: Control


func _ready() -> void:
	_prepare_real_runtime_family()

	var screen_instance := FAMILY_TREE_SCREEN_SCENE.instantiate()
	family_tree_screen = screen_instance as Control

	if family_tree_screen == null:
		push_error("FamilyTreeScreen could not be instantiated.")
		return

	# Family surname and Diamonds do not yet have runtime state in GameManager.
	# These two presentation-only values are intentionally explicit here so
	# the rest of the screen can be tested entirely against real managers.
	family_tree_screen.set("family_name", "JOHNSON")
	family_tree_screen.set("unsupported_diamond_text", "—")
	add_child(family_tree_screen)

	await get_tree().process_frame
	await get_tree().process_frame

	print("")
	print("========================================")
	print("Family Tree REAL-DATA UI visual test")
	print("========================================")
	print("Characters from CharacterManager: ", CharacterManager.characters.size())
	print("Date from TimeManager: ", TimeManager.get_date_string())
	print("Money from GameManager: ", GameManager.family_money)
	print("")
	print("Controls:")
	print("- Right mouse drag: pan Family Tree + family logo")
	print("- Mouse wheel: zoom 0.9 - 1.2")
	print("- Touch: one-finger pan / two-finger pinch")
	print("- Pause / Play / x2 / x3 use the real TimeManager")
	print("========================================")


func _prepare_real_runtime_family() -> void:
	GameManager.set_same_sex_marriage_enabled(false)
	GameManager.set_distant_relative_marriage_enabled(false)

	var starting_character: Dictionary = GameManager.start_new_game(
		"William",
		"male"
	)

	if starting_character.is_empty():
		push_error("Real-data UI test could not create the starting Character.")
		return

	var starting_id: int = int(starting_character.get("character_id", 0))
	var candidate: Dictionary = RelationshipNpcManager.create_relationship_candidate(
		starting_id
	)

	if candidate.is_empty():
		push_error("Real-data UI test could not create a Relationship candidate.")
		return

	var candidate_id: int = int(candidate.get("character_id", 0))
	var married: bool = RelationshipNpcManager.make_candidate_family_member(
		candidate_id,
		starting_id
	)

	if not married:
		push_error("Real-data UI test could not marry the generated candidate.")
		return

	var child: Dictionary = CharacterManager.create_baby_character(
		"Mia",
		"female",
		starting_id,
		candidate_id
	)

	if child.is_empty():
		push_error("Real-data UI test could not create the child through CharacterManager.")
