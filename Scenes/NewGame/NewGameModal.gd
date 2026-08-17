extends Control

signal dismissed

const GAME_SCENE := "res://Scenes/Main/Main.tscn"

const MODAL_SIZE := Vector2(920.0, 1252.0)
const MODAL_BG := Color("#FCEFDE")
const BORDER_COLOR := Color("#E4C9AF")
const TEXT_COLOR := Color("#232323")
const SELECTED_CARD_COLOR := Color("#E3CCB6")
const SELECTED_SWATCH_BG := Color("#E3CBB7")

const LIGHT_SKIN_COLOR := Color("#FFF8F2")
const MIXED_SKIN_COLOR := Color("#D8B493")
const DARK_SKIN_COLOR := Color("#8B624A")

const LOAD_BUTTON_BG := "res://Resources/Icons/main-menu/load-btn-bg.png"
const FONT_EXTRA_BOLD := "res://Resources/Fonts/Roboto-ExtraBold.ttf"
const FONT_SEMIBOLD := "res://Resources/Fonts/Roboto-SemiBold.ttf"

var selected_gender: String = "male"
var selected_skin_tone: String = "mixed"

var modal_panel: Panel
var male_button: Button
var female_button: Button
var male_portrait: TextureRect
var female_portrait: TextureRect

var skin_buttons: Dictionary = {}
var selected_portrait_paths: Dictionary = {
	"male": "",
	"female": ""
}


func _ready() -> void:
	set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_overlay()
	_refresh_portraits()
	_refresh_selection_visuals()

	await get_tree().process_frame
	_layout_modal()


func _notification(
	what: int
) -> void:
	if (
		what == NOTIFICATION_RESIZED
		and is_inside_tree()
	):
		_layout_modal()


func _unhandled_key_input(
	event: InputEvent
) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_ESCAPE
	):
		dismissed.emit()


func select_gender(
	value: String
) -> void:
	var normalized := (
		value.strip_edges().to_lower()
	)

	if normalized not in [
		"male",
		"female"
	]:
		return

	selected_gender = normalized
	_refresh_selection_visuals()


func select_skin_tone(
	value: String
) -> void:
	var normalized := (
		value.strip_edges().to_lower()
	)

	if normalized not in [
		"light",
		"mixed",
		"dark"
	]:
		return

	if selected_skin_tone == normalized:
		return

	selected_skin_tone = normalized
	_refresh_portraits()
	_refresh_selection_visuals()


func get_selected_portrait_path() -> String:
	return String(
		selected_portrait_paths.get(
			selected_gender,
			""
		)
	)


