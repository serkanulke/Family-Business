extends Control
class_name MapScreen

const WORLD_BOUNDS := Rect2(0.0, 0.0, 6200.0, 4200.0)

@onready var map_camera: MapCamera = $MapWorld/Camera2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh_from_managers() -> void:
	# The empty authoring canvas has no manager-backed properties yet.
	pass


func get_world_bounds() -> Rect2:
	return WORLD_BOUNDS
