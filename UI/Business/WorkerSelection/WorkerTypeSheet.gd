extends Control

signal source_selected(source_type: String)
signal cancelled

const SOURCE_FAMILY := "family"
const SOURCE_NPC := "npc"

const COLOR_TEXT := Color("#1E1E1E")
const COLOR_BROWN := Color("#6D4534")
const FONT_REGULAR := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_MEDIUM := "res://Resources/Fonts/Roboto-Medium.ttf"
const FONT_SEMIBOLD := "res://Resources/Fonts/Roboto-SemiBold.ttf"
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"
const PATH_ARROW_RIGHT := "res://Resources/Icons/arrow-right.svg"

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var role_label: Label = %RoleLabel
@onready var family_button: Button = %FamilyButton
@onready var npc_button: Button = %NPCButton
@onready var backdrop_button: Button = $BackdropButton


func _ready() -> void:
	family_button.pressed.connect(func() -> void: source_selected.emit(SOURCE_FAMILY))
	npc_button.pressed.connect(func() -> void: source_selected.emit(SOURCE_NPC))
	backdrop_button.pressed.connect(_on_cancelled)
	_apply_fonts()
	_apply_button_icons()


func setup(role_name: String, is_replace: bool = false) -> void:
	if is_node_ready():
		_apply_setup(role_name, is_replace)
	else:
		call_deferred("_apply_setup", role_name, is_replace)


func _apply_setup(role_name: String, is_replace: bool) -> void:
	title_label.text = "REPLACE POSITION" if is_replace else "ASSIGN POSITION"
	subtitle_label.text = "Who would you like to choose?" if is_replace else "Who would you like to assign?"
	role_label.text = role_name


func _apply_button_icons() -> void:
	if not ResourceLoader.exists(PATH_ARROW_RIGHT):
		return
	var arrow := load(PATH_ARROW_RIGHT)
	if not arrow is Texture2D:
		return
	for button in [family_button, npc_button]:
		button.icon = arrow
		button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 28)

func _apply_fonts() -> void:
	_set_label_font(title_label, FONT_BOLD, 34, COLOR_BROWN)
	_set_label_font(subtitle_label, FONT_REGULAR, 22, COLOR_TEXT)
	_set_label_font(role_label, FONT_MEDIUM, 22, COLOR_BROWN)
	_set_button_font(family_button, FONT_SEMIBOLD, 27, COLOR_BROWN)
	_set_button_font(npc_button, FONT_SEMIBOLD, 27, COLOR_BROWN)


func _set_label_font(label: Label, path: String, size: int, color: Color) -> void:
	if ResourceLoader.exists(path):
		var font := load(path)
		if font:
			label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


func _set_button_font(button: Button, path: String, size: int, color: Color) -> void:
	if ResourceLoader.exists(path):
		var font := load(path)
		if font:
			button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", color)


func _on_cancelled() -> void:
	cancelled.emit()
	queue_free()
