extends Control
class_name MainHUD

signal screen_requested(screen_id: String)

const CALENDAR_PATH := "res://Resources/Icons/main-ui/calendar.svg"
const SHOP_BTN_PATH := "res://Resources/Icons/main-ui/shop-btn.svg"
const SETTINGS_BTN_PATH := "res://Resources/Icons/main-ui/settings-btn.svg"
const COIN_PATH := "res://Resources/Icons/main-ui/coin.png"
const DIAMOND_PATH := "res://Resources/Icons/main-ui/diamond.png"
const NAV_LIFESTYLE_ACTIVE_PATH := "res://Resources/Icons/nav/lifestyle-btn.webp"
const NAV_LIFESTYLE_INACTIVE_PATH := "res://Resources/Icons/nav/lifestyle-btn-deact.webp"
const NAV_FAMILY_TREE_ACTIVE_PATH := "res://Resources/Icons/nav/fam-tree-btn.webp"
const NAV_FAMILY_TREE_INACTIVE_PATH := "res://Resources/Icons/nav/fam-tree-btn-deact.webp"
const NAV_MAP_ACTIVE_PATH := "res://Resources/Icons/nav/map-btn.webp"
const NAV_MAP_INACTIVE_PATH := "res://Resources/Icons/nav/map-btn-deact.webp"
const OUTFIT_BOLD_PATH := "res://Resources/Fonts/Outfit-Bold.ttf"
const OUTFIT_SEMIBOLD_PATH := "res://Resources/Fonts/Outfit-SemiBold.ttf"
const CANVAS_SIZE := Vector2(1080.0, 1920.0)
const TOP_MARGIN := 34.0
const SIDE_MARGIN := 36.0
const NAV_BOTTOM_MARGIN := 44.0
const SHOP_SETTINGS_GAP := 32.0
const BUTTON_LABEL_GAP := 8.0

class SoftTextureShadow:
	extends Control
	var shadow_texture: Texture2D
	var target_size := Vector2.ZERO
	var blur_radius := 4.0
	var shadow_offset := Vector2.ZERO
	var shadow_opacity := 0.10

	func configure(texture: Texture2D, new_size: Vector2, offset: Vector2, radius: float, opacity: float) -> void:
		shadow_texture = texture
		target_size = new_size
		shadow_offset = offset
		blur_radius = maxf(radius, 0.0)
		shadow_opacity = clampf(opacity, 0.0, 1.0)
		size = target_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		if shadow_texture == null: return
		var ring_count := maxi(2, int(ceil(blur_radius / 2.0)))
		var samples_per_ring := 12
		var sample_alpha := shadow_opacity / float(1 + ring_count * samples_per_ring)
		var tint := Color(0.0, 0.0, 0.0, sample_alpha)
		draw_texture_rect(shadow_texture, Rect2(shadow_offset, target_size), false, tint)
		for ring_index in range(1, ring_count + 1):
			var radius := blur_radius * float(ring_index) / float(ring_count)
			for sample_index in range(samples_per_ring):
				var angle := TAU * float(sample_index) / float(samples_per_ring)
				draw_texture_rect(shadow_texture, Rect2(shadow_offset + Vector2(cos(angle), sin(angle)) * radius, target_size), false, tint)

var outfit_bold: FontFile
var outfit_semibold: FontFile
var date_pill: PanelContainer
var date_value_label: Label
var coin_pill: PanelContainer
var coin_value_label: Label
var diamond_pill: PanelContainer
var diamond_value_label: Label
var shop_block: Control
var settings_block: Control
var nav_root: Control
var active_screen_id := "family_tree"


func _ready() -> void:
	custom_minimum_size = CANVAS_SIZE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	outfit_bold = load(OUTFIT_BOLD_PATH) as FontFile
	outfit_semibold = load(OUTFIT_SEMIBOLD_PATH) as FontFile
	_build_global_ui()
	_connect_runtime_signals()
	refresh_from_managers()
	call_deferred("_layout_ui")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree(): _layout_ui()


func set_active_screen(screen_id: String) -> void:
	if screen_id == active_screen_id and nav_root != null: return
	active_screen_id = screen_id
	if nav_root != null:
		nav_root.queue_free()
		nav_root = null
	_create_and_add_navigation()
	_layout_ui()


func refresh_from_managers() -> void:
	if date_value_label != null: date_value_label.text = TimeManager.get_date_string()
	if coin_value_label != null: coin_value_label.text = _format_compact_number(GameManager.family_money)
	if diamond_value_label != null: diamond_value_label.text = _format_compact_number(GameManager.diamonds)
	call_deferred("_layout_ui")