func _build_overlay() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(
		0.0,
		0.0,
		0.0,
		0.28
	)
	dim.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(
		dim
	)

	modal_panel = Panel.new()
	modal_panel.name = "Modal"
	modal_panel.size = MODAL_SIZE
	modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var modal_style := StyleBoxFlat.new()
	modal_style.bg_color = MODAL_BG
	modal_style.corner_radius_top_left = 80
	modal_style.corner_radius_top_right = 80
	modal_style.corner_radius_bottom_left = 80
	modal_style.corner_radius_bottom_right = 80
	modal_style.anti_aliasing = true

	modal_panel.add_theme_stylebox_override(
		"panel",
		modal_style
	)

	add_child(
		modal_panel
	)

	var title := Label.new()
	title.name = "Title"
	title.text = "SELECT CHARACTER"
	title.position = Vector2(
		70.0,
		40.0
	)
	title.size = Vector2(
		780.0,
		100.0
	)
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		64
	)
	title.add_theme_color_override(
		"font_color",
		TEXT_COLOR
	)

	var extra_bold := load(
		FONT_EXTRA_BOLD
	) as FontFile

	if extra_bold != null:
		title.add_theme_font_override(
			"font",
			extra_bold
		)

	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_panel.add_child(
		title
	)

	var gender_section := Panel.new()
	gender_section.name = "GenderSection"
	gender_section.position = Vector2(
		0.0,
		174.0
	)
	gender_section.size = Vector2(
		920.0,
		510.0
	)
	gender_section.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var gender_section_style := StyleBoxFlat.new()
	gender_section_style.bg_color = Color(
		0.0,
		0.0,
		0.0,
		0.0
	)
	gender_section_style.border_width_left = 3
	gender_section_style.border_width_top = 3
	gender_section_style.border_width_right = 3
	gender_section_style.border_width_bottom = 3
	gender_section_style.border_color = BORDER_COLOR

	gender_section.add_theme_stylebox_override(
		"panel",
		gender_section_style
	)

	modal_panel.add_child(
		gender_section
	)

	male_button = _create_gender_button(
		"male"
	)
	male_button.position = Vector2(
		50.0,
		50.0
	)
	gender_section.add_child(
		male_button
	)

	female_button = _create_gender_button(
		"female"
	)
	female_button.position = Vector2(
		462.0,
		50.0
	)
	gender_section.add_child(
		female_button
	)

	male_portrait = male_button.get_node(
		"Portrait"
	) as TextureRect

	female_portrait = female_button.get_node(
		"Portrait"
	) as TextureRect

	var skin_panel := Panel.new()
	skin_panel.name = "SkinSelector"
	skin_panel.position = Vector2(
		170.0,
		734.0
	)
	skin_panel.size = Vector2(
		580.0,
		188.0
	)
	skin_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var skin_panel_style := StyleBoxFlat.new()
	skin_panel_style.bg_color = Color(
		1.0,
		0.98,
		0.965,
		1.0
	)
	skin_panel_style.border_width_left = 2
	skin_panel_style.border_width_top = 2
	skin_panel_style.border_width_right = 2
	skin_panel_style.border_width_bottom = 2
	skin_panel_style.border_color = BORDER_COLOR
	skin_panel_style.corner_radius_top_left = 94
	skin_panel_style.corner_radius_top_right = 94
	skin_panel_style.corner_radius_bottom_left = 94
	skin_panel_style.corner_radius_bottom_right = 94

	skin_panel.add_theme_stylebox_override(
		"panel",
		skin_panel_style
	)

	modal_panel.add_child(
		skin_panel
	)

	var skin_values := [
		{
			"id": "light",
			"color": LIGHT_SKIN_COLOR
		},
		{
			"id": "mixed",
			"color": MIXED_SKIN_COLOR
		},
		{
			"id": "dark",
			"color": DARK_SKIN_COLOR
		}
	]

	for index in range(
		skin_values.size()
	):
		var skin_definition: Dictionary = (
			skin_values[index]
		)

		var skin_button := _create_skin_button(
			String(
				skin_definition["id"]
			),
			skin_definition["color"]
		)

		skin_button.position = Vector2(
			55.0 + float(index) * 170.0,
			24.0
		)

		skin_panel.add_child(
			skin_button
		)

		skin_buttons[
			String(
				skin_definition["id"]
			)
		] = skin_button

	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.position = Vector2(
		0.0,
		992.0
	)
	divider.size = Vector2(
		920.0,
		3.0
	)
	divider.color = BORDER_COLOR
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_panel.add_child(
		divider
	)

	var start_button := TextureButton.new()
	start_button.name = "StartGameButton"
	start_button.position = Vector2(
		204.0,
		1042.0
	)
	start_button.size = Vector2(
		512.0,
		164.0
	)
	start_button.custom_minimum_size = (
		start_button.size
	)
	start_button.ignore_texture_size = true
	start_button.stretch_mode = (
		TextureButton.STRETCH_SCALE
	)
	start_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)

	var button_texture := load(
		LOAD_BUTTON_BG
	) as Texture2D

	start_button.texture_normal = button_texture
	start_button.texture_hover = button_texture
	start_button.texture_pressed = button_texture

	start_button.pressed.connect(
		_on_start_game_pressed
	)

	modal_panel.add_child(
		start_button
	)

	var button_label := Label.new()
	button_label.name = "Label"
	button_label.text = "START GAME"
	button_label.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	button_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	button_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	button_label.add_theme_color_override(
		"font_color",
		Color.WHITE
	)
	button_label.add_theme_font_size_override(
		"font_size",
		64
	)

	var semibold := load(
		FONT_SEMIBOLD
	) as FontFile

	if semibold != null:
		button_label.add_theme_font_override(
			"font",
			semibold
		)

	button_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	start_button.add_child(
		button_label
	)


