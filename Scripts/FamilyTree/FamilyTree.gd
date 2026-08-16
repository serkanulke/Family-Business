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

const PORTRAIT_RADIUS := 60.0
const PORTRAIT_CENTER_OFFSET := Vector2(
	90.0,
	72.0
)

@export var tree_origin: Vector2 = Vector2(
	540.0,
	320.0
)

@export var unit_spacing: float = 340.0
@export var partner_spacing: float = 180.0
@export var generation_spacing: float = 320.0

@export var connection_color: Color = Color(
	0.43,
	0.45,
	0.50,
	1.0
)

@export var connection_width: float = 4.0

@onready var character_layer: Node2D = $CharacterLayer
@onready var family_tree_camera: Camera2D = $Camera2D

var layout_positions: Dictionary = {}
var relationship_data: Dictionary = {}


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

	var relationship_manager: Node = get_node_or_null(
		"/root/RelationshipNPCManager"
	)

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
	_clear_character_nodes()

	var family_characters: Array = (
		FAMILY_TREE_LAYOUT.get_playable_characters(
			CharacterManager.characters
		)
	)

	layout_positions = (
		FAMILY_TREE_LAYOUT.calculate_positions(
			family_characters,
			tree_origin,
			unit_spacing,
			partner_spacing,
			generation_spacing
		)
	)

	relationship_data = (
		FAMILY_TREE_LAYOUT.build_relationship_data(
			family_characters
		)
	)

	for character_value in family_characters:
		if typeof(character_value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value
		var character_id: int = int(
			character.get(
				"character_id",
				0
			)
		)

		if not layout_positions.has(
			character_id
		):
			continue

		var character_node_value: Node = (
			CHARACTER_NODE_SCENE.instantiate()
		)

		if character_node_value == null:
			continue

		character_layer.add_child(
			character_node_value
		)

		var character_node: Control = (
			character_node_value as Control
		)

		if character_node == null:
			continue

		var portrait_position: Vector2 = layout_positions[
			character_id
		]

		character_node.position = (
			portrait_position
			- PORTRAIT_CENTER_OFFSET
		)

		if character_node.has_method(
			"setup_character"
		):
			character_node.call(
				"setup_character",
				character
			)

		if character_node.has_signal(
			"character_pressed"
		):
			character_node.connect(
				"character_pressed",
				_on_character_node_pressed
			)

	_update_camera_bounds()
	queue_redraw()


func _draw() -> void:
	_draw_spouse_connections()
	_draw_parent_child_connections()


func _draw_spouse_connections() -> void:
	var spouse_pairs_value = relationship_data.get(
		"spouse_pairs",
		[]
	)

	if typeof(spouse_pairs_value) != TYPE_ARRAY:
		return

	var spouse_pairs: Array = spouse_pairs_value

	for pair_value in spouse_pairs:
		if typeof(pair_value) != TYPE_ARRAY:
			continue

		var pair: Array = pair_value

		if pair.size() != 2:
			continue

		var first_id: int = int(
			pair[0]
		)

		var second_id: int = int(
			pair[1]
		)

		if (
			not layout_positions.has(
				first_id
			)
			or not layout_positions.has(
				second_id
			)
		):
			continue

		var first_position: Vector2 = layout_positions[
			first_id
		]

		var second_position: Vector2 = layout_positions[
			second_id
		]

		var direction: Vector2 = (
			second_position
			- first_position
		).normalized()

		var line_start: Vector2 = (
			first_position
			+ direction * PORTRAIT_RADIUS
		)

		var line_end: Vector2 = (
			second_position
			- direction * PORTRAIT_RADIUS
		)

		draw_line(
			line_start,
			line_end,
			connection_color,
			connection_width,
			true
		)


func _draw_parent_child_connections() -> void:
	var parent_groups_value = relationship_data.get(
		"parent_groups",
		[]
	)

	if typeof(parent_groups_value) != TYPE_ARRAY:
		return

	var parent_groups: Array = parent_groups_value

	for group_value in parent_groups:
		if typeof(group_value) != TYPE_DICTIONARY:
			continue

		var group: Dictionary = group_value
		var child_id: int = int(
			group.get(
				"child_id",
				0
			)
		)

		if not layout_positions.has(
			child_id
		):
			continue

		var parent_ids_value = group.get(
			"parent_ids",
			[]
		)

		if typeof(parent_ids_value) != TYPE_ARRAY:
			continue

		var parent_ids: Array = parent_ids_value
		var parent_positions: Array = []

		for parent_id_value in parent_ids:
			var parent_id: int = int(
				parent_id_value
			)

			if layout_positions.has(
				parent_id
			):
				parent_positions.append(
					layout_positions[
						parent_id
					]
				)

		if parent_positions.is_empty():
			continue

		var source_x: float = 0.0
		var source_y: float = -1000000000.0

		for parent_position_value in parent_positions:
			var parent_position: Vector2 = (
				parent_position_value
			)

			source_x += parent_position.x
			source_y = maxf(
				source_y,
				parent_position.y
			)

		source_x /= float(
			parent_positions.size()
		)

		var source_position: Vector2 = Vector2(
			source_x,
			source_y + PORTRAIT_RADIUS
		)

		var child_position: Vector2 = layout_positions[
			child_id
		]

		var target_position: Vector2 = Vector2(
			child_position.x,
			child_position.y - PORTRAIT_RADIUS
		)

		var middle_y: float = (
			source_position.y
			+ (
				target_position.y
				- source_position.y
			) * 0.5
		)

		var source_middle: Vector2 = Vector2(
			source_position.x,
			middle_y
		)

		var target_middle: Vector2 = Vector2(
			target_position.x,
			middle_y
		)

		draw_line(
			source_position,
			source_middle,
			connection_color,
			connection_width,
			true
		)

		draw_line(
			source_middle,
			target_middle,
			connection_color,
			connection_width,
			true
		)

		draw_line(
			target_middle,
			target_position,
			connection_color,
			connection_width,
			true
		)


func _update_camera_bounds() -> void:
	if family_tree_camera == null:
		return

	if not family_tree_camera.has_method(
		"set_content_bounds"
	):
		return

	if layout_positions.is_empty():
		family_tree_camera.call(
			"clear_content_bounds"
		)
		return

	var first_position_set: bool = false
	var minimum_x: float = 0.0
	var maximum_x: float = 0.0
	var minimum_y: float = 0.0
	var maximum_y: float = 0.0

	for position_value in layout_positions.values():
		if typeof(position_value) != TYPE_VECTOR2:
			continue

		var portrait_position: Vector2 = position_value

		if not first_position_set:
			minimum_x = portrait_position.x
			maximum_x = portrait_position.x
			minimum_y = portrait_position.y
			maximum_y = portrait_position.y
			first_position_set = true
			continue

		minimum_x = minf(
			minimum_x,
			portrait_position.x
		)

		maximum_x = maxf(
			maximum_x,
			portrait_position.x
		)

		minimum_y = minf(
			minimum_y,
			portrait_position.y
		)

		maximum_y = maxf(
			maximum_y,
			portrait_position.y
		)

	if not first_position_set:
		family_tree_camera.call(
			"clear_content_bounds"
		)
		return

	var portrait_half_size: Vector2 = Vector2(
		90.0,
		105.0
	)

	var bounds_position: Vector2 = Vector2(
		minimum_x,
		minimum_y
	) - portrait_half_size

	var bounds_size: Vector2 = Vector2(
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


func _clear_character_nodes() -> void:
	for child in character_layer.get_children():
		character_layer.remove_child(
			child
		)

		child.queue_free()


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