func _build_global_ui() -> void:
	var date_result := _create_info_pill(CALENDAR_PATH, TimeManager.get_date_string())
	date_pill = date_result["pill"]
	date_pill.name = "DatePill"
	date_value_label = date_result["label"]
	date_value_label.name = "DateValue"
	add_child(date_pill)
	shop_block = _create_vertical_icon_button(SHOP_BTN_PATH, "SHOP")
	shop_block.name = "ShopButtonBlock"
	add_child(shop_block)
	settings_block = _create_vertical_icon_button(SETTINGS_BTN_PATH, "SETTINGS")
	settings_block.name = "SettingsButtonBlock"
	add_child(settings_block)
	var coin_result := _create_info_pill(COIN_PATH, _format_compact_number(GameManager.family_money))
	coin_pill = coin_result["pill"]
	coin_pill.name = "CoinPill"
	coin_value_label = coin_result["label"]
	coin_value_label.name = "CoinValue"
	add_child(coin_pill)
	var diamond_result := _create_info_pill(DIAMOND_PATH, _format_compact_number(GameManager.diamonds))
	diamond_pill = diamond_result["pill"]
	diamond_pill.name = "DiamondPill"
	diamond_value_label = diamond_result["label"]
	diamond_value_label.name = "DiamondValue"
	add_child(diamond_pill)
	_create_and_add_navigation()


func _create_and_add_navigation() -> void:
	nav_root = _create_nav_bar()
	nav_root.name = "BottomNavigation"
	add_child(nav_root)


func _connect_runtime_signals() -> void:
	if not TimeManager.date_changed.is_connected(_on_date_changed): TimeManager.date_changed.connect(_on_date_changed)
	if not GameManager.family_money_changed.is_connected(_on_family_money_changed): GameManager.family_money_changed.connect(_on_family_money_changed)
	if not GameManager.diamonds_changed.is_connected(_on_diamonds_changed): GameManager.diamonds_changed.connect(_on_diamonds_changed)
	if not GameManager.new_game_started.is_connected(_on_new_game_started): GameManager.new_game_started.connect(_on_new_game_started)


