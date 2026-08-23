extends Node
class_name MainScreenController

const MAP_SCENE := preload("res://UI/Map.tscn")

@onready var world: Node = $World
@onready var family_tree_screen: FamilyTreeScreen = $World/FamilyTreeScreen

var map_screen: MapScreen


func _ready() -> void:
	if not family_tree_screen.screen_requested.is_connected(_on_screen_requested):
		family_tree_screen.screen_requested.connect(_on_screen_requested)
	_show_family_tree()


func show_screen(screen_id: String) -> void:
	_on_screen_requested(screen_id)


func _on_screen_requested(screen_id: String) -> void:
	match screen_id:
		"map":
			_show_map()
		"family_tree":
			_show_family_tree()


func _show_map() -> void:
	if map_screen == null:
		map_screen = MAP_SCENE.instantiate() as MapScreen
		map_screen.name = "MapScreen"
		world.add_child(map_screen)
		map_screen.family_tree_requested.connect(_show_family_tree)
	family_tree_screen.visible = false
	family_tree_screen.process_mode = Node.PROCESS_MODE_DISABLED
	map_screen.visible = true
	map_screen.process_mode = Node.PROCESS_MODE_INHERIT
	map_screen.refresh_from_managers()


func _show_family_tree() -> void:
	if map_screen != null:
		map_screen.visible = false
		map_screen.process_mode = Node.PROCESS_MODE_DISABLED
	family_tree_screen.visible = true
	family_tree_screen.process_mode = Node.PROCESS_MODE_INHERIT
	family_tree_screen.refresh_from_managers()
