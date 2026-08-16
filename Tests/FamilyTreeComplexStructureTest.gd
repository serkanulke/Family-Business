extends Node

const FAMILY_TREE_LAYOUT := preload(
	"res://Scripts/FamilyTree/FamilyTreeLayout.gd"
)

var passed: int = 0
var failed: int = 0


func _ready() -> void:
	print("")
	print("========================================")
	print("Family Tree complex-structure tests starting")
	print("========================================")

	_run_tests()

	print("")
	print("========================================")
	print(
		"Family Tree complex-structure tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL FAMILY TREE COMPLEX-STRUCTURE TESTS PASSED."
		)
	else:
		push_error(
			"Family Tree complex structures have %d failing test(s)."
			% failed
		)


func _run_tests() -> void:
	_test_current_spouse_matches_family_member_depth()
	_test_previous_relationship_child_keeps_correct_depth()
	_test_step_parent_is_not_added_as_parent()
	_test_current_union_child_uses_both_current_parents()
	_test_next_generation_remains_below_parent_generation()


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


func _build_stepfamily_source() -> Array:
	# Character 1 is the family-line parent.
	# Character 2 is the current spouse.
	# Character 3 is a child from an earlier relationship.
	# Parent 99 is intentionally outside the playable tree.
	# Character 4 is a child of the current marriage.
	# Character 5 is Character 3's spouse.
	# Character 6 is their child.
	return [
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
				99
			],
			5
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
			[],
			3
		),
		_make_character(
			6,
			[
				3,
				5
			]
		)
	]


func _test_current_spouse_matches_family_member_depth() -> void:
	var source: Array = _build_stepfamily_source()

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
	)

	_assert_true(
		valid,
		"Current spouse is placed on the same tree level"
	)


func _test_previous_relationship_child_keeps_correct_depth() -> void:
	var source: Array = _build_stepfamily_source()

	var depths: Dictionary = (
		FAMILY_TREE_LAYOUT.calculate_depths(
			source
		)
	)

	var valid: bool = (
		int(
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
	)

	_assert_true(
		valid,
		"Children from previous and current relationships stay on the child level"
	)


func _test_step_parent_is_not_added_as_parent() -> void:
	var source: Array = _build_stepfamily_source()

	var relationship_data: Dictionary = (
		FAMILY_TREE_LAYOUT.build_relationship_data(
			source
		)
	)

	var parent_groups_value = relationship_data.get(
		"parent_groups",
		[]
	)

	var found_previous_child: bool = false
	var valid: bool = false

	if typeof(parent_groups_value) == TYPE_ARRAY:
		var parent_groups: Array = parent_groups_value

		for group_value in parent_groups:
			if typeof(group_value) != TYPE_DICTIONARY:
				continue

			var group: Dictionary = group_value

			if int(
				group.get(
					"child_id",
					0
				)
			) != 3:
				continue

			found_previous_child = true

			var parent_ids_value = group.get(
				"parent_ids",
				[]
			)

			if typeof(parent_ids_value) != TYPE_ARRAY:
				break

			var parent_ids: Array = parent_ids_value

			valid = (
				parent_ids.has(
					1
				)
				and not parent_ids.has(
					2
				)
			)

			break

	_assert_true(
		found_previous_child
		and valid,
		"Current spouse is not falsely treated as previous child's parent"
	)


func _test_current_union_child_uses_both_current_parents() -> void:
	var source: Array = _build_stepfamily_source()

	var relationship_data: Dictionary = (
		FAMILY_TREE_LAYOUT.build_relationship_data(
			source
		)
	)

	var parent_groups_value = relationship_data.get(
		"parent_groups",
		[]
	)

	var valid: bool = false

	if typeof(parent_groups_value) == TYPE_ARRAY:
		var parent_groups: Array = parent_groups_value

		for group_value in parent_groups:
			if typeof(group_value) != TYPE_DICTIONARY:
				continue

			var group: Dictionary = group_value

			if int(
				group.get(
					"child_id",
					0
				)
			) != 4:
				continue

			var parent_ids_value = group.get(
				"parent_ids",
				[]
			)

			if typeof(parent_ids_value) != TYPE_ARRAY:
				break

			var parent_ids: Array = parent_ids_value

			valid = (
				parent_ids.size() == 2
				and parent_ids.has(
					1
				)
				and parent_ids.has(
					2
				)
			)

			break

	_assert_true(
		valid,
		"Child of current marriage connects to both current parents"
	)


func _test_next_generation_remains_below_parent_generation() -> void:
	var source: Array = _build_stepfamily_source()

	var positions: Dictionary = (
		FAMILY_TREE_LAYOUT.calculate_positions(
			source,
			Vector2(
				540.0,
				320.0
			),
			340.0,
			180.0,
			320.0
		)
	)

	var previous_child_position: Vector2 = positions[
		3
	]

	var previous_child_spouse_position: Vector2 = positions[
		5
	]

	var grandchild_position: Vector2 = positions[
		6
	]

	var valid: bool = (
		is_equal_approx(
			previous_child_position.y,
			previous_child_spouse_position.y
		)
		and grandchild_position.y
			> previous_child_position.y
	)

	_assert_true(
		valid,
		"Next generation remains below remarried/stepfamily branch"
	)
