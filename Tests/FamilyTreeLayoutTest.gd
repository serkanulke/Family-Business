extends Node

const FAMILY_TREE_LAYOUT := preload(
	"res://Scripts/FamilyTree/FamilyTreeLayout.gd"
)

var passed: int = 0
var failed: int = 0


func _ready() -> void:
	print("")
	print("========================================")
	print("Family Tree layout tests starting")
	print("========================================")

	_run_tests()

	print("")
	print("========================================")
	print(
		"Family Tree layout tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL FAMILY TREE LAYOUT TESTS PASSED."
		)
	else:
		push_error(
			"Family Tree layout has %d failing test(s)."
			% failed
		)


func _run_tests() -> void:
	_test_non_family_characters_are_excluded()
	_test_parent_child_depths()
	_test_external_spouse_matches_partner_depth()
	_test_positions_follow_depth_and_partner_rules()
	_test_relationship_data_uses_parent_ids()


func _assert_true(
	condition: bool,
	test_name: String
) -> void:
	if condition:
		passed += 1
		print(
			"[PASS] ",
			test_name
		)
	else:
		failed += 1
		push_error(
			"[FAIL] "
			+ test_name
		)


func _make_character(
	character_id: int,
	parent_ids: Array,
	partner_id: Variant = null,
	is_player_family: bool = true
) -> Dictionary:
	return {
		"character_id": character_id,
		"first_name": "C" + str(
			character_id
		),
		"is_player_family": is_player_family,
		"is_alive": true,
		"parent_ids": parent_ids,
		"partner_id": partner_id,
		"children_ids": []
	}


func _test_non_family_characters_are_excluded() -> void:
	var source: Array = [
		_make_character(
			1,
			[]
		),
		_make_character(
			2,
			[],
			null,
			false
		)
	]

	var family: Array = (
		FAMILY_TREE_LAYOUT.get_playable_characters(
			source
		)
	)

	var valid: bool = (
		family.size() == 1
		and int(
			family[0].get(
				"character_id",
				0
			)
		) == 1
	)

	_assert_true(
		valid,
		"External relationship candidates are excluded from Family Tree"
	)


func _test_parent_child_depths() -> void:
	var source: Array = [
		_make_character(
			1,
			[],
			2
		),
		_make_character(
			2,
			[],
			1
		),
		_make_character(
			3,
			[
				1,
				2
			]
		),
		_make_character(
			4,
			[
				1,
				2
			]
		),
		_make_character(
			5,
			[
				3
			]
		)
	]

	var depths: Dictionary = (
		FAMILY_TREE_LAYOUT.calculate_depths(
			source
		)
	)

	var valid: bool = (
		int(
			depths.get(
				1,
				-1
			)
		) == 0
		and int(
			depths.get(
				2,
				-1
			)
		) == 0
		and int(
			depths.get(
				3,
				-1
			)
		) == 1
		and int(
			depths.get(
				4,
				-1
			)
		) == 1
		and int(
			depths.get(
				5,
				-1
			)
		) == 2
	)

	_assert_true(
		valid,
		"Parent-child links calculate visual tree depth"
	)


func _test_external_spouse_matches_partner_depth() -> void:
	var source: Array = [
		_make_character(
			1,
			[]
		),
		_make_character(
			2,
			[
				1
			],
			3
		),
		_make_character(
			3,
			[],
			2
		),
		_make_character(
			4,
			[
				2,
				3
			]
		)
	]

	var depths: Dictionary = (
		FAMILY_TREE_LAYOUT.calculate_depths(
			source
		)
	)

	var valid: bool = (
		int(
			depths.get(
				2,
				-1
			)
		) == 1
		and int(
			depths.get(
				3,
				-1
			)
		) == 1
		and int(
			depths.get(
				4,
				-1
			)
		) == 2
	)

	_assert_true(
		valid,
		"Spouse without stored parents is shown on partner generation"
	)


func _test_positions_follow_depth_and_partner_rules() -> void:
	var source: Array = [
		_make_character(
			1,
			[],
			2
		),
		_make_character(
			2,
			[],
			1
		),
		_make_character(
			3,
			[
				1,
				2
			]
		),
		_make_character(
			4,
			[
				1,
				2
			]
		)
	]

	var partner_spacing: float = 180.0
	var generation_spacing: float = 320.0

	var positions: Dictionary = (
		FAMILY_TREE_LAYOUT.calculate_positions(
			source,
			Vector2(
				540.0,
				320.0
			),
			340.0,
			partner_spacing,
			generation_spacing
		)
	)

	var first_position: Vector2 = positions[
		1
	]

	var second_position: Vector2 = positions[
		2
	]

	var child_one_position: Vector2 = positions[
		3
	]

	var child_two_position: Vector2 = positions[
		4
	]

	var valid: bool = (
		is_equal_approx(
			first_position.y,
			second_position.y
		)
		and is_equal_approx(
			absf(
				first_position.x
				- second_position.x
			),
			partner_spacing
		)
		and is_equal_approx(
			child_one_position.y
				- first_position.y,
			generation_spacing
		)
		and is_equal_approx(
			child_one_position.y,
			child_two_position.y
		)
		and not is_equal_approx(
			child_one_position.x,
			child_two_position.x
		)
	)

	_assert_true(
		valid,
		"Layout places spouses together and children on next row"
	)


func _test_relationship_data_uses_parent_ids() -> void:
	var source: Array = [
		_make_character(
			1,
			[],
			2
		),
		_make_character(
			2,
			[],
			1
		),
		_make_character(
			3,
			[
				1,
				2
			]
		)
	]

	var relationship_data: Dictionary = (
		FAMILY_TREE_LAYOUT.build_relationship_data(
			source
		)
	)

	var spouse_pairs_value = relationship_data.get(
		"spouse_pairs",
		[]
	)

	var parent_groups_value = relationship_data.get(
		"parent_groups",
		[]
	)

	var valid: bool = (
		typeof(spouse_pairs_value) == TYPE_ARRAY
		and typeof(parent_groups_value) == TYPE_ARRAY
		and spouse_pairs_value.size() == 1
		and parent_groups_value.size() == 1
	)

	if valid:
		var parent_group: Dictionary = (
			parent_groups_value[0]
		)

		var stored_parent_ids_value = parent_group.get(
			"parent_ids",
			[]
		)

		valid = (
			typeof(stored_parent_ids_value) == TYPE_ARRAY
			and stored_parent_ids_value == [
				1,
				2
			]
			and int(
				parent_group.get(
					"child_id",
					0
				)
			) == 3
		)

	_assert_true(
		valid,
		"Family Tree connectors are built from gender-neutral parent_ids"
	)
