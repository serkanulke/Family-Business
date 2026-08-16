class_name FamilyTreeLayout
extends RefCounted


static func get_playable_characters(
	source_characters: Array
) -> Array:
	var playable_characters: Array = []

	for character_value in source_characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value

		if not bool(
			character.get(
				"is_player_family",
				false
			)
		):
			continue

		playable_characters.append(
			character
		)

	playable_characters.sort_custom(
		_sort_characters_by_id
	)

	return playable_characters


static func build_character_map(
	source_characters: Array
) -> Dictionary:
	var character_map: Dictionary = {}

	for character_value in get_playable_characters(
		source_characters
	):
		var character: Dictionary = character_value
		var character_id: int = int(
			character.get(
				"character_id",
				0
			)
		)

		if character_id <= 0:
			continue

		character_map[character_id] = character

	return character_map


static func build_all_character_map(
	source_characters: Array
) -> Dictionary:
	var character_map: Dictionary = {}

	for character_value in source_characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value
		var character_id := int(
			character.get(
				"character_id",
				0
			)
		)

		if character_id <= 0:
			continue

		character_map[character_id] = character

	return character_map


static func calculate_depths(
	source_characters: Array
) -> Dictionary:
	var family_characters := get_playable_characters(
		source_characters
	)

	var character_map := build_character_map(
		family_characters
	)

	var depths: Dictionary = {}

	for character_value in family_characters:
		var character: Dictionary = character_value
		var character_id := int(
			character.get(
				"character_id",
				0
			)
		)

		if character_id > 0:
			depths[character_id] = 0

	var maximum_passes := maxi(
		8,
		family_characters.size() * 4
	)

	for _pass_index in range(
		maximum_passes
	):
		var changed := false

		for character_value in family_characters:
			var character: Dictionary = character_value
			var character_id := int(
				character.get(
					"character_id",
					0
				)
			)

			if not depths.has(
				character_id
			):
				continue

			var desired_depth := int(
				depths[character_id]
			)

			var parent_ids_value = character.get(
				"parent_ids",
				[]
			)

			if typeof(parent_ids_value) == TYPE_ARRAY:
				for parent_id_value in parent_ids_value:
					if parent_id_value == null:
						continue

					var parent_id := int(
						parent_id_value
					)

					if not character_map.has(
						parent_id
					):
						continue

					desired_depth = maxi(
						desired_depth,
						int(
							depths.get(
								parent_id,
								0
							)
						) + 1
					)

			if desired_depth > int(
				depths[character_id]
			):
				depths[character_id] = desired_depth
				changed = true

		# Only a simple spouse is aligned to the family member's depth.
		# When both spouses already have visible family ancestry, they keep
		# their canonical parent-derived depths and a reference portrait is
		# used for the marriage presentation instead.
		for character_value in family_characters:
			var character: Dictionary = character_value
			var character_id := int(
				character.get(
					"character_id",
					0
				)
			)

			var partner_id_value = character.get(
				"partner_id",
				null
			)

			if partner_id_value == null:
				continue

			var partner_id := int(
				partner_id_value
			)

			if (
				not character_map.has(character_id)
				or not character_map.has(partner_id)
			):
				continue

			var partner: Dictionary = character_map[
				partner_id
			]

			if _is_reference_spouse_pair(
				character,
				partner,
				character_map
			):
				continue

			var shared_depth := maxi(
				int(
					depths.get(
						character_id,
						0
					)
				),
				int(
					depths.get(
						partner_id,
						0
					)
				)
			)

			if int(depths[character_id]) != shared_depth:
				depths[character_id] = shared_depth
				changed = true

			if int(depths[partner_id]) != shared_depth:
				depths[partner_id] = shared_depth
				changed = true

		if not changed:
			break

	return depths


