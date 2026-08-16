extends Node2D

signal character_selected(
	character_id: int
)

const FAMILY_TREE_LAYOUT := preload(
	"res://Scripts/FamilyTree/FamilyTreeLayout.gd"
)

const CHARACTER_NODE_SCENE := preload(
	"res://Scenes/Characters/FamilyTreeCharacterNode.tscn"
)

const LINK_NODE_SCENE := preload(
	"res://Scenes/Characters/FamilyTreeLinkNode.tscn"
)

const PORTRAIT_CENTER_OFFSET := Vector2(
	90.0,
	72.0
)

const LINK_CENTER_OFFSET := Vector2(
	22.0,
	22.0
)

@export var tree_origin: Vector2 = Vector2(
	540.0,
	320.0
)

@export var unit_spacing: float = 340.0
@export var partner_spacing: float = 180.0
@export var generation_spacing: float = 320.0

@export_range(0.1, 0.8, 0.01) var link_vertical_ratio: float = 0.38
@export_range(44.0, 120.0, 1.0) var link_icon_spacing: float = 64.0

@export var connection_color: Color = Color(
	0.43,
	0.45,
	0.50,
	1.0
)

@export var connection_width: float = 4.0

@onready var character_layer: Node2D = $CharacterLayer
@onready var link_layer: Node2D = $LinkLayer
@onready var family_tree_camera: Camera2D = $Camera2D

var layout_positions: Dictionary = {}
var relationship_data: Dictionary = {}

# Runtime-only presentation anchors. They are rebuilt from Character data and
# are never written to Character.json or save state.
var reference_display_data: Dictionary = {}
var link_anchor_positions: Dictionary = {}


func _ready() -> void:
	if not CharacterManager.character_born.is_connected(
		_on_character_born
	):
		CharacterManager.character_born.connect(
			_on_character_born
		)

	if not CharacterManager.character_died.is_connected(
		_on_character_died
	):
		CharacterManager.character_died.connect(
			_on_character_died
		)

	var relationship_manager := _get_relationship_manager()

	if (
		relationship_manager != null
		and relationship_manager.has_signal(
			"family_relationship_changed"
		)
		and not relationship_manager.is_connected(
			"family_relationship_changed",
			_on_family_relationship_changed
		)
	):
		relationship_manager.connect(
			"family_relationship_changed",
			_on_family_relationship_changed
		)

	rebuild_tree()


func rebuild_tree() -> void:
	_clear_visual_nodes()
	reference_display_data = {}
	link_anchor_positions = {}

	var family_characters := (
		FAMILY_TREE_LAYOUT.get_playable_characters(
			CharacterManager.characters
		)
	)

	layout_positions = (
		FAMILY_TREE_LAYOUT.calculate_positions(
			CharacterManager.characters,
			tree_origin,
			unit_spacing,
			partner_spacing,
			generation_spacing
		)
	)

	relationship_data = (
		FAMILY_TREE_LAYOUT.build_relationship_data(
			CharacterManager.characters
		)
	)

	for character_value in family_characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value
		var character_id := int(
			character.get(
				"character_id",
				0
			)
		)

		if not layout_positions.has(character_id):
			continue

		_create_character_node(
			character,
			layout_positions[character_id],
			false
		)

	_build_reference_spouse_nodes()
	_build_link_nodes()

	_update_camera_bounds()
	queue_redraw()


func _draw() -> void:
	_draw_spouse_connections()
	_draw_parent_child_connections()


func _create_character_node(
	character: Dictionary,
	portrait_position: Vector2,
	reference_mode: bool
) -> void:
	var character_node_value := (
		CHARACTER_NODE_SCENE.instantiate()
	)

	if character_node_value == null:
		return

	character_layer.add_child(
		character_node_value
	)

	var character_node := character_node_value as Control

	if character_node == null:
		return

	character_node.position = (
		portrait_position
		- PORTRAIT_CENTER_OFFSET
	)

	if character_node.has_method(
		"setup_character"
	):
		character_node.call(
			"setup_character",
			character,
			reference_mode
		)

	if character_node.has_signal(
		"character_pressed"
	):
		character_node.connect(
			"character_pressed",
			_on_character_node_pressed
		)