func _create_info_pill(icon_path: String, value_text: String) -> Dictionary:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _make_stylebox(Color("#EBF5EF"), 48.0, Color(0, 0, 0, 0.10), Vector2(0, 4), 4))
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]: margin.add_theme_constant_override(side, 28)
	for side in ["margin_top", "margin_bottom"]: margin.add_theme_constant_override(side, 18)
	pill.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	margin.add_child(hbox)
	var texture := _load_texture(icon_path)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_size := texture.get_size() if texture != null else Vector2(36, 40)
	icon.custom_minimum_size = icon_size
	icon.size = icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)
	var label := Label.new()
	label.text = value_text
	label.add_theme_font_size_override("font_size", 36)
	if outfit_bold != null: label.add_theme_font_override("font", outfit_bold)
	label.add_theme_color_override("font_color", Color("#312F60"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(label)
	return {"pill": pill, "label": label}


func _create_vertical_icon_button(texture_path: String, caption: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(112, 116)
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := _load_texture(texture_path)
	var icon_size := texture.get_size() if texture != null else Vector2(84, 84)
	var shadow := TextureRect.new()
	shadow.texture = texture
	shadow.position = Vector2((root.size.x - icon_size.x) * 0.5, 4)
	shadow.size = icon_size
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.modulate = Color(0, 0, 0, 0.10)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)
	var button := TextureButton.new()
	button.texture_normal = texture
	button.texture_pressed = texture
	button.texture_hover = texture
	button.position = Vector2((root.size.x - icon_size.x) * 0.5, 0)
	button.size = icon_size
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	root.add_child(button)
	var label := Label.new()
	label.text = caption
	label.position = Vector2(0, icon_size.y + BUTTON_LABEL_GAP)
	label.size = Vector2(root.size.x, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	if outfit_semibold != null: label.add_theme_font_override("font", outfit_semibold)
	label.add_theme_color_override("font_color", Color("#454698"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return root


func _create_nav_bar() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(800, 144)
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := Panel.new()
	background.size = root.size
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.add_theme_stylebox_override("panel", _make_stylebox(Color(1, 1, 1, 0.70), 72, Color(0, 0, 0, 0.10), Vector2(0, 16), 32))
	root.add_child(background)
	var entries: Array[Dictionary] = [
		{"id": "lifestyle", "label": "LIFESTYLE", "active_path": NAV_LIFESTYLE_ACTIVE_PATH, "inactive_path": NAV_LIFESTYLE_INACTIVE_PATH},
		{"id": "family_tree", "label": "FAMILY TREE", "active_path": NAV_FAMILY_TREE_ACTIVE_PATH, "inactive_path": NAV_FAMILY_TREE_INACTIVE_PATH},
		{"id": "map", "label": "MAP", "active_path": NAV_MAP_ACTIVE_PATH, "inactive_path": NAV_MAP_INACTIVE_PATH}
	]
	var section_width := root.size.x / 3.0
	var label_top := root.size.y - 20.0 - 30.0
	var icon_bottom := label_top - BUTTON_LABEL_GAP
	for index in range(entries.size()):
		var entry := entries[index]
		var is_active := str(entry["id"]) == active_screen_id
		var item := Control.new()
		item.position = Vector2(section_width * index, 0)
		item.size = Vector2(section_width, root.size.y)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(item)
		var texture := _load_texture(str(entry["active_path"] if is_active else entry["inactive_path"]))
		var icon_size := Vector2(132, 132) if is_active else Vector2(110, 110)
		var icon_position := Vector2((section_width - icon_size.x) * 0.5, icon_bottom - icon_size.y)
		if not is_active and texture != null:
			var soft_shadow := SoftTextureShadow.new()
			soft_shadow.position = icon_position
			soft_shadow.configure(texture, icon_size, Vector2(0, 4), 4, 0.10)
			item.add_child(soft_shadow)
		var icon := TextureRect.new()
		icon.name = str(entry["id"]).to_pascal_case() + "Icon"
		icon.texture = texture
		icon.position = icon_position
		icon.size = icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(icon)
		var label := Label.new()
		label.text = str(entry["label"])
		label.position = Vector2(0, label_top)
		label.size = Vector2(section_width, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		if outfit_semibold != null: label.add_theme_font_override("font", outfit_semibold)
		label.add_theme_color_override("font_color", Color("#3528BD") if is_active else Color("#454698"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(label)
		var navigation_button := Button.new()
		navigation_button.name = str(entry["id"]).to_pascal_case() + "NavigationButton"
		navigation_button.size = item.size
		navigation_button.flat = true
		navigation_button.focus_mode = Control.FOCUS_NONE
		navigation_button.mouse_filter = Control.MOUSE_FILTER_STOP
		navigation_button.pressed.connect(_on_navigation_button_pressed.bind(str(entry["id"])))
		item.add_child(navigation_button)
	return root


func _layout_ui() -> void:
	if date_pill != null: date_pill.position = Vector2(SIDE_MARGIN, TOP_MARGIN)
	if shop_block != null: shop_block.position = Vector2(20, 180)
	if settings_block != null: settings_block.position = Vector2(20, 180 + shop_block.size.y + SHOP_SETTINGS_GAP)
	if coin_pill != null: coin_pill.position = Vector2(size.x - SIDE_MARGIN - coin_pill.size.x, TOP_MARGIN)
	if diamond_pill != null: diamond_pill.position = Vector2(size.x - SIDE_MARGIN - diamond_pill.size.x, TOP_MARGIN + coin_pill.size.y + 22)
	if nav_root != null: nav_root.position = Vector2((size.x - nav_root.size.x) * 0.5, size.y - NAV_BOTTOM_MARGIN - nav_root.size.y)


func _on_navigation_button_pressed(screen_id: String) -> void:
	screen_requested.emit(screen_id)


func _on_date_changed(value: String) -> void:
	if date_value_label != null: date_value_label.text = value
	call_deferred("_layout_ui")


func _on_family_money_changed(value: int) -> void:
	if coin_value_label != null: coin_value_label.text = _format_compact_number(value)
	call_deferred("_layout_ui")


func _on_diamonds_changed(value: int) -> void:
	if diamond_value_label != null: diamond_value_label.text = _format_compact_number(value)
	call_deferred("_layout_ui")


func _on_new_game_started(_starting_character: Dictionary) -> void:
	refresh_from_managers()


func _format_compact_number(value: int) -> String:
	var absolute_value := absi(value)
	var prefix := "-" if value < 0 else ""
	if absolute_value >= 1000000000: return prefix + _format_short_decimal(absolute_value / 1000000000.0) + "B"
	if absolute_value >= 1000000: return prefix + _format_short_decimal(absolute_value / 1000000.0) + "M"
	if absolute_value >= 1000: return prefix + _format_short_decimal(absolute_value / 1000.0) + "k"
	return str(value)


func _format_short_decimal(value: float) -> String:
	return str(int(round(value))) if is_equal_approx(value, round(value)) else "%.1f" % value


func _make_stylebox(bg_color: Color, radius: float, shadow_color: Color, shadow_offset: Vector2, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.shadow_color = shadow_color
	style.shadow_offset = shadow_offset
	style.shadow_size = shadow_size
	style.anti_aliasing = true
	return style


func _load_texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