static func calculate_positions(
	source_characters: Array,
	origin: Vector2 = Vector2(
		540.0,
		320.0
	),
	unit_spacing: float = 340.0,
	partner_spacing: float = 180.0,
	generation_spacing: float = 320.0
) -> Dictionary:
	var family_characters := get_playable_characters(
		source_characters
	)

	var character_map := build_character_map(
		family_characters
	)

	var depths := calculate_depths(
		source_characters
	)

	var positions: Dictionary = {}
	var maximum_depth := 0

	for depth_value in depths.values():
		maximum_depth = maxi(
			maximum_depth,
			int(depth_value)
		)

	for depth_index in range(
		maximum_depth + 1
	):
		var units := _build_units_for_depth(
			family_characters,
			character_map,
			depths,
			depth_index,
			positions,
			origin.x
		)

		if units.is_empty():
			continue

		units.sort_custom(
			_sort_unit_records
		)

		var unit_centers := _calculate_unit_centers(
			units,
			origin.x,
			unit_spacing
		)

		var row_y := (
			origin.y
			+ float(depth_index) * generation_spacing
		)

		for unit_index in range(
			units.size()
		):
			var unit: Dictionary = units[unit_index]
			var members_value = unit.get(
				"members",
				[]
			)

			if typeof(members_value) != TYPE_ARRAY:
				continue

			var members: Array = members_value
			var center_x := float(
				unit_centers[unit_index]
			)

			if members.size() == 1:
				positions[int(members[0])] = Vector2(
					center_x,
					row_y
				)
				continue

			var left_x := center_x - partner_spacing * 0.5
			var right_x := center_x + partner_spacing * 0.5

			positions[int(members[0])] = Vector2(
				left_x,
				row_y
			)

			positions[int(members[1])] = Vector2(
				right_x,
				row_y
			)

	return positions


static func build_relationship_data(
	source_characters: Array
) -> Dictionary:
	var family_characters := get_playable_characters(
		source_characters
	)

	var family_map := build_character_map(
		family_characters
	)

	var all_map := build_all_character_map(
		source_characters
	)

	var spouse_pairs: Array = []
	var reference_spouse_links: Array = []
	var parent_groups: Array = []
	var seen_spouse_pairs: Dictionary = {}

	for character_value in family_characters:
		var character: Dictionary = character_value
		var character_id := int(
			character.get(
				"character_id",
				0
			)
		)

		var partner_id_value = character.get(
			"partner_id",
			null
		)

		if partner_id_value == null:
			continue

		var partner_id := int(
			partner_id_value
		)

		if not family_map.has(partner_id):
			continue

		var lower_id := mini(
			character_id,
			partner_id
		)

		var upper_id := maxi(
			character_id,
			partner_id
		)

		var pair_key := _pair_key(
			lower_id,
			upper_id
		)

		if seen_spouse_pairs.has(pair_key):
			continue

		seen_spouse_pairs[pair_key] = true

		var partner: Dictionary = family_map[
			partner_id
		]

		if _is_reference_spouse_pair(
			character,
			partner,
			family_map
		):
			var host_id := lower_id
			var reference_id := upper_id

			reference_spouse_links.append(
				{
					"pair_key": pair_key,
					"host_id": host_id,
					"reference_id": reference_id
				}
			)
		else:
			spouse_pairs.append(
				[
					lower_id,
					upper_id
				]
			)

	for child_value in family_characters:
		var child: Dictionary = child_value
		var child_id := int(
			child.get(
				"character_id",
				0
			)
		)

		var parent_ids_value = child.get(
			"parent_ids",
			[]
		)

		if typeof(parent_ids_value) != TYPE_ARRAY:
			continue

		var all_parent_ids: Array = []
		var visible_parent_ids: Array = []

		for parent_id_value in parent_ids_value:
			if parent_id_value == null:
				continue

			var parent_id := int(parent_id_value)

			if parent_id <= 0:
				continue

			if parent_id not in all_parent_ids:
				all_parent_ids.append(parent_id)

			if (
				family_map.has(parent_id)
				and parent_id not in visible_parent_ids
			):
				visible_parent_ids.append(parent_id)

		if visible_parent_ids.is_empty():
			continue

		visible_parent_ids.sort()

		if visible_parent_ids.size() == 1:
			var primary_parent_id := int(
				visible_parent_ids[0]
			)

			var linked_parent_id := _find_hidden_parent_id(
				all_parent_ids,
				primary_parent_id,
				family_map,
				all_map
			)

			if linked_parent_id > 0:
				parent_groups.append(
					{
						"child_id": child_id,
						"mode": "linked_parent",
						"parent_ids": [
							primary_parent_id
						],
						"primary_parent_id": primary_parent_id,
						"linked_parent_id": linked_parent_id,
						"link_key": _pair_key(
							primary_parent_id,
							linked_parent_id
						)
					}
				)
			else:
				parent_groups.append(
					{
						"child_id": child_id,
						"mode": "single_parent",
						"parent_ids": [
							primary_parent_id
						],
						"primary_parent_id": primary_parent_id
					}
				)

			continue

		var first_parent_id := int(
			visible_parent_ids[0]
		)

		var second_parent_id := int(
			visible_parent_ids[1]
		)

		var first_parent: Dictionary = family_map[
			first_parent_id
		]

		var second_parent: Dictionary = family_map[
			second_parent_id
		]

		if _are_current_partners(
			first_parent,
			second_parent
		):
			if _is_reference_spouse_pair(
				first_parent,
				second_parent,
				family_map
			):
				var pair_key := _pair_key(
					first_parent_id,
					second_parent_id
				)

				parent_groups.append(
					{
						"child_id": child_id,
						"mode": "reference_union",
						"parent_ids": [
							first_parent_id,
							second_parent_id
						],
						"pair_key": pair_key,
						"primary_parent_id": mini(
							first_parent_id,
							second_parent_id
						),
						"linked_parent_id": maxi(
							first_parent_id,
							second_parent_id
						)
					}
				)
			else:
				parent_groups.append(
					{
						"child_id": child_id,
						"mode": "spouse_union",
						"parent_ids": [
							first_parent_id,
							second_parent_id
						]
					}
				)

			continue

		# The parents are both visible but no longer married to each other.
		# Only one branch remains visually connected to the child; the other
		# parent is represented by the link icon. parent_ids remain untouched.
		var primary_parent_id := _select_primary_display_parent(
			first_parent_id,
			second_parent_id,
			all_map
		)

		var linked_parent_id := (
			second_parent_id
			if primary_parent_id == first_parent_id
			else first_parent_id
		)

		parent_groups.append(
			{
				"child_id": child_id,
				"mode": "linked_parent",
				"parent_ids": [
					primary_parent_id
				],
				"primary_parent_id": primary_parent_id,
				"linked_parent_id": linked_parent_id,
				"link_key": _pair_key(
					primary_parent_id,
					linked_parent_id
				)
			}
		)

	return {
		"spouse_pairs": spouse_pairs,
		"reference_spouse_links": reference_spouse_links,
		"parent_groups": parent_groups
	}