func _build_reference_spouse_nodes() -> void:
	var reference_links_value = relationship_data.get(
		"reference_spouse_links",
		[]
	)

	if typeof(reference_links_value) != TYPE_ARRAY:
		return

	for record_value in reference_links_value:
		if typeof(record_value) != TYPE_DICTIONARY:
			continue

		var record: Dictionary = record_value
		var pair_key := String(
			record.get(
				"pair_key",
				""
			)
		)

		var host_id := int(
			record.get(
				"host_id",
				0
			)
		)

		var reference_id := int(
			record.get(
				"reference_id",
				0
			)
		)

		if (
			pair_key.is_empty()
			or not layout_positions.has(host_id)
			or not layout_positions.has(reference_id)
		):
			continue

		var host_position: Vector2 = layout_positions[
			host_id
		]

		var canonical_reference_position: Vector2 = (
			layout_positions[reference_id]
		)

		var side := 1.0

		if canonical_reference_position.x < host_position.x:
			side = -1.0

		var reference_position := (
			host_position
			+ Vector2(
				side * partner_spacing,
				0.0
			)
		)

		var union_position := (
			host_position
			+ reference_position
		) * 0.5

		reference_display_data[pair_key] = {
			"host_id": host_id,
			"reference_id": reference_id,
			"host_position": host_position,
			"reference_position": reference_position,
			"union_position": union_position
		}

		var reference_character := (
			CharacterManager.get_character_by_id(
				reference_id
			)
		)

		if reference_character.is_empty():
			continue

		_create_character_node(
			reference_character,
			reference_position,
			true
		)


func _build_link_nodes() -> void:
	var parent_groups_value = relationship_data.get(
		"parent_groups",
		[]
	)

	if typeof(parent_groups_value) != TYPE_ARRAY:
		return

	# One primary parent can have children with more than one former/off-tree
	# spouse. Build unique link relations first so their icons can fan out
	# instead of stacking on the exact same point.
	var links_by_primary: Dictionary = {}
	var seen_link_keys: Dictionary = {}

	for group_value in parent_groups_value:
		if typeof(group_value) != TYPE_DICTIONARY:
			continue

		var group: Dictionary = group_value

		if String(
			group.get(
				"mode",
				""
			)
		) != "linked_parent":
			continue

		var link_key := String(
			group.get(
				"link_key",
				""
			)
		)

		if link_key.is_empty() or seen_link_keys.has(link_key):
			continue

		var primary_parent_id := int(
			group.get(
				"primary_parent_id",
				0
			)
		)

		var linked_parent_id := int(
			group.get(
				"linked_parent_id",
				0
			)
		)

		if not layout_positions.has(primary_parent_id):
			continue

		seen_link_keys[link_key] = true

		if not links_by_primary.has(primary_parent_id):
			links_by_primary[primary_parent_id] = []

		var records: Array = links_by_primary[
			primary_parent_id
		]

		records.append(
			{
				"link_key": link_key,
				"linked_parent_id": linked_parent_id
			}
		)

	for primary_parent_id_value in links_by_primary.keys():
		var primary_parent_id := int(
			primary_parent_id_value
		)

		var records_value = links_by_primary[
			primary_parent_id
		]

		if typeof(records_value) != TYPE_ARRAY:
			continue

		var records: Array = records_value
		records.sort_custom(
			_sort_link_records
		)

		var primary_position: Vector2 = layout_positions[
			primary_parent_id
		]

		var center_index := (
			float(records.size() - 1) * 0.5
		)

		for record_index in range(records.size()):
			var record: Dictionary = records[record_index]
			var link_key := String(
				record.get(
					"link_key",
					""
				)
			)

			var linked_parent_id := int(
				record.get(
					"linked_parent_id",
					0
				)
			)

			var horizontal_offset := (
				(float(record_index) - center_index)
				* link_icon_spacing
			)

			var link_position := (
				primary_position
				+ Vector2(
					horizontal_offset,
					generation_spacing * link_vertical_ratio
				)
			)

			link_anchor_positions[link_key] = link_position

			_create_link_node(
				linked_parent_id,
				link_position
			)


