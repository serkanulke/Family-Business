extends Node2D

@onready var family_tree: Node2D = $FamilyTree


func _ready() -> void:
	CharacterManager.characters = []
	CharacterManager.next_character_id = 1

	var parent_one: Dictionary = (
		CharacterManager.create_base_starting_character(
			"Elena",
			"female"
		)
	)

	var parent_two: Dictionary = (
		CharacterManager.create_base_starting_character(
			"Daniel",
			"male"
		)
	)

	parent_one["birth_date"] = (
		CharacterManager.generate_birth_date_for_age(
			30
		)
	)

	parent_two["birth_date"] = (
		CharacterManager.generate_birth_date_for_age(
			31
		)
	)

	parent_one["partner_id"] = int(
		parent_two[
			"character_id"
		]
	)

	parent_two["partner_id"] = int(
		parent_one[
			"character_id"
		]
	)

	CharacterManager.characters.append(
		parent_one
	)

	CharacterManager.characters.append(
		parent_two
	)

	CharacterManager.create_baby_character(
		"Mia",
		"female",
		int(
			parent_one[
				"character_id"
			]
		),
		int(
			parent_two[
				"character_id"
			]
		)
	)

	CharacterManager.create_baby_character(
		"Noah",
		"male",
		int(
			parent_one[
				"character_id"
			]
		),
		int(
			parent_two[
				"character_id"
			]
		)
	)

	if family_tree.has_method(
		"rebuild_tree"
	):
		family_tree.call(
			"rebuild_tree"
		)