static func _build_units_for_depth(
	family_characters: Array,
	character_map: Dictionary,
	depths: Dictionary,
	target_depth: int,
	positions: Dictionary,
	default_x: float
) -> Array:
	var ids_at_depth: Array = []

	for character_value in family_characters:
		var character: Dictionary = character_value
		var character_id := int(
			character.get(
				"character_id",
				0
			)
		)

		if int(
			depths.get(
				character_id,
				-1
			)
		) == target_depth:
			ids_at_depth.append(character_id)

	ids_at_depth.sort()

	var visited: Dictionary = {}
	var units: Array = []

	for character_id_value in ids_at_depth:
		var character_id := int(
			character_id_value
		)

		if visited.has(character_id):
			continue

		var character: Dictionary = character_map.get(
			character_id,
			{}
		)

		if character.is_empty():
			continue

		var members: Array = [
			character_id
		]

		var partner_id_value = character.get(
			"partner_id",
			null
		)

		if partner_id_value != null:
			var partner_id := int(partner_id_value)

			if (
				partner_id in ids_at_depth
				and not visited.has(partner_id)
				and character_map.has(partner_id)
			):
				var partner: Dictionary = character_map[
					partner_id
				]

				if not _is_reference_spouse_pair(
					character,
					partner,
					character_map
				):
					members.append(partner_id)

		members.sort()

		for member_id_value in members:
			visited[int(member_id_value)] = true

		var parent_x_values: Array = []

		for member_id_value in members:
			var member_id := int(member_id_value)
			var member: Dictionary = character_map.get(
				member_id,
				{}
			)

			var parent_ids_value = member.get(
				"parent_ids",
				[]
			)

			if typeof(parent_ids_value) != TYPE_ARRAY:
				continue

			for parent_id_value in parent_ids_value:
				if parent_id_value == null:
					continue

				var parent_id := int(parent_id_value)

				if not positions.has(parent_id):
					continue

				var parent_position: Vector2 = positions[
					parent_id
				]

				parent_x_values.append(
					parent_position.x
				)

		var desired_x := default_x

		if not parent_x_values.is_empty():
			var parent_x_total := 0.0

			for parent_x_value in parent_x_values:
				parent_x_total += float(
					parent_x_value
				)

			desired_x = (
				parent_x_total
				/ float(parent_x_values.size())
			)

		units.append(
			{
				"members": members,
				"desired_x": desired_x,
				"min_id": int(members[0])
			}
		)

	return units


