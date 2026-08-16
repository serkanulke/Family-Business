extends Control

signal character_pressed(character_id: int)

const PORTRAIT_SIZE := Vector2(180.0, 180.0)
const PORTRAIT_POSITION := Vector2(0.0, -18.0)
const AGE_BADGE_SIZE := Vector2(44.0, 44.0)
const GENDER_ICON_SIZE := Vector2(44.0, 44.0)
const NAME_CARD_SIZE := Vector2(170.0, 70.0)

const MALE_ICON_PATH := "res://Resources/Icons/character-portrait/male-icon.svg"
const FEMALE_ICON_PATH := "res://Resources/Icons/character-portrait/female-icon.svg"
const LINK_ICON_PATH := "res://Resources/Icons/character-portrait/link-icon.svg"
const OUTFIT_BOLD_PATH := "res://Resources/Fonts/Outfit-Bold.ttf"
const OUTFIT_SEMIBOLD_PATH := "res://Resources/Fonts/Outfit-SemiBold.ttf"

class SoftRoundedShadow:
	extends Control
	var target_size: Vector2 = Vector2.ZERO
	var corner_radius: float = 0.0
	var blur_radius: float = 4.0
	var shadow_offset: Vector2 = Vector2.ZERO
	var shadow_opacity: float = 0.10

	func configure(
		new_size: Vector2,
		new_corner_radius: float,
		new_offset: Vector2,
		new_blur_radius: float,
		new_opacity: float
	) -> void:
		target_size = new_size
		corner_radius = new_corner_radius
		shadow_offset = new_offset
		blur_radius = maxf(new_blur_radius, 0.0)
		shadow_opacity = clampf(new_opacity, 0.0, 1.0)
		size = target_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		if target_size.x <= 0.0 or target_size.y <= 0.0:
			return

		var layer_count: int = maxi(8, int(ceil(blur_radius * 2.0)))
		var layer_alpha: float = shadow_opacity / float(layer_count)

		for layer_index in range(layer_count, 0, -1):
			var factor: float = float(layer_index) / float(layer_count)
			var spread: float = blur_radius * factor
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.0, 0.0, 0.0, layer_alpha)
			var radius: int = int(round(corner_radius + spread))
			style.corner_radius_top_left = radius
			style.corner_radius_top_right = radius
			style.corner_radius_bottom_left = radius
			style.corner_radius_bottom_right = radius
			style.anti_aliasing = true
			draw_style_box(
				style,
				Rect2(
					shadow_offset - Vector2(spread, spread),
					target_size + Vector2(spread * 2.0, spread * 2.0)
				)
			)

class SoftCircleShadow:
	extends Control
	var diameter: float = 44.0
	var blur_radius: float = 10.0
	var shadow_offset: Vector2 = Vector2(4.0, 4.0)
	var shadow_opacity: float = 0.25

	func configure(
		new_diameter: float,
		new_offset: Vector2,
		new_blur_radius: float,
		new_opacity: float
	) -> void:
		diameter = maxf(new_diameter, 1.0)
		shadow_offset = new_offset
		blur_radius = maxf(new_blur_radius, 0.0)
		shadow_opacity = clampf(new_opacity, 0.0, 1.0)
		size = Vector2(diameter, diameter)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var base_radius: float = diameter * 0.5
		var center := Vector2(base_radius, base_radius) + shadow_offset
		var layer_count: int = maxi(10, int(ceil(blur_radius * 2.0)))

		for layer_index in range(layer_count, 0, -1):
			var t: float = float(layer_index) / float(layer_count)
			var spread: float = blur_radius * t
			var falloff: float = 1.0 - t
			var alpha: float = shadow_opacity * (0.018 + 0.055 * falloff * falloff)
			draw_circle(
				center,
				base_radius + spread,
				Color(0.0, 0.0, 0.0, alpha),
				true,
				-1.0,
				true
			)

class SoftTextureShadow:
	extends Control
	var shadow_texture: Texture2D
	var target_size: Vector2 = Vector2.ZERO
	var blur_radius: float = 4.0
	var shadow_offset: Vector2 = Vector2.ZERO
	var shadow_opacity: float = 0.10

	func configure(
		new_texture: Texture2D,
		new_size: Vector2,
		new_offset: Vector2,
		new_blur_radius: float,
		new_opacity: float
	) -> void:
		shadow_texture = new_texture
		target_size = new_size
		shadow_offset = new_offset
		blur_radius = maxf(new_blur_radius, 0.0)
		shadow_opacity = clampf(new_opacity, 0.0, 1.0)
		size = target_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		if shadow_texture == null:
			return

		var ring_count: int = maxi(2, int(ceil(blur_radius / 2.0)))
		var samples_per_ring: int = 12
		var sample_count: int = 1 + ring_count * samples_per_ring
		var sample_alpha: float = shadow_opacity / float(sample_count)
		var tint := Color(0.0, 0.0, 0.0, sample_alpha)

		draw_texture_rect(
			shadow_texture,
			Rect2(shadow_offset, target_size),
			false,
			tint
		)

		for ring_index in range(1, ring_count + 1):
			var radius: float = blur_radius * float(ring_index) / float(ring_count)
			for sample_index in range(samples_per_ring):
				var angle: float = TAU * float(sample_index) / float(samples_per_ring)
				var sample_offset := shadow_offset + Vector2(cos(angle), sin(angle)) * radius
				draw_texture_rect(
					shadow_texture,
					Rect2(sample_offset, target_size),
					false,
					tint
				)

