extends Node

const FAMILY_TREE_LAYOUT := preload(
	"res://Scripts/FamilyTree/FamilyTreeLayout.gd"
)

const LINK_NODE_SCENE := preload(
	"res://Scenes/Characters/FamilyTreeLinkNode.tscn"
)

var passed: int = 0
var failed: int = 0


func _ready() -> void:
	print("")
	print("========================================")
	print("Family Tree relationship-display tests starting")
	print("========================================")

	_test_link_icon_resource_exists()
	_test_off_tree_ex_spouse_uses_linked_parent_mode()
	_test_divorced_visible_parents_use_single_branch_and_link()
	_test_distant_relative_marriage_uses_reference_spouse()
	_test_reference_marriage_does_not_force_canonical_depth_alignment()
	_test_normal_external_spouse_still_uses_standard_pair()
	_test_link_node_keeps_target_character_id()

	print("")
	print("========================================")
	print(
		"Family Tree relationship-display tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")

	if failed == 0:
		print(
			"ALL FAMILY TREE RELATIONSHIP-DISPLAY TESTS PASSED."
		)
	else:
		push_error(
			"Family Tree relationship display has %d failing test(s)."
			% failed
		)


func _make_character(
	character_id: int,
	parent_ids: Array,
	partner_id: Variant = null,
	is_player_family: bool = true,
	character_type: Variant = null
) -> Dictionary:
	var character := {
		"character_id": character_id,
		"first_name": "C" + str(character_id),
		"is_player_family": is_player_family,
		"is_alive": true,
		"parent_ids": parent_ids.duplicate(),
		"partner_id": partner_id,
		"children_ids": []
	}

	if character_type != null:
		character["character_type"] = character_type

	return character


func _test_link_icon_resource_exists() -> void:
	_assert_true(
		ResourceLoader.exists(
			"res://Resources/Icons/link-icon.svg"
		),
		"link-icon.svg is available for Family Tree reference/link nodes"
	)


func _test_off_tree_ex_spouse_uses_linked_parent_mode() -> void:
	var source: Array = [
		_make_character(
			1,
			[]
		),
		_make_character(
			2,
			[],
			null,
			false,
			"relationship_npc"
		),
		_make_character(
			3,
			[
				1,
				2
			]
		)
	]

	var data := FAMILY_TREE_LAYOUT.build_relationship_data(
		source
	)

	var group := _get_parent_group(
		data,
		3
	)

	var valid: bool = (
		String(
			group.get(
				"mode",
				""
			)
		) == "linked_parent"
		and int(
			group.get(
				"primary_parent_id",
				0
			)
		) == 1
		and int(
			group.get(
				"linked_parent_id",
				0
			)
		) == 2
	)

	_assert_true(
		valid,
		"Off-tree ex-spouse is represented by a link icon instead of a long connector"
	)


func _test_divorced_visible_parents_use_single_branch_and_link() -> void:
	var source: Array = [
		_make_character(
			1,
			[]
		),
		_make_character(
			2,
			[],
			null,
			true,
			"relationship_npc"
		),
		_make_character(
			3,
			[
				1,
				2
			]
		)
	]

	var data := FAMILY_TREE_LAYOUT.build_relationship_data(
		source
	)

	var group := _get_parent_group(
		data,
		3
	)

	var parent_ids_value = group.get(
		"parent_ids",
		[]
	)

	var valid: bool = (
		String(
			group.get(
				"mode",
				""
			)
		) == "linked_parent"
		and int(
			group.get(
				"primary_parent_id",
				0
			)
		) == 1
		and int(
			group.get(
				"linked_parent_id",
				0
			)
		) == 2
		and typeof(parent_ids_value) == TYPE_ARRAY
		and parent_ids_value == [1]
	)

	_assert_true(
		valid,
		"Divorced parents keep one visible family branch and one linked-parent icon"
	)


