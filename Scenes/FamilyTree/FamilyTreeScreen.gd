extends Control
class_name FamilyTreeScreen

signal character_selected(character_id: int)
signal item_buy_requested(character_id: int, catalog_item_id: Variant, slot_context: String)
signal item_wear_requested(character_id: int, item_instance_id: Variant, slot_context: String)
signal item_unequip_requested(character_id: int, item_instance_id: Variant, slot_context: String)
signal screen_requested(screen_id: String)

const FAMILY_TREE_SCENE := preload("res://Scenes/Characters/FamilyTree.tscn")

const FAMILY_BG_PATH := "res://Resources/Icons/main-ui/family-tree-background.svg"
const CENTER_TREE_PATH := "res://Resources/Icons/main-ui/tree-img.png"
const CALENDAR_PATH := "res://Resources/Icons/main-ui/calendar.svg"
const SHOP_BTN_PATH := "res://Resources/Icons/main-ui/shop-btn.svg"
const SETTINGS_BTN_PATH := "res://Resources/Icons/main-ui/settings-btn.svg"
const COIN_PATH := "res://Resources/Icons/main-ui/coin.png"
const DIAMOND_PATH := "res://Resources/Icons/main-ui/diamond.png"
const FAMILY_TREE_LOGO_PATH := "res://Resources/Icons/main-ui/family-logo-tree.png"
const FAMILY_BOTTOM_LOGO_PATH := "res://Resources/Icons/main-ui/family-logo-bottom.svg"

const TIME_BG_PATH := "res://Resources/Icons/time-control/time-control-bg.png"
const PAUSE_ACTIVE_PATH := "res://Resources/Icons/time-control/pause-btn.svg"
const PAUSE_INACTIVE_PATH := "res://Resources/Icons/time-control/pause-btn-deactive.svg"
const PLAY_ACTIVE_PATH := "res://Resources/Icons/time-control/play-btn.svg"
const PLAY_INACTIVE_PATH := "res://Resources/Icons/time-control/play-btn-deactive.svg"
const X2_ACTIVE_PATH := "res://Resources/Icons/time-control/x2-btn.svg"
const X2_INACTIVE_PATH := "res://Resources/Icons/time-control/x2-btn-deactive.svg"
const X3_ACTIVE_PATH := "res://Resources/Icons/time-control/x3-btn.svg"
const X3_INACTIVE_PATH := "res://Resources/Icons/time-control/x3-btn-deactive.svg"

const NAV_LIFESTYLE_ACTIVE_PATH := "res://Resources/Icons/nav/lifestyle-btn.webp"
const NAV_LIFESTYLE_INACTIVE_PATH := "res://Resources/Icons/nav/lifestyle-btn-deact.webp"
const NAV_FAMILY_TREE_ACTIVE_PATH := "res://Resources/Icons/nav/fam-tree-btn.webp"
const NAV_FAMILY_TREE_INACTIVE_PATH := "res://Resources/Icons/nav/fam-tree-btn-deact.webp"
const NAV_MAP_ACTIVE_PATH := "res://Resources/Icons/nav/map-btn.webp"
const NAV_MAP_INACTIVE_PATH := "res://Resources/Icons/nav/map-btn-deact.webp"

const OUTFIT_BOLD_PATH := "res://Resources/Fonts/Outfit-Bold.ttf"
const OUTFIT_SEMIBOLD_PATH := "res://Resources/Fonts/Outfit-SemiBold.ttf"
const BUENARD_BOLD_PATH := "res://Resources/Fonts/Buenard-Bold.ttf"

const CANVAS_SIZE := Vector2(1080.0, 1920.0)
const TOP_MARGIN := 34.0
const SIDE_MARGIN := 36.0
const NAV_BOTTOM_MARGIN := 44.0
const TIME_CONTROL_BOTTOM_MARGIN := 344.0
const SHOP_SETTINGS_GAP := 32.0
const BUTTON_LABEL_GAP := 8.0

const FAMILY_LOGO_SIZE := Vector2(560.0, 190.0)
const FAMILY_LOGO_POSITION := Vector2(260.0, 170.0)
const TREE_ORIGIN := Vector2(540.0, 590.0)

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

@export var family_name: String = "FAMILY"

var outfit_bold: FontFile
var outfit_semibold: FontFile
var buenard_bold: FontFile

