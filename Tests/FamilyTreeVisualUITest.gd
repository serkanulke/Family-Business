extends Control

const FamilyTreeScreenScript = preload("res://Scenes/FamilyTree/FamilyTreeScreen.gd")
const OUTFIT_SEMIBOLD_PATH := "res://Resources/Fonts/Outfit-SemiBold.ttf"

var screen: Control
var debug_bar: Panel
var scenario_label: Label
var debug_font: FontFile

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(OUTFIT_SEMIBOLD_PATH):
		debug_font = load(OUTFIT_SEMIBOLD_PATH) as FontFile

	screen = FamilyTreeScreenScript.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)

	_build_debug_bar()
	await get_tree().process_frame
	_set_scenario("normal")

func _build_debug_bar() -> void:
	debug_bar = Panel.new()
	debug_bar.name = "VisualTestControls"
	debug_bar.position = Vector2(300, 18)
	debug_bar.size = Vector2(480, 86)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.10, 0.84)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	debug_bar.add_theme_stylebox_override("panel", style)
	add_child(debug_bar)

	scenario_label = Label.new()
	scenario_label.text = "VISUAL TEST"
	scenario_label.position = Vector2(14, 7)
	scenario_label.size = Vector2(452, 22)
	scenario_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scenario_label.add_theme_font_size_override("font_size", 14)
	if debug_font != null:
		scenario_label.add_theme_font_override("font", debug_font)
	scenario_label.add_theme_color_override("font_color", Color.WHITE)
	debug_bar.add_child(scenario_label)

	var scenarios: Array[Dictionary] = [
		{"title": "NORMAL", "key": "normal"},
		{"title": "DIVORCE", "key": "divorce"},
		{"title": "REMARRY", "key": "remarriage"},
		{"title": "DISTANT", "key": "distant_relative"}
	]

	for i in range(scenarios.size()):
		var data: Dictionary = scenarios[i]
		var button := Button.new()
		button.text = str(data["title"])
		button.position = Vector2(12 + i * 112, 35)
		button.size = Vector2(104, 40)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		if debug_font != null:
			button.add_theme_font_override("font", debug_font)
		button.pressed.connect(_set_scenario.bind(str(data["key"])))
		debug_bar.add_child(button)

	var reset_button := Button.new()
	reset_button.text = "RESET VIEW"
	reset_button.position = Vector2(490, 35)
	reset_button.size = Vector2(110, 40)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.add_theme_font_size_override("font_size", 13)
	if debug_font != null:
		reset_button.add_theme_font_override("font", debug_font)
	reset_button.pressed.connect(_reset_view)
	debug_bar.add_child(reset_button)
	debug_bar.size.x = 614
	debug_bar.position.x = (1080.0 - debug_bar.size.x) * 0.5

func _set_scenario(scenario: String) -> void:
	if screen == null:
		return
	await screen.set_demo_scenario(scenario)
	scenario_label.text = "VISUAL TEST • " + scenario.replace("_", " ").to_upper()

func _reset_view() -> void:
	if screen != null:
		screen.reset_view()