func _create_link_node(
	linked_character_id: int,
	link_position: Vector2
) -> void:
	var link_node_value := LINK_NODE_SCENE.instantiate()

	if link_node_value == null:
		return

	link_layer.add_child(
		link_node_value
	)

	var link_node := link_node_value as Control

	if link_node == null:
		return

	link_node.position = (
		link_position
		- LINK_CENTER_OFFSET
	)

	if link_node.has_method(
		"setup_linked_character"
	):
		link_node.call(
			"setup_linked_character",
			linked_character_id
		)

	if link_node.has_signal(
		"linked_character_pressed"
	):
		link_node.connect(
			"linked_character_pressed",
			_on_character_node_pressed
		)


func _draw_spouse_connections() -> void:
	var spouse_pairs_value = relationship_data.get(
		"spouse_pairs",
		[]
	)

	if typeof(spouse_pairs_value) == TYPE_ARRAY:
		for pair_value in spouse_pairs_value:
			if typeof(pair_value) != TYPE_ARRAY:
				continue

			var pair: Array = pair_value

			if pair.size() != 2:
				continue

			var first_id := int(pair[0])
			var second_id := int(pair[1])

			if (
				not layout_positions.has(first_id)
				or not layout_positions.has(second_id)
			):
				continue

			_draw_connection_line(
				layout_positions[first_id],
				layout_positions[second_id]
			)

	for display_value in reference_display_data.values():
		if typeof(display_value) != TYPE_DICTIONARY:
			continue

		var display: Dictionary = display_value
		var host_position_value = display.get(
			"host_position",
			null
		)

		var reference_position_value = display.get(
			"reference_position",
			null
		)

		if (
			typeof(host_position_value) != TYPE_VECTOR2
			or typeof(reference_position_value) != TYPE_VECTOR2
		):
			continue

		_draw_connection_line(
			host_position_value,
			reference_position_value
		)


func _draw_parent_child_connections() -> void:
	var parent_groups_value = relationship_data.get(
		"parent_groups",
		[]
	)

	if typeof(parent_groups_value) != TYPE_ARRAY:
		return

	var drawn_link_stems: Dictionary = {}

	for group_value in parent_groups_value:
		if typeof(group_value) != TYPE_DICTIONARY:
			continue

		var group: Dictionary = group_value
		var child_id := int(
			group.get(
				"child_id",
				0
			)
		)

		if not layout_positions.has(child_id):
			continue

		var child_position: Vector2 = layout_positions[
			child_id
		]

		var mode := String(
			group.get(
				"mode",
				"single_parent"
			)
		)

		var source_position := Vector2.ZERO
		var has_source := false

		match mode:
			"spouse_union":
				var parent_ids_value = group.get(
					"parent_ids",
					[]
				)

				if typeof(parent_ids_value) == TYPE_ARRAY:
					var parent_ids: Array = parent_ids_value

					if parent_ids.size() >= 2:
						var first_parent_id := int(parent_ids[0])
						var second_parent_id := int(parent_ids[1])

						if (
							layout_positions.has(first_parent_id)
							and layout_positions.has(second_parent_id)
						):
							source_position = (
								layout_positions[first_parent_id]
								+ layout_positions[second_parent_id]
							) * 0.5
							has_source = true

			"reference_union":
				var pair_key := String(
					group.get(
						"pair_key",
						""
					)
				)

				if reference_display_data.has(pair_key):
					var display: Dictionary = (
						reference_display_data[pair_key]
					)

					var union_position_value = display.get(
						"union_position",
						null
					)

					if typeof(union_position_value) == TYPE_VECTOR2:
						source_position = union_position_value
						has_source = true

			"linked_parent":
				var link_key := String(
					group.get(
						"link_key",
						""
					)
				)

				var primary_parent_id := int(
					group.get(
						"primary_parent_id",
						0
					)
				)

				if link_anchor_positions.has(link_key):
					source_position = link_anchor_positions[
						link_key
					]
					has_source = true

					if (
						not drawn_link_stems.has(link_key)
						and layout_positions.has(primary_parent_id)
					):
						drawn_link_stems[link_key] = true
						_draw_connection_line(
							layout_positions[primary_parent_id],
							source_position
						)

			_:
				var primary_parent_id := int(
					group.get(
						"primary_parent_id",
						0
					)
				)

				if layout_positions.has(primary_parent_id):
					source_position = layout_positions[
						primary_parent_id
					]
					has_source = true

		if not has_source:
			continue

		_draw_orthogonal_connection(
			source_position,
			child_position
		)


