@tool
extends Node2D
class_name MapBoundaryGuide

const WORLD_SIZE := Vector2(6200.0, 4200.0)


func _ready() -> void:
	visible = Engine.is_editor_hint()
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.35, 0.55, 0.95, 0.85), false, 8.0)

