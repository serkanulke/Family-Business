extends Control
class_name MapScreen

const WORLD_BOUNDS := Rect2(0.0, 0.0, 6200.0, 4200.0)

@onready var map_camera: MapCamera = $MapWorld/Camera2D
@onready var backdrop_layer: CanvasLayer = $BackdropLayer
@onready var map_world: Node2D = $MapWorld


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_screen_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	backdrop_layer.visible = active
	map_world.visible = active
	map_camera.set_screen_active(active)


func refresh_from_managers() -> void:
	# The authored Map has no manager-backed property instances yet.
	pass


func get_world_bounds() -> Rect2:
	return WORLD_BOUNDS