func _create_gender_button(
	gender: String
) -> Button:
	var button := Button.new()
	button.name = (
		"MaleButton"
		if gender == "male"
		else "FemaleButton"
	)
	button.size = Vector2(
		408.0,
		408.0
	)
	button.custom_minimum_size = button.size
	button.text = ""
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	button.focus_mode = Control.FOCUS_NONE

	button.pressed.connect(
		func() -> void:
			select_gender(
				gender
			)
	)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.position = Vector2(
		24.0,
		24.0
	)
	portrait.size = Vector2(
		360.0,
		360.0
	)
	portrait.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)
	portrait.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	portrait.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	button.add_child(
		portrait
	)

	return button


func _create_skin_button(
	skin_tone: String,
	swatch_color: Color
) -> Button:
	var button := Button.new()
	button.name = (
		skin_tone.capitalize()
		+ "SkinButton"
	)
	button.size = Vector2(
		140.0,
		140.0
	)
	button.custom_minimum_size = button.size
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)

	button.pressed.connect(
		func() -> void:
			select_skin_tone(
				skin_tone
			)
	)

	var circle := Panel.new()
	circle.name = "Circle"
	circle.position = Vector2(
		15.0,
		15.0
	)
	circle.size = Vector2(
		110.0,
		110.0
	)
	circle.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	var circle_style := StyleBoxFlat.new()
	circle_style.bg_color = swatch_color
	circle_style.corner_radius_top_left = 55
	circle_style.corner_radius_top_right = 55
	circle_style.corner_radius_bottom_left = 55
	circle_style.corner_radius_bottom_right = 55
	circle_style.anti_aliasing = true

	circle.add_theme_stylebox_override(
		"panel",
		circle_style
	)

	button.add_child(
		circle
	)

	return button


func _refresh_portraits() -> void:
	for gender in [
		"male",
		"female"
	]:
		var path := (
			CharacterManager.get_random_portrait_path(
				gender,
				selected_skin_tone
			)
		)

		selected_portrait_paths[
			gender
		] = path

		var texture := load(
			path
		) as Texture2D

		if gender == "male":
			if male_portrait != null:
				male_portrait.texture = texture
		else:
			if female_portrait != null:
				female_portrait.texture = texture


func _refresh_selection_visuals() -> void:
	if male_button != null:
		_apply_gender_button_style(
			male_button,
			selected_gender == "male"
		)

	if female_button != null:
		_apply_gender_button_style(
			female_button,
			selected_gender == "female"
		)

	for skin_tone_value in skin_buttons.keys():
		var skin_tone := String(
			skin_tone_value
		)

		var button := skin_buttons[
			skin_tone
		] as Button

		_apply_skin_button_style(
			button,
			selected_skin_tone == skin_tone
		)


func _apply_gender_button_style(
	button: Button,
	is_selected: bool
) -> void:
	var style := StyleBoxFlat.new()

	style.bg_color = (
		SELECTED_CARD_COLOR
		if is_selected
		else Color(
			0.0,
			0.0,
			0.0,
			0.0
		)
	)

	style.corner_radius_top_left = 48
	style.corner_radius_top_right = 48
	style.corner_radius_bottom_left = 48
	style.corner_radius_bottom_right = 48
	style.anti_aliasing = true

	for state in [
		"normal",
		"hover",
		"pressed",
		"focus"
	]:
		button.add_theme_stylebox_override(
			state,
			style
		)


func _apply_skin_button_style(
	button: Button,
	is_selected: bool
) -> void:
	if button == null:
		return

	var style := StyleBoxFlat.new()

	style.bg_color = (
		SELECTED_SWATCH_BG
		if is_selected
		else Color(
			0.0,
			0.0,
			0.0,
			0.0
		)
	)

	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.anti_aliasing = true

	for state in [
		"normal",
		"hover",
		"pressed",
		"focus"
	]:
		button.add_theme_stylebox_override(
			state,
			style
		)


func _layout_modal() -> void:
	if modal_panel == null:
		return

	modal_panel.position = (
		(size - MODAL_SIZE)
		* 0.5
	)


func _on_start_game_pressed() -> void:
	var starting_character := (
		GameManager.start_new_game_from_character_selection(
			selected_gender,
			selected_skin_tone,
			get_selected_portrait_path()
		)
	)

	if starting_character.is_empty():
		return

	get_tree().change_scene_to_file(
		GAME_SCENE
	)