var background_layer: CanvasLayer
var hud_layer: CanvasLayer
var background_root: Control
var fixed_ui_root: Control
var background_rect: TextureRect
var center_tree_rect: TextureRect

var family_tree_world: Node2D
var family_tree_camera: Camera2D
var family_logo_root: Control
var family_name_label: Label

var date_pill: PanelContainer
var date_value_label: Label
var coin_pill: PanelContainer
var coin_value_label: Label
var diamond_pill: PanelContainer
var diamond_value_label: Label
var shop_block: Control
var settings_block: Control
var time_control_root: Control
var nav_root: Control

var pause_button: TextureButton
var play_button: TextureButton
var x2_button: TextureButton
var x3_button: TextureButton


func _ready() -> void:
	custom_minimum_size = CANVAS_SIZE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	outfit_bold = load(OUTFIT_BOLD_PATH) as FontFile
	outfit_semibold = load(OUTFIT_SEMIBOLD_PATH) as FontFile
	buenard_bold = load(BUENARD_BOLD_PATH) as FontFile

	_build_background()
	_build_real_family_tree()
	_build_fixed_ui()
	_connect_runtime_signals()
	_connect_item_list_shop()
	_refresh_runtime_values()

	await get_tree().process_frame
	_update_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_update_layout()


func _build_background() -> void:
	background_layer = CanvasLayer.new()
	background_layer.name = "BackgroundLayer"
	background_layer.layer = -10
	add_child(background_layer)

	background_root = Control.new()
	background_root.name = "BackgroundRoot"
	background_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_layer.add_child(background_root)

	background_rect = TextureRect.new()
	background_rect.name = "Background"
	background_rect.texture = _load_texture(FAMILY_BG_PATH)
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.stretch_mode = TextureRect.STRETCH_SCALE
	background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_root.add_child(background_rect)

	center_tree_rect = TextureRect.new()
	center_tree_rect.name = "CenterTreeImage"
	center_tree_rect.texture = _load_texture(CENTER_TREE_PATH)
	center_tree_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	center_tree_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center_tree_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_root.add_child(center_tree_rect)


func _build_real_family_tree() -> void:
	var tree_instance := FAMILY_TREE_SCENE.instantiate()
	family_tree_world = tree_instance as Node2D

	if family_tree_world == null:
		push_error("Production Family Tree scene could not be instantiated.")
		return

	family_tree_world.set("tree_origin", TREE_ORIGIN)
	family_tree_world.set("connection_color", Color(1.0, 1.0, 1.0, 0.95))
	family_tree_world.set("connection_width", 4.0)
	family_tree_world.set("partner_spacing", 180.0)
	family_tree_world.set("generation_spacing", 320.0)

	family_tree_camera = family_tree_world.get_node_or_null("Camera2D") as Camera2D
	if family_tree_camera != null:
		family_tree_camera.set("center_small_content", false)
		family_tree_camera.set("default_position", Vector2(540.0, 960.0))
		family_tree_camera.set("bounds_padding", Vector2(220.0, 320.0))

	if family_tree_world.has_signal("character_selected"):
		family_tree_world.connect(
			"character_selected",
			_on_family_tree_character_selected
		)

	add_child(family_tree_world)

	family_logo_root = _create_family_logo()
	family_logo_root.name = "FamilyLogo"
	family_logo_root.position = FAMILY_LOGO_POSITION
	family_logo_root.z_index = 3
	family_tree_world.add_child(family_logo_root)


func _build_fixed_ui() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	hud_layer.layer = 10
	add_child(hud_layer)

	fixed_ui_root = Control.new()
	fixed_ui_root.name = "FixedUIRoot"
	fixed_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	fixed_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(fixed_ui_root)

	var date_result: Dictionary = _create_info_pill(CALENDAR_PATH, TimeManager.get_date_string())
	date_pill = date_result["pill"]
	date_value_label = date_result["label"]
	fixed_ui_root.add_child(date_pill)

	shop_block = _create_vertical_icon_button(SHOP_BTN_PATH, "SHOP")
	fixed_ui_root.add_child(shop_block)

	settings_block = _create_vertical_icon_button(SETTINGS_BTN_PATH, "SETTINGS")
	fixed_ui_root.add_child(settings_block)

	var coin_result: Dictionary = _create_info_pill(COIN_PATH, _format_compact_number(GameManager.family_money))
	coin_pill = coin_result["pill"]
	coin_value_label = coin_result["label"]
	fixed_ui_root.add_child(coin_pill)

	var diamond_result: Dictionary = _create_info_pill(DIAMOND_PATH, _format_compact_number(GameManager.diamonds))
	diamond_pill = diamond_result["pill"]
	diamond_value_label = diamond_result["label"]
	fixed_ui_root.add_child(diamond_pill)

	time_control_root = _create_time_controls()
	fixed_ui_root.add_child(time_control_root)

	nav_root = _create_nav_bar()
	fixed_ui_root.add_child(nav_root)


