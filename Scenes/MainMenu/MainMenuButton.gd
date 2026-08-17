@tool
extends TextureButton

@export var title_text: String = "BUTTON":
	set(value):
		title_text = value
		_sync_visuals()

@export var subtitle_text: String = "":
	set(value):
		subtitle_text = value
		_sync_visuals()

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_sync_visuals()


func _ready() -> void:
	_sync_visuals()


func _sync_visuals() -> void:
	if not is_inside_tree():
		return

	var icon_rect := get_node_or_null(
		"Padding/Content/Icon"
	) as TextureRect
	var title_label := get_node_or_null(
		"Padding/Content/TextCenter/Text/Title"
	) as Label
	var subtitle_label := get_node_or_null(
		"Padding/Content/TextCenter/Text/Subtitle"
	) as Label

	if icon_rect != null:
		icon_rect.texture = icon_texture

	if title_label != null:
		title_label.text = title_text

	if subtitle_label != null:
		subtitle_label.text = subtitle_text
		subtitle_label.visible = not subtitle_text.is_empty()