func _draw_connection_line(
	from_position: Vector2,
	to_position: Vector2
) -> void:
	draw_line(
		from_position,
		to_position,
		connection_color,
		connection_width,
		true
	)


func _draw_orthogonal_connection(
	from_position: Vector2,
	to_position: Vector2
) -> void:
	var middle_y := (
		from_position.y
		+ (to_position.y - from_position.y) * 0.5
	)

	var source_middle := Vector2(
		from_position.x,
		middle_y
	)

	var target_middle := Vector2(
		to_position.x,
		middle_y
	)

	_draw_connection_line(
		from_position,
		source_middle
	)

	_draw_connection_line(
		source_middle,
		target_middle
	)

	_draw_connection_line(
		target_middle,
		to_position
	)


func _sort_link_records(
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
			"linked_parent_id",
			0
		)
	) < int(
		second.get(
			"linked_parent_id",
			0
		)
	)


func _update_camera_bounds() -> void:
	if family_tree_camera == null:
		return

	if not family_tree_camera.has_method(
		"set_content_bounds"
	):
		return

	var visual_positions: Array = []

	for position_value in layout_positions.values():
		if typeof(position_value) == TYPE_VECTOR2:
			visual_positions.append(position_value)

	for display_value in reference_display_data.values():
		if typeof(display_value) != TYPE_DICTIONARY:
			continue

		var display: Dictionary = display_value
		var reference_position_value = display.get(
			"reference_position",
			null
		)

		if typeof(reference_position_value) == TYPE_VECTOR2:
			visual_positions.append(reference_position_value)

	for link_position_value in link_anchor_positions.values():
		if typeof(link_position_value) == TYPE_VECTOR2:
			visual_positions.append(link_position_value)

	if visual_positions.is_empty():
		family_tree_camera.call(
			"clear_content_bounds"
		)
		return

	var first_position: Vector2 = visual_positions[0]
	var minimum_x := first_position.x
	var maximum_x := first_position.x
	var minimum_y := first_position.y
	var maximum_y := first_position.y

	for position_value in visual_positions:
		var visual_position: Vector2 = position_value
		minimum_x = minf(minimum_x, visual_position.x)
		maximum_x = maxf(maximum_x, visual_position.x)
		minimum_y = minf(minimum_y, visual_position.y)
		maximum_y = maxf(maximum_y, visual_position.y)

	var portrait_half_size := Vector2(
		90.0,
		105.0
	)

	var bounds_position := Vector2(
		minimum_x,
		minimum_y
	) - portrait_half_size

	var bounds_size := Vector2(
		maximum_x - minimum_x,
		maximum_y - minimum_y
	) + portrait_half_size * 2.0

	family_tree_camera.call(
		"set_content_bounds",
		Rect2(
			bounds_position,
			bounds_size
		)
	)


func _clear_visual_nodes() -> void:
	for child in character_layer.get_children():
		character_layer.remove_child(child)
		child.queue_free()

	for child in link_layer.get_children():
		link_layer.remove_child(child)
		child.queue_free()


func _get_relationship_manager() -> Node:
	var manager := get_node_or_null(
		"/root/RelationshipNpcManager"
	)

	if manager != null:
		return manager

	return get_node_or_null(
		"/root/RelationshipNPCManager"
	)


func _on_character_node_pressed(
	character_id: int
) -> void:
	character_selected.emit(
		character_id
	)


func _on_character_born(
	_character_id: int,
	_parent_one_id: int,
	_parent_two_id: int
) -> void:
	rebuild_tree()


func _on_character_died(
	_character_id: int,
	_death_date: String
) -> void:
	rebuild_tree()


func _on_family_relationship_changed() -> void:
	rebuild_tree()