@onready var hit_button: Button = $HitButton

var character_id: int = 0
var is_alive: bool = true
var is_reference_node: bool = false

var visual_root: Control
var portrait_shadow: SoftTextureShadow
var portrait: TextureRect
var age_shadow: SoftCircleShadow
var age_badge: Panel
var age_label: Label
var gender_shadow: SoftTextureShadow
var gender_icon: TextureRect
var reference_shadow: SoftTextureShadow
var reference_link_icon: TextureRect
var name_shadow: SoftRoundedShadow
var name_panel: Panel
var name_label: Label
var money_label: Label

var outfit_bold: FontFile
var outfit_semibold: FontFile


func _ready() -> void:
	outfit_bold = load(OUTFIT_BOLD_PATH) as FontFile
	outfit_semibold = load(OUTFIT_SEMIBOLD_PATH) as FontFile
	_build_visuals()

	if not hit_button.pressed.is_connected(_on_hit_button_pressed):
		hit_button.pressed.connect(_on_hit_button_pressed)

	if not TimeManager.date_changed.is_connected(_on_date_changed):
		TimeManager.date_changed.connect(_on_date_changed)


func _build_visuals() -> void:
	visual_root = Control.new()
	visual_root.name = "VisualRoot"
	visual_root.position = Vector2.ZERO
	visual_root.size = Vector2(180.0, 250.0)
	visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual_root)
	move_child(visual_root, 0)

	portrait_shadow = SoftTextureShadow.new()
	portrait_shadow.position = PORTRAIT_POSITION
	visual_root.add_child(portrait_shadow)

	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.position = PORTRAIT_POSITION
	portrait.size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual_root.add_child(portrait)

	age_shadow = SoftCircleShadow.new()
	age_shadow.position = Vector2(-4.0, -22.0)
	age_shadow.configure(44.0, Vector2(4.0, 4.0), 10.0, 0.25)
	visual_root.add_child(age_shadow)

	age_badge = Panel.new()
	age_badge.position = Vector2(-4.0, -22.0)
	age_badge.size = AGE_BADGE_SIZE
	age_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var age_style := StyleBoxFlat.new()
	age_style.bg_color = Color.WHITE
	age_style.corner_radius_top_left = 22
	age_style.corner_radius_top_right = 22
	age_style.corner_radius_bottom_left = 22
	age_style.corner_radius_bottom_right = 22
	age_style.anti_aliasing = true
	age_badge.add_theme_stylebox_override("panel", age_style)
	visual_root.add_child(age_badge)

	age_label = Label.new()
	age_label.position = Vector2.ZERO
	age_label.size = AGE_BADGE_SIZE
	age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	age_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	age_label.add_theme_font_size_override("font_size", 24)
	if outfit_bold != null:
		age_label.add_theme_font_override("font", outfit_bold)
	age_label.add_theme_color_override("font_color", Color("#312F60"))
	age_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	age_badge.add_child(age_label)

	gender_shadow = SoftTextureShadow.new()
	gender_shadow.position = Vector2(136.0, 114.0)
	visual_root.add_child(gender_shadow)

	gender_icon = TextureRect.new()
	gender_icon.position = Vector2(136.0, 114.0)
	gender_icon.size = GENDER_ICON_SIZE
	gender_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gender_icon.stretch_mode = TextureRect.STRETCH_SCALE
	gender_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual_root.add_child(gender_icon)

	reference_shadow = SoftTextureShadow.new()
	reference_shadow.position = Vector2(136.0, -22.0)
	visual_root.add_child(reference_shadow)

	reference_link_icon = TextureRect.new()
	reference_link_icon.position = Vector2(136.0, -22.0)
	reference_link_icon.size = GENDER_ICON_SIZE
	reference_link_icon.texture = load(LINK_ICON_PATH) as Texture2D
	reference_link_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference_link_icon.stretch_mode = TextureRect.STRETCH_SCALE
	reference_link_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference_link_icon.visible = false
	visual_root.add_child(reference_link_icon)

	name_shadow = SoftRoundedShadow.new()
	name_shadow.position = Vector2(5.0, 172.0)
	name_shadow.configure(
		NAME_CARD_SIZE,
		35.0,
		Vector2(0.0, 4.0),
		8.0,
		0.10
	)
	visual_root.add_child(name_shadow)

	name_panel = Panel.new()
	name_panel.position = Vector2(5.0, 172.0)
	name_panel.size = NAME_CARD_SIZE
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_style := StyleBoxFlat.new()
	name_style.bg_color = Color.WHITE
	name_style.corner_radius_top_left = 35
	name_style.corner_radius_top_right = 35
	name_style.corner_radius_bottom_left = 35
	name_style.corner_radius_bottom_right = 35
	name_style.anti_aliasing = true
	name_panel.add_theme_stylebox_override("panel", name_style)
	visual_root.add_child(name_panel)

	name_label = Label.new()
	name_label.position = Vector2(0.0, 7.0)
	name_label.size = Vector2(170.0, 28.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	if outfit_semibold != null:
		name_label.add_theme_font_override("font", outfit_semibold)
	name_label.add_theme_color_override("font_color", Color("#312F60"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_child(name_label)

	money_label = Label.new()
	money_label.position = Vector2(0.0, 31.0)
	money_label.size = Vector2(170.0, 31.0)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 24)
	if outfit_semibold != null:
		money_label.add_theme_font_override("font", outfit_semibold)
	money_label.add_theme_color_override("font_color", Color("#047D48"))
	money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_child(money_label)


func setup_character(character: Dictionary, reference_mode: bool = false) -> void:
	if visual_root == null:
		return

	character_id = int(character.get("character_id", 0))
	is_alive = bool(character.get("is_alive", true))
	is_reference_node = reference_mode

	name_label.text = String(character.get("first_name", ""))

	var age: int = CharacterManager.get_character_age(character)
	age_label.text = str(maxi(age, 0))

	var avatar_texture: Texture2D = CharacterManager.get_avatar_texture(character)
	portrait.texture = avatar_texture
	portrait_shadow.configure(
		avatar_texture,
		PORTRAIT_SIZE,
		Vector2(0.0, 4.0),
		4.0,
		0.10
	)

	var gender: String = String(character.get("gender", "male")).to_lower()
	var gender_path: String = FEMALE_ICON_PATH if gender == "female" else MALE_ICON_PATH
	var gender_texture := load(gender_path) as Texture2D
	gender_icon.texture = gender_texture
	gender_shadow.configure(
		gender_texture,
		GENDER_ICON_SIZE,
		Vector2(-4.0, -4.0),
		10.0,
		0.25
	)

	var link_texture := load(LINK_ICON_PATH) as Texture2D
	reference_link_icon.visible = is_reference_node
	reference_shadow.visible = is_reference_node
	reference_shadow.configure(
		link_texture,
		GENDER_ICON_SIZE,
		Vector2(-4.0, 4.0),
		10.0,
		0.25
	)

	var money_text: String = _get_character_monthly_money_text(character)
	money_label.text = money_text
	money_label.visible = not money_text.is_empty()

	if money_text.is_empty():
		name_label.position = Vector2(0.0, 0.0)
		name_label.size = NAME_CARD_SIZE
	else:
		name_label.position = Vector2(0.0, 7.0)
		name_label.size = Vector2(170.0, 28.0)

	visual_root.modulate.a = 1.0 if is_alive else 0.42


func _get_character_monthly_money_text(character: Dictionary) -> String:
	var amount: int = 0

	if bool(character.get("is_retired", false)):
		amount = int(character.get("pension", 0))
	else:
		amount = int(character.get("salary", 0))

	if amount <= 0:
		return ""

	return "+%s/mo" % _format_compact_amount(amount)


func _format_compact_amount(amount: int) -> String:
	var absolute_amount: int = absi(amount)

	if absolute_amount >= 1000000:
		var millions: float = float(absolute_amount) / 1000000.0
		return _format_short_decimal(millions) + "M"

	if absolute_amount >= 1000:
		var thousands: float = float(absolute_amount) / 1000.0
		return _format_short_decimal(thousands) + "k"

	return str(absolute_amount)


func _format_short_decimal(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))

	return "%.1f" % value


func _on_date_changed(_date_text: String) -> void:
	if character_id <= 0:
		return

	var character: Dictionary = CharacterManager.get_character_by_id(character_id)
	if character.is_empty():
		return

	setup_character(character, is_reference_node)


func _on_hit_button_pressed() -> void:
	if character_id <= 0:
		return

	character_pressed.emit(character_id)
