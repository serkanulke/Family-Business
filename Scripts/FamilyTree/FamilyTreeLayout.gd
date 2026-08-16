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


static func calculate_depths(
	source_characters: Array
) -> Dictionary:
	var family_characters: Array = get_playable_characters(
		source_characters
	)

	var character_map: Dictionary = build_character_map(
		family_characters
	)

	var depths: Dictionary = {}

	for character_value in family_characters:
		var character: Dictionary = character_value
		var character_id: int = int(
			character.get(
				"character_id",
				0
			)
		)

		if character_id > 0:
			depths[character_id] = 0

	var maximum_passes: int = maxi(
		8,
		family_characters.size() * 4
	)

	for _pass_index in range(
		maximum_passes
	):
		var changed: bool = false

		for character_value in family_characters:
			var character: Dictionary = character_value
			var character_id: int = int(
				character.get(
					"character_id",
					0
				)
			)

			if not depths.has(
				character_id
			):
				continue

			var desired_depth: int = int(
				depths[
					character_id
				]
			)

			var parent_ids_value = character.get(
				"parent_ids",
				[]
			)

			if typeof(parent_ids_value) == TYPE_ARRAY:
				var parent_ids: Array = parent_ids_value

				for parent_id_value in parent_ids:
					if parent_id_value == null:
						continue

					var parent_id: int = int(
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
				depths[
					character_id
				]
			):
				depths[character_id] = desired_depth
				changed = true

		for character_value in family_characters:
			var character: Dictionary = character_value
			var character_id: int = int(
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

			var partner_id: int = int(
				partner_id_value
			)

			if (
				not depths.has(
					character_id
				)
				or not depths.has(
					partner_id
				)
			):
				continue

			var shared_depth: int = maxi(
				int(
					depths[
						character_id
					]
				),
				int(
					depths[
						partner_id
					]
				)
			)

			if int(
				depths[
					character_id
				]
			) != shared_depth:
				depths[character_id] = shared_depth
				changed = true

			if int(
				depths[
					partner_id
				]
			) != shared_depth:
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
	var family_characters: Array = get_playable_characters(
		source_characters
	)

	var character_map: Dictionary = build_character_map(
		family_characters
	)

	var depths: Dictionary = calculate_depths(
		family_characters
	)

	var positions: Dictionary = {}
	var maximum_depth: int = 0

	for depth_value in depths.values():
		maximum_depth = maxi(
			maximum_depth,
			int(
				depth_value
			)
		)

	for depth_index in range(
		maximum_depth + 1
	):
		var units: Array = _build_units_for_depth(
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

		var unit_centers: Array = _calculate_unit_centers(
			units,
			origin.x,
			unit_spacing
		)

		var row_y: float = (
			origin.y
			+ float(
				depth_index
			) * generation_spacing
		)

		for unit_index in range(
			units.size()
		):
			var unit: Dictionary = units[
				unit_index
			]

			var members_value = unit.get(
				"members",
				[]
			)

			if typeof(members_value) != TYPE_ARRAY:
				continue

			var members: Array = members_value
			var center_x: float = float(
				unit_centers[
					unit_index
				]
			)

			if members.size() == 1:
				positions[
					int(
						members[0]
					)
				] = Vector2(
					center_x,
					row_y
				)
				continue

			var left_x: float = (
				center_x
				- partner_spacing * 0.5
			)

			var right_x: float = (
				center_x
				+ partner_spacing * 0.5
			)

			positions[
				int(
					members[0]
				)
			] = Vector2(
				left_x,
				row_y
			)

			positions[
				int(
					members[1]
				)
			] = Vector2(
				right_x,
				row_y
			)

	return positions


static func build_relationship_data(
	source_characters: Array
) -> Dictionary:
	var family_characters: Array = get_playable_characters(
		source_characters
	)

	var character_map: Dictionary = build_character_map(
		family_characters
	)

	var spouse_pairs: Array = []
	var parent_groups: Array = []
	var seen_spouse_pairs: Dictionary = {}

	for character_value in family_characters:
		var character: Dictionary = character_value
		var character_id: int = int(
			character.get(
				"character_id",
				0
			)
		)

		var partner_id_value = character.get(
			"partner_id",
			null
		)

		if partner_id_value != null:
			var partner_id: int = int(
				partner_id_value
			)

			if character_map.has(
				partner_id
			):
				var lower_id: int = mini(
					character_id,
					partner_id
				)

				var upper_id: int = maxi(
					character_id,
					partner_id
				)

				var pair_key: String = (
					str(
						lower_id
					)
					+ ":"
					+ str(
						upper_id
					)
				)

				if not seen_spouse_pairs.has(
					pair_key
				):
					seen_spouse_pairs[
						pair_key
					] = true

					spouse_pairs.append(
						[
							lower_id,
							upper_id
						]
					)

		var parent_ids_value = character.get(
			"parent_ids",
			[]
		)

		if typeof(parent_ids_value) != TYPE_ARRAY:
			continue

		var valid_parent_ids: Array = []

		for parent_id_value in parent_ids_value:
			if parent_id_value == null:
				continue

			var parent_id: int = int(
				parent_id_value
			)

			if (
				character_map.has(
					parent_id
				)
				and parent_id not in valid_parent_ids
			):
				valid_parent_ids.append(
					parent_id
				)

		if valid_parent_ids.is_empty():
			continue

		valid_parent_ids.sort()

		parent_groups.append(
			{
				"child_id": character_id,
				"parent_ids": valid_parent_ids
			}
		)

	return {
		"spouse_pairs": spouse_pairs,
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
		var character_id: int = int(
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
			ids_at_depth.append(
				character_id
			)

	ids_at_depth.sort()

	var visited: Dictionary = {}
	var units: Array = []

	for character_id_value in ids_at_depth:
		var character_id: int = int(
			character_id_value
		)

		if visited.has(
			character_id
		):
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
			var partner_id: int = int(
				partner_id_value
			)

			if (
				partner_id in ids_at_depth
				and not visited.has(
					partner_id
				)
			):
				members.append(
					partner_id
				)

		members.sort()

		for member_id_value in members:
			visited[
				int(
					member_id_value
				)
			] = true

		var parent_x_values: Array = []

		for member_id_value in members:
			var member_id: int = int(
				member_id_value
			)

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

			var parent_ids: Array = parent_ids_value

			for parent_id_value in parent_ids:
				if parent_id_value == null:
					continue

				var parent_id: int = int(
					parent_id_value
				)

				if not positions.has(
					parent_id
				):
					continue

				var parent_position: Vector2 = positions[
					parent_id
				]

				parent_x_values.append(
					parent_position.x
				)

		var desired_x: float = default_x

		if not parent_x_values.is_empty():
			var parent_x_total: float = 0.0

			for parent_x_value in parent_x_values:
				parent_x_total += float(
					parent_x_value
				)

			desired_x = (
				parent_x_total
				/ float(
					parent_x_values.size()
				)
			)

		units.append(
			{
				"members": members,
				"desired_x": desired_x,
				"min_id": int(
					members[0]
				)
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

	var desired_total: float = 0.0

	for unit_value in units:
		var unit: Dictionary = unit_value
		desired_total += float(
			unit.get(
				"desired_x",
				default_x
			)
		)

	var desired_average: float = (
		desired_total
		/ float(
			units.size()
		)
	)

	for unit_index in range(
		units.size()
	):
		var unit: Dictionary = units[
			unit_index
		]

		var desired_x: float = float(
			unit.get(
				"desired_x",
				default_x
			)
		)

		if unit_index == 0:
			centers.append(
				desired_x
			)
			continue

		var previous_center: float = float(
			centers[
				unit_index - 1
			]
		)

		centers.append(
			maxf(
				desired_x,
				previous_center
				+ unit_spacing
			)
		)

	var actual_total: float = 0.0

	for center_value in centers:
		actual_total += float(
			center_value
		)

	var actual_average: float = (
		actual_total
		/ float(
			centers.size()
		)
	)

	var row_shift: float = (
		desired_average
		- actual_average
	)

	for center_index in range(
		centers.size()
	):
		centers[
			center_index
		] = (
			float(
				centers[
					center_index
				]
			)
			+ row_shift
		)

	return centers


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

	var first_x: float = float(
		first.get(
			"desired_x",
			0.0
		)
	)

	var second_x: float = float(
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