func _connect_runtime_signals() -> void:
	if not TimeManager.date_changed.is_connected(_on_date_changed):
		TimeManager.date_changed.connect(_on_date_changed)

	if TimeManager.has_signal("pause_state_changed"):
		if not TimeManager.is_connected("pause_state_changed", _on_pause_state_changed):
			TimeManager.connect("pause_state_changed", _on_pause_state_changed)

	if TimeManager.has_signal("speed_changed"):
		if not TimeManager.is_connected("speed_changed", _on_speed_changed):
			TimeManager.connect("speed_changed", _on_speed_changed)

	if not GameManager.family_money_changed.is_connected(_on_family_money_changed):
		GameManager.family_money_changed.connect(_on_family_money_changed)

	if not GameManager.diamonds_changed.is_connected(_on_diamonds_changed):
		GameManager.diamonds_changed.connect(_on_diamonds_changed)

	if not GameManager.new_game_started.is_connected(_on_new_game_started):
		GameManager.new_game_started.connect(_on_new_game_started)


func _connect_item_list_shop() -> void:
	var character_card := get_node_or_null("CharacterCard")
	var item_list_sheet := get_node_or_null("ItemListBottomSheet")
	if character_card == null or item_list_sheet == null:
		return
	if item_list_sheet.has_method("set_data_provider"):
		item_list_sheet.call("set_data_provider", ItemManager)
	if character_card.has_signal("item_slot_requested"):
		if not character_card.is_connected("item_slot_requested", _on_character_card_item_slot_requested):
			character_card.connect("item_slot_requested", _on_character_card_item_slot_requested)
	if item_list_sheet.has_signal("sheet_closed"):
		if not item_list_sheet.is_connected("sheet_closed", _on_item_list_sheet_closed):
			item_list_sheet.connect("sheet_closed", _on_item_list_sheet_closed)
	if item_list_sheet.has_signal("item_buy_requested"):
		if not item_list_sheet.is_connected("item_buy_requested", _on_item_buy_requested):
			item_list_sheet.connect("item_buy_requested", _on_item_buy_requested)
	if item_list_sheet.has_signal("item_wear_requested"):
		if not item_list_sheet.is_connected("item_wear_requested", _on_item_wear_requested):
			item_list_sheet.connect("item_wear_requested", _on_item_wear_requested)
	if item_list_sheet.has_signal("item_unequip_requested"):
		if not item_list_sheet.is_connected("item_unequip_requested", _on_item_unequip_requested):
			item_list_sheet.connect("item_unequip_requested", _on_item_unequip_requested)
	for signal_name in ["monthly_stock_changed", "inventory_changed", "equipment_changed"]:
		if ItemManager.has_signal(signal_name) and not ItemManager.is_connected(signal_name, _on_item_manager_state_changed):
			ItemManager.connect(signal_name, _on_item_manager_state_changed)


func refresh_from_managers() -> void:
	_refresh_runtime_values()

	if (
		family_tree_world != null
		and family_tree_world.has_method("rebuild_tree")
	):
		family_tree_world.call("rebuild_tree")

	call_deferred("_update_layout")


func _refresh_runtime_values() -> void:
	if date_value_label != null:
		date_value_label.text = TimeManager.get_date_string()

	if coin_value_label != null:
		coin_value_label.text = _format_compact_number(GameManager.family_money)

	if diamond_value_label != null:
		diamond_value_label.text = _format_compact_number(GameManager.diamonds)

	if family_name_label != null:
		family_name_label.text = family_name

	_update_time_button_visuals()
	call_deferred("_layout_fixed_ui")