func _test_distant_relative_marriage_uses_reference_spouse() -> void:
	var source := _build_distant_relative_family()

	var data := FAMILY_TREE_LAYOUT.build_relationship_data(
		source
	)

	var reference_links_value = data.get(
		"reference_spouse_links",
		[]
	)

	var spouse_pairs_value = data.get(
		"spouse_pairs",
		[]
	)

	var child_group := _get_parent_group(
		data,
		5
	)

	var valid: bool = (
		typeof(reference_links_value) == TYPE_ARRAY
		and reference_links_value.size() == 1
		and typeof(spouse_pairs_value) == TYPE_ARRAY
		and not _contains_pair(
			spouse_pairs_value,
			3,
			4
		)
		and String(
			child_group.get(
				"mode",
				""
			)
		) == "reference_union"
	)

	_assert_true(
		valid,
		"Distant-relative marriage uses a reference portrait instead of joining canonical branches"
	)


func _test_reference_marriage_does_not_force_canonical_depth_alignment() -> void:
	var source: Array = [
		_make_character(
			10,
			[]
		),
		_make_character(
			20,
			[]
		),
		_make_character(
			30,
			[
				20
			]
		),
		_make_character(
			1,
			[
				10
			],
			2
		),
		_make_character(
			2,
			[
				30
			],
			1
		)
	]

	var depths := FAMILY_TREE_LAYOUT.calculate_depths(
		source
	)

	var valid: bool = (
		int(
			depths.get(
				1,
				-1
			)
		) == 1
		and int(
			depths.get(
				2,
				-1
			)
		) == 2
	)

	_assert_true(
		valid,
		"Reference marriage never changes canonical parent-derived generation depth"
	)


func _test_normal_external_spouse_still_uses_standard_pair() -> void:
	var source: Array = [
		_make_character(
			10,
			[]
		),
		_make_character(
			1,
			[
				10
			],
			2
		),
		_make_character(
			2,
			[],
			1,
			true,
			"relationship_npc"
		),
		_make_character(
			3,
			[
				1,
				2
			]
		)
	]

	var data := FAMILY_TREE_LAYOUT.build_relationship_data(
		source
	)

	var spouse_pairs_value = data.get(
		"spouse_pairs",
		[]
	)

	var reference_links_value = data.get(
		"reference_spouse_links",
		[]
	)

	var group := _get_parent_group(
		data,
		3
	)

	var valid: bool = (
		typeof(spouse_pairs_value) == TYPE_ARRAY
		and _contains_pair(
			spouse_pairs_value,
			1,
			2
		)
		and typeof(reference_links_value) == TYPE_ARRAY
		and reference_links_value.is_empty()
		and String(
			group.get(
				"mode",
				""
			)
		) == "spouse_union"
	)

	_assert_true(
		valid,
		"Normal external-spouse marriage keeps the standard two-portrait layout"
	)


func _test_link_node_keeps_target_character_id() -> void:
	var node_value := LINK_NODE_SCENE.instantiate()
	add_child(node_value)

	var valid: bool = false

	if node_value.has_method(
		"setup_linked_character"
	):
		node_value.call(
			"setup_linked_character",
			77
		)

		valid = int(
			node_value.get(
				"linked_character_id"
			)
		) == 77

	node_value.queue_free()

	_assert_true(
		valid,
		"Visible link icon points to the real Character ID behind its ghost anchor"
	)


func _build_distant_relative_family() -> Array:
	return [
		_make_character(
			1,
			[]
		),
		_make_character(
			2,
			[]
		),
		_make_character(
			3,
			[
				1
			],
			4
		),
		_make_character(
			4,
			[
				2
			],
			3
		),
		_make_character(
			5,
			[
				3,
				4
			]
		)
	]


func _get_parent_group(
	data: Dictionary,
	child_id: int
) -> Dictionary:
	var groups_value = data.get(
		"parent_groups",
		[]
	)

	if typeof(groups_value) != TYPE_ARRAY:
		return {}

	for group_value in groups_value:
		if typeof(group_value) != TYPE_DICTIONARY:
			continue

		var group: Dictionary = group_value

		if int(
			group.get(
				"child_id",
				0
			)
		) == child_id:
			return group

	return {}


func _contains_pair(
	pairs: Array,
	first_id: int,
	second_id: int
) -> bool:
	for pair_value in pairs:
		if typeof(pair_value) != TYPE_ARRAY:
			continue

		var pair: Array = pair_value

		if pair.size() != 2:
			continue

		if (
			pair.has(first_id)
			and pair.has(second_id)
		):
			return true

	return false


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
