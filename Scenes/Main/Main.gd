extends Node
class_name MainScreenController

const MAP_SCENE := preload("res://UI/Map.tscn")

@onready var world: Node = $World
@onready var family_tree_screen: FamilyTreeScreen = $World/FamilyTreeScreen
@onready var main_hud: MainHUD = $SharedUI/MainHUD

var map_screen: MapScreen


func _ready() -> void:
	if not main_hud.screen_requested.is_connected(_on_screen_requested):
		main_hud.screen_requested.connect(_on_screen_requested)
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
	_set_family_tree_active(false)
	map_screen.set_screen_active(true)
	map_screen.refresh_from_managers()
	main_hud.set_active_screen("map")
	main_hud.refresh_from_managers()


func _show_family_tree() -> void:
	if map_screen != null:
		map_screen.set_screen_active(false)
	_set_family_tree_active(true)
	family_tree_screen.refresh_from_managers()
	main_hud.set_active_screen("family_tree")
	main_hud.refresh_from_managers()


func _set_family_tree_active(active: bool) -> void:
	family_tree_screen.visible = active
	family_tree_screen.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if family_tree_screen.has_method("set_screen_active"):
		family_tree_screen.call("set_screen_active", active)
	var family_camera := family_tree_screen.family_tree_camera
	if family_camera != null:
		family_camera.enabled = active
		if active:
			family_camera.make_current()
