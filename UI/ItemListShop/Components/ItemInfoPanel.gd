extends PanelContainer
class_name ItemInfoPanel


const ICON_FOLDER := "res://Resources/Icons/item-list-shop/"
const FONT_REGULAR := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"
const COLOR_PANEL := Color("#FFF5E6")
const COLOR_BORDER := Color("#E8D1B6")
const COLOR_TEXT := Color("#1E1E1E")
const COLOR_BLUE := Color("#083F78")
const COLOR_YELLOW := Color("#FFCE72")


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	add_theme_stylebox_override("panel", _make_style(COLOR_PANEL, 24, COLOR_BORDER, 2))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	margin.add_child(column)
	_add_info_entry(
		column,
		"DURABILITY",
		"Items age from purchase and expire when their remaining lifetime reaches 0.",
		"durability_info_icon.svg",
		COLOR_BLUE,
		Color.WHITE
	)
	_add_divider(column)
	_add_info_entry(
		column,
		"FAMILY HEIRLOOM",
		"Permanent family items that do not receive an expiration date.",
		"heirloom_rarity_icon.svg",
		COLOR_BLUE,
		Color.WHITE
	)
	_add_divider(column)
	_add_info_entry(
		column,
		"LIFESTYLE SCORE",
		"Only equipped items contribute to the character's Lifestyle score.",
		"lifestyle_star.svg",
		COLOR_YELLOW,
		Color.WHITE
	)


func _add_info_entry(
	parent: VBoxContainer,
	title_text: String,
	description: String,
	icon_file: String,
	circle_color: Color,
	icon_modulate: Color
) -> void:
	var entry := MarginContainer.new()
	entry.name = title_text.to_pascal_case() + "Entry"
	entry.custom_minimum_size = Vector2(0.0, 196.0)
	entry.add_theme_constant_override("margin_top", 24)
	entry.add_theme_constant_override("margin_bottom", 24)
	parent.add_child(entry)
	var row := HBoxContainer.new()
	row.name = title_text.to_pascal_case() + "Row"
	row.add_theme_constant_override("separation", 18)
	entry.add_child(row)
	var circle_center := CenterContainer.new()
	circle_center.name = title_text.to_pascal_case() + "IconCenter"
	circle_center.custom_minimum_size = Vector2(52.0, 52.0)
	circle_center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	circle_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(circle_center)
	var circle := PanelContainer.new()
	circle.name = title_text.to_pascal_case() + "IconCircle"
	circle.custom_minimum_size = Vector2(52.0, 52.0)
	circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	circle.add_theme_stylebox_override("panel", _make_style(circle_color, 26, Color.TRANSPARENT, 0))
	circle_center.add_child(circle)
	var center := CenterContainer.new()
	circle.add_child(center)
	var icon := TextureRect.new()
	icon.texture = load(ICON_FOLDER + icon_file) as Texture2D
	icon.custom_minimum_size = Vector2(28.0, 28.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.material = _make_icon_tint_material(icon_modulate)
	center.add_child(icon)
	var text_block := VBoxContainer.new()
	text_block.name = title_text.to_pascal_case() + "TextBlock"
	text_block.custom_minimum_size = Vector2(325.0, 0.0)
	text_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_block.add_theme_constant_override("separation", 10)
	row.add_child(text_block)
	var title := _make_label(title_text, 25, FONT_BOLD)
	title.name = title_text.to_pascal_case() + "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_block.add_child(title)
	var description_label := _make_label(description, 21, FONT_REGULAR)
	description_label.name = title_text.to_pascal_case() + "Description"
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_block.add_child(description_label)


func _add_divider(parent: VBoxContainer) -> void:
	var divider := HSeparator.new()
	var divider_number := 1
	for child in parent.get_children():
		if child is HSeparator:
			divider_number += 1
	divider.name = "InfoDivider%d" % divider_number
	divider.custom_minimum_size.y = 1.0
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var divider_style := StyleBoxLine.new()
	divider_style.color = COLOR_BORDER
	divider_style.thickness = 1
	divider.add_theme_stylebox_override("separator", divider_style)
	parent.add_child(divider)


func _make_label(text_value: String, font_size: int, font_path: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", load(font_path) as Font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	return label


func _make_icon_tint_material(tint_color: Color) -> ShaderMaterial:
	# The provided Lifestyle asset is yellow while the reference uses its alpha
	# silhouette as a white glyph inside a yellow circle. Tint the supplied asset
	# in the UI without modifying or re-exporting the SVG.
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform vec4 tint_color : source_color = vec4(1.0);\nvoid fragment() {\n\tvec4 source = texture(TEXTURE, UV);\n\tCOLOR = vec4(tint_color.rgb, source.a * tint_color.a);\n}\n"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint_color", tint_color)
	return material


func _make_style(background: Color, radius: int, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.border_color = border
	return style