func _on_date_changed(new_date_text: String) -> void:
	if date_value_label != null:
		date_value_label.text = new_date_text

	# Character portrait nodes listen to the same date signal and refresh
	# their real age/salary values without rebuilding the genealogy layout.
	call_deferred("_layout_fixed_ui")


func _on_family_money_changed(new_amount: int) -> void:
	if coin_value_label != null:
		coin_value_label.text = _format_compact_number(new_amount)
	call_deferred("_layout_fixed_ui")


func _on_diamonds_changed(new_amount: int) -> void:
	if diamond_value_label != null:
		diamond_value_label.text = _format_compact_number(new_amount)
	call_deferred("_layout_fixed_ui")


func _on_new_game_started(_starting_character: Dictionary) -> void:
	refresh_from_managers()


func _on_pause_state_changed(_paused: bool) -> void:
	_update_time_button_visuals()


func _on_speed_changed(_speed: float) -> void:
	_update_time_button_visuals()


func _on_family_tree_character_selected(character_id: int) -> void:
	var character_card := get_node_or_null("CharacterCard")

	if (
		character_card != null
		and character_card.has_method("open_for_character")
	):
		character_card.call(
			"open_for_character",
			character_id
		)

	character_selected.emit(character_id)


func _on_character_card_item_slot_requested(slot_type: String, character_id: int) -> void:
	var character_card := get_node_or_null("CharacterCard")
	var item_list_sheet := get_node_or_null("ItemListBottomSheet")
	if item_list_sheet == null or not item_list_sheet.has_method("open_for_character"):
		return
	if character_card != null and character_card.has_method("close_card"):
		character_card.call("close_card")
	item_list_sheet.call("open_for_character", character_id, slot_type)


func _on_item_list_sheet_closed(character_id: int, _slot_context: String) -> void:
	var character_card := get_node_or_null("CharacterCard")
	if character_id > 0 and character_card != null and character_card.has_method("open_for_character"):
		character_card.call("open_for_character", character_id)


func _on_item_buy_requested(character_id: int, catalog_item_id: Variant, slot_type: String) -> void:
	ItemManager.purchase_item(str(catalog_item_id))
	_refresh_open_item_sheet()
	item_buy_requested.emit(character_id, catalog_item_id, slot_type)


func _on_item_wear_requested(character_id: int, item_instance_id: Variant, slot_type: String) -> void:
	ItemManager.equip_item(character_id, str(item_instance_id), slot_type)
	_refresh_open_item_sheet()
	item_wear_requested.emit(character_id, item_instance_id, slot_type)


func _on_item_unequip_requested(character_id: int, item_instance_id: Variant, slot_type: String) -> void:
	ItemManager.unequip_item(character_id, slot_type, str(item_instance_id))
	_refresh_open_item_sheet()
	item_unequip_requested.emit(character_id, item_instance_id, slot_type)


func _on_item_manager_state_changed(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
	_refresh_open_item_sheet()


func _refresh_open_item_sheet() -> void:
	var item_list_sheet := get_node_or_null("ItemListBottomSheet")
	if item_list_sheet != null and item_list_sheet.visible and item_list_sheet.has_method("refresh_data"):
		item_list_sheet.call("refresh_data")


func _create_family_logo() -> Control:
	var root := Control.new()
	root.custom_minimum_size = FAMILY_LOGO_SIZE
	root.size = FAMILY_LOGO_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tree_texture := _load_texture(FAMILY_TREE_LOGO_PATH)
	var tree_size := Vector2(80.0, 80.0)
	if tree_texture != null:
		tree_size = tree_texture.get_size()

	var tree_logo := TextureRect.new()
	tree_logo.texture = tree_texture
	tree_logo.position = Vector2((root.size.x - tree_size.x) * 0.5, 0.0)
	tree_logo.size = tree_size
	tree_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tree_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tree_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tree_logo)

	family_name_label = Label.new()
	family_name_label.text = family_name
	family_name_label.position = Vector2(0.0, 74.0)
	family_name_label.size = Vector2(root.size.x, 62.0)
	family_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	family_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	family_name_label.add_theme_font_size_override("font_size", 55)
	if buenard_bold != null:
		family_name_label.add_theme_font_override("font", buenard_bold)
	family_name_label.add_theme_color_override("font_color", Color("#063166"))
	family_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(family_name_label)

	var bottom_texture := _load_texture(FAMILY_BOTTOM_LOGO_PATH)
	var bottom_size := Vector2(333.0, 33.0)
	if bottom_texture != null:
		bottom_size = bottom_texture.get_size()

	var bottom_logo := TextureRect.new()
	bottom_logo.texture = bottom_texture
	bottom_logo.position = Vector2((root.size.x - bottom_size.x) * 0.5, 138.0)
	bottom_logo.size = bottom_size
	bottom_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bottom_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bottom_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_logo)

	return root