static func _calculate_unit_centers(
	units: Array,
	default_x: float,
	unit_spacing: float
) -> Array:
	var centers: Array = []

	if units.is_empty():
		return centers

	var desired_total := 0.0

	for unit_value in units:
		var unit: Dictionary = unit_value
		desired_total += float(
			unit.get(
				"desired_x",
				default_x
			)
		)

	var desired_average := (
		desired_total
		/ float(units.size())
	)

	for unit_index in range(
		units.size()
	):
		var unit: Dictionary = units[unit_index]
		var desired_x := float(
			unit.get(
				"desired_x",
				default_x
			)
		)

		if unit_index == 0:
			centers.append(desired_x)
			continue

		var previous_center := float(
			centers[unit_index - 1]
		)

		centers.append(
			maxf(
				desired_x,
				previous_center + unit_spacing
			)
		)

	var actual_total := 0.0

	for center_value in centers:
		actual_total += float(center_value)

	var actual_average := (
		actual_total
		/ float(centers.size())
	)

	var row_shift := desired_average - actual_average

	for center_index in range(
		centers.size()
	):
		centers[center_index] = (
			float(centers[center_index])
			+ row_shift
		)

	return centers


static func _is_reference_spouse_pair(
	first_character: Dictionary,
	second_character: Dictionary,
	family_map: Dictionary
) -> bool:
	return (
		_has_visible_parent(
			first_character,
			family_map
		)
		and _has_visible_parent(
			second_character,
			family_map
		)
	)


static func _has_visible_parent(
	character: Dictionary,
	family_map: Dictionary
) -> bool:
	var parent_ids_value = character.get(
		"parent_ids",
		[]
	)

	if typeof(parent_ids_value) != TYPE_ARRAY:
		return false

	for parent_id_value in parent_ids_value:
		if parent_id_value == null:
			continue

		if family_map.has(
			int(parent_id_value)
		):
			return true

	return false


static func _are_current_partners(
	first_character: Dictionary,
	second_character: Dictionary
) -> bool:
	var first_id := int(
		first_character.get(
			"character_id",
			0
		)
	)

	var second_id := int(
		second_character.get(
			"character_id",
			0
		)
	)

	if first_id <= 0 or second_id <= 0:
		return false

	return (
		first_character.get(
			"partner_id",
			null
		) == second_id
		and second_character.get(
			"partner_id",
			null
		) == first_id
	)


static func _find_hidden_parent_id(
	all_parent_ids: Array,
	visible_parent_id: int,
	family_map: Dictionary,
	all_map: Dictionary
) -> int:
	for parent_id_value in all_parent_ids:
		var parent_id := int(parent_id_value)

		if parent_id == visible_parent_id:
			continue

		if family_map.has(parent_id):
			continue

		if all_map.has(parent_id):
			return parent_id

	return 0


static func _select_primary_display_parent(
	first_parent_id: int,
	second_parent_id: int,
	all_map: Dictionary
) -> int:
	var first_parent: Dictionary = all_map.get(
		first_parent_id,
		{}
	)

	var second_parent: Dictionary = all_map.get(
		second_parent_id,
		{}
	)

	var first_is_relationship_npc := (
		String(
			first_parent.get(
				"character_type",
				""
			)
		) == "relationship_npc"
	)

	var second_is_relationship_npc := (
		String(
			second_parent.get(
				"character_type",
				""
			)
		) == "relationship_npc"
	)

	if (
		first_is_relationship_npc
		and not second_is_relationship_npc
	):
		return second_parent_id

	if (
		second_is_relationship_npc
		and not first_is_relationship_npc
	):
		return first_parent_id

	return mini(
		first_parent_id,
		second_parent_id
	)


static func _pair_key(
	first_id: int,
	second_id: int
) -> String:
	var lower_id := mini(
		first_id,
		second_id
	)

	var upper_id := maxi(
		first_id,
		second_id
	)

	return (
		str(lower_id)
		+ ":"
		+ str(upper_id)
	)


static func _sort_characters_by_id(
	first_value: Variant,
	second_value: Variant
) -> bool:
	if (
		typeof(first_value) != TYPE_DICTIONARY
		or typeof(second_value) != TYPE_DICTIONARY
	):
		return false

	var first: Dictionary = first_value
	var second: Dictionary = second_value

	return int(
		first.get(
			"character_id",
			0
		)
	) < int(
		second.get(
			"character_id",
			0
		)
	)


static func _sort_unit_records(
	first_value: Variant,
	second_value: Variant
) -> bool:
	if (
		typeof(first_value) != TYPE_DICTIONARY
		or typeof(second_value) != TYPE_DICTIONARY
	):
		return false

	var first: Dictionary = first_value
	var second: Dictionary = second_value

	var first_x := float(
		first.get(
			"desired_x",
			0.0
		)
	)

	var second_x := float(
		second.get(
			"desired_x",
			0.0
		)
	)

	if not is_equal_approx(
		first_x,
		second_x
	):
		return first_x < second_x

	return int(
		first.get(
			"min_id",
			0
		)
	) < int(
		second.get(
			"min_id",
			0
		)
	)