func _create_info_pill(icon_path: String, value_text: String) -> Dictionary:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override(
		"panel",
		_make_stylebox(
			Color("#EBF5EF"),
			48.0,
			Color(0.0, 0.0, 0.0, 0.10),
			Vector2(0.0, 4.0),
			4
		)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	pill.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	margin.add_child(hbox)

	var icon_texture := _load_texture(icon_path)
	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_size := Vector2(36.0, 40.0)
	if icon_texture != null:
		icon_size = icon_texture.get_size()
	icon.custom_minimum_size = icon_size
	icon.size = icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var label := Label.new()
	label.text = value_text
	label.add_theme_font_size_override("font_size", 36)
	if outfit_bold != null:
		label.add_theme_font_override("font", outfit_bold)
	label.add_theme_color_override("font_color", Color("#312F60"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(label)

	return {"pill": pill, "label": label}


func _create_vertical_icon_button(texture_path: String, caption: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(112.0, 116.0)
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var texture_resource := _load_texture(texture_path)
	var icon_size := Vector2(84.0, 84.0)
	if texture_resource != null:
		icon_size = texture_resource.get_size()

	var shadow := TextureRect.new()
	shadow.texture = texture_resource
	shadow.position = Vector2((root.size.x - icon_size.x) * 0.5, 4.0)
	shadow.size = icon_size
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.10)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)

	var button := TextureButton.new()
	button.texture_normal = texture_resource
	button.texture_pressed = texture_resource
	button.texture_hover = texture_resource
	button.position = Vector2((root.size.x - icon_size.x) * 0.5, 0.0)
	button.size = icon_size
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	root.add_child(button)

	var label := Label.new()
	label.text = caption
	label.position = Vector2(0.0, icon_size.y + BUTTON_LABEL_GAP)
	label.size = Vector2(root.size.x, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	if outfit_semibold != null:
		label.add_theme_font_override("font", outfit_semibold)
	label.add_theme_color_override("font_color", Color("#454698"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)

	return root


func _create_time_controls() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(456.0, 120.0)
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_resource := _load_texture(TIME_BG_PATH)
	var bg_shadow := TextureRect.new()
	bg_shadow.texture = bg_resource
	bg_shadow.position = Vector2(0.0, 4.0)
	bg_shadow.size = root.size
	bg_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_shadow.stretch_mode = TextureRect.STRETCH_SCALE
	bg_shadow.modulate = Color(0.0, 0.0, 0.0, 0.10)
	bg_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg_shadow)

	var bg := TextureRect.new()
	bg.texture = bg_resource
	bg.size = root.size
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	pause_button = _create_time_button(PAUSE_ACTIVE_PATH, PAUSE_INACTIVE_PATH, "pause")
	play_button = _create_time_button(PLAY_ACTIVE_PATH, PLAY_INACTIVE_PATH, "play")
	x2_button = _create_time_button(X2_ACTIVE_PATH, X2_INACTIVE_PATH, "x2")
	x3_button = _create_time_button(X3_ACTIVE_PATH, X3_INACTIVE_PATH, "x3")

	var buttons: Array[TextureButton] = [pause_button, play_button, x2_button, x3_button]
	var start_x: float = 24.0
	var button_size: float = 90.0
	var gap: float = 16.0

	for index in range(buttons.size()):
		var button: TextureButton = buttons[index]
		button.position = Vector2(start_x + float(index) * (button_size + gap), 15.0)
		root.add_child(button)

	_update_time_button_visuals()
	return root


func _create_time_button(active_path: String, inactive_path: String, speed_key: String) -> TextureButton:
	var button := TextureButton.new()
	button.set_meta("active_path", active_path)
	button.set_meta("inactive_path", inactive_path)
	button.set_meta("speed_key", speed_key)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.size = Vector2(90.0, 90.0)
	button.focus_mode = Control.FOCUS_NONE

	var shadow := TextureRect.new()
	shadow.name = "DropShadow"
	shadow.show_behind_parent = true
	shadow.position = Vector2(-2.0, 1.0)
	shadow.size = Vector2(94.0, 94.0)
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.20)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(shadow)

	button.pressed.connect(_on_time_button_pressed.bind(button))
	return button


func _create_nav_bar() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(800.0, 144.0)
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := Panel.new()
	background.size = root.size
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.add_theme_stylebox_override(
		"panel",
		_make_stylebox(
			Color(1.0, 1.0, 1.0, 0.70),
			72.0,
			Color(0.0, 0.0, 0.0, 0.10),
			Vector2(0.0, 16.0),
			32
		)
	)
	root.add_child(background)

	var entries: Array[Dictionary] = [
		{"label": "LIFESTYLE", "active": false, "active_path": NAV_LIFESTYLE_ACTIVE_PATH, "inactive_path": NAV_LIFESTYLE_INACTIVE_PATH},
		{"label": "FAMILY TREE", "active": true, "active_path": NAV_FAMILY_TREE_ACTIVE_PATH, "inactive_path": NAV_FAMILY_TREE_INACTIVE_PATH},
		{"label": "MAP", "active": false, "active_path": NAV_MAP_ACTIVE_PATH, "inactive_path": NAV_MAP_INACTIVE_PATH}
	]

	var section_width: float = root.size.x / 3.0
	var label_height: float = 30.0
	var label_bottom: float = root.size.y - 20.0
	var label_top: float = label_bottom - label_height
	var icon_bottom: float = label_top - BUTTON_LABEL_GAP

	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var is_active: bool = bool(entry["active"])
		var item := Control.new()
		item.position = Vector2(section_width * float(index), 0.0)
		item.size = Vector2(section_width, root.size.y)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(item)

		var texture_path: String = String(entry["active_path"] if is_active else entry["inactive_path"])
		var texture_resource := _load_texture(texture_path)
		var icon_size := Vector2(132.0, 132.0) if is_active else Vector2(110.0, 110.0)
		var icon_position := Vector2(
			(section_width - icon_size.x) * 0.5,
			icon_bottom - icon_size.y
		)

		if not is_active and texture_resource != null:
			var soft_shadow := SoftTextureShadow.new()
			soft_shadow.position = icon_position
			soft_shadow.configure(
				texture_resource,
				icon_size,
				Vector2(0.0, 4.0),
				4.0,
				0.10
			)
			item.add_child(soft_shadow)

		var icon := TextureRect.new()
		icon.texture = texture_resource
		icon.position = icon_position
		icon.size = icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(icon)

		var label := Label.new()
		label.text = String(entry["label"])
		label.position = Vector2(0.0, label_top)
		label.size = Vector2(section_width, label_height)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		if outfit_semibold != null:
			label.add_theme_font_override("font", outfit_semibold)
		label.add_theme_color_override(
			"font_color",
			Color("#3528BD") if is_active else Color("#454698")
		)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(label)

		var navigation_button := Button.new()
		navigation_button.name = "%sNavigationButton" % String(entry["label"]).capitalize().replace(" ", "")
		navigation_button.position = Vector2.ZERO
		navigation_button.size = item.size
		navigation_button.flat = true
		navigation_button.focus_mode = Control.FOCUS_NONE
		navigation_button.mouse_filter = Control.MOUSE_FILTER_STOP
		navigation_button.pressed.connect(
			_on_navigation_button_pressed.bind(String(entry["label"]))
		)
		item.add_child(navigation_button)

	return root


func _on_navigation_button_pressed(label_text: String) -> void:
	var screen_id := label_text.to_lower().replace(" ", "_")
	screen_requested.emit(screen_id)


func _on_time_button_pressed(button: TextureButton) -> void:
	var speed_key: String = String(button.get_meta("speed_key", "play"))

	match speed_key:
		"pause":
			TimeManager.pause()
		"x2":
			TimeManager.set_speed_multiplier(2.0)
			TimeManager.play()
		"x3":
			TimeManager.set_speed_multiplier(3.0)
			TimeManager.play()
		_:
			TimeManager.set_speed_multiplier(1.0)
			TimeManager.play()

	_update_time_button_visuals()


func _update_time_button_visuals() -> void:
	if pause_button == null:
		return

	var active_key: String = "pause"
	if not TimeManager.is_paused:
		var speed: float = TimeManager.get_speed_multiplier()
		if is_equal_approx(speed, 3.0):
			active_key = "x3"
		elif is_equal_approx(speed, 2.0):
			active_key = "x2"
		else:
			active_key = "play"

	var buttons: Array[TextureButton] = [pause_button, play_button, x2_button, x3_button]

	for button in buttons:
		if button == null:
			continue

		var speed_key: String = String(button.get_meta("speed_key", ""))
		var is_active: bool = speed_key == active_key
		var texture_path: String = String(
			button.get_meta("active_path", "")
			if is_active
			else button.get_meta("inactive_path", "")
		)
		var texture_resource := _load_texture(texture_path)
		button.texture_normal = texture_resource
		button.texture_pressed = texture_resource
		button.texture_hover = texture_resource
		button.texture_disabled = texture_resource

		var shadow := button.get_node_or_null("DropShadow") as TextureRect
		if shadow != null:
			shadow.texture = texture_resource


func reset_tree_view() -> void:
	if family_tree_camera != null and family_tree_camera.has_method("reset_view"):
		family_tree_camera.call("reset_view")


func _update_layout() -> void:
	if background_root != null:
		background_root.size = size
	if fixed_ui_root != null:
		fixed_ui_root.size = size
	_center_tree_background()
	_layout_fixed_ui()


func _center_tree_background() -> void:
	if center_tree_rect == null:
		return

	var texture_size := Vector2(921.0, 1024.0)
	if center_tree_rect.texture != null:
		texture_size = center_tree_rect.texture.get_size()

	var target_width: float = minf(size.x * 0.86, 920.0)
	var aspect: float = texture_size.y / maxf(texture_size.x, 1.0)
	var target_height: float = target_width * aspect

	if target_height > size.y * 0.62:
		target_height = size.y * 0.62
		target_width = target_height / aspect

	center_tree_rect.size = Vector2(target_width, target_height)
	center_tree_rect.position = (size - center_tree_rect.size) * 0.5


func _layout_fixed_ui() -> void:
	if date_pill != null:
		date_pill.position = Vector2(SIDE_MARGIN, TOP_MARGIN)
	if shop_block != null:
		shop_block.position = Vector2(20.0, 180.0)
	if settings_block != null:
		settings_block.position = Vector2(20.0, 180.0 + shop_block.size.y + SHOP_SETTINGS_GAP)
	if coin_pill != null:
		coin_pill.position = Vector2(size.x - SIDE_MARGIN - coin_pill.size.x, TOP_MARGIN)
	if diamond_pill != null:
		diamond_pill.position = Vector2(size.x - SIDE_MARGIN - diamond_pill.size.x, TOP_MARGIN + coin_pill.size.y + 22.0)
	if nav_root != null:
		nav_root.position = Vector2((size.x - nav_root.size.x) * 0.5, size.y - NAV_BOTTOM_MARGIN - nav_root.size.y)
	if time_control_root != null:
		time_control_root.position = Vector2((size.x - time_control_root.size.x) * 0.5, size.y - TIME_CONTROL_BOTTOM_MARGIN - time_control_root.size.y)


func _format_compact_number(value: int) -> String:
	var absolute_value: int = absi(value)
	var prefix: String = "-" if value < 0 else ""

	if absolute_value >= 1000000000:
		return prefix + _format_short_decimal(float(absolute_value) / 1000000000.0) + "B"
	if absolute_value >= 1000000:
		return prefix + _format_short_decimal(float(absolute_value) / 1000000.0) + "M"
	if absolute_value >= 1000:
		return prefix + _format_short_decimal(float(absolute_value) / 1000.0) + "k"

	return str(value)


func _format_short_decimal(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%.1f" % value


func _make_stylebox(
	bg_color: Color,
	radius: float,
	shadow_color: Color,
	shadow_offset: Vector2,
	shadow_size: int
) -> StyleBoxFlat:
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


func _load_texture(resource_path: String) -> Texture2D:
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		return null
	return load(resource_path) as Texture2D
