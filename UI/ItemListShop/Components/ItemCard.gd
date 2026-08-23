extends PanelContainer
class_name ItemListShopCard


signal action_requested(item_reference: Variant)


enum Mode {
	SHOP,
	OWNED,
	EQUIPPED,
}

const ICON_FOLDER := "res://Resources/Icons/item-list-shop/"
const CURRENCY_FOLDER := "res://Resources/Icons/main-ui/"
const FONT_REGULAR := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"
const FONT_EXTRA_BOLD := "res://Resources/Fonts/Roboto-ExtraBold.ttf"

const COLOR_CARD := Color("#FFFDFC")
const COLOR_BORDER := Color("#EEDFD4")
const COLOR_TEXT := Color("#1E1E1E")
const COLOR_BROWN := Color("#6D4534")
const COLOR_GREEN := Color("#63AA7D")
const COLOR_PROGRESS_BG := Color("#F3E2D8")

const RARITY_COLORS := {
	"common": Color("#777777"),
	"uncommon": Color("#4F9569"),
	"rare": Color("#28579B"),
	"epic": Color("#7B4A98"),
	"legendary": Color("#FF9147"),
}

var item_data: Dictionary = {}
var mode: Mode = Mode.OWNED
var action_button: Button
var rarity_badge: PanelContainer
var rarity_label: Label
var rarity_crown: TextureRect
var durability_slot: Control
var durability_row: HBoxContainer
var durability_label: Label
var durability_bar: ProgressBar
var price_row: HBoxContainer


func _ready() -> void:
	if item_data.is_empty():
		_build_interface()


func configure(new_item_data: Dictionary, new_mode: Mode) -> void:
	item_data = new_item_data.duplicate(true)
	mode = new_mode
	_build_interface()


func request_action() -> void:
	action_requested.emit(get_item_reference())


func get_item_reference() -> Variant:
	if mode == Mode.SHOP:
		return item_data.get("item_id", item_data.get("catalog_item_id", null))
	return item_data.get("instance_id", item_data.get("item_id", null))


func get_display_snapshot() -> Dictionary:
	var currencies: Array[String] = []
	var is_heirloom := bool(item_data.get("is_heirloom", false))
	var money_price := int(item_data.get("money_price", 0))
	var diamond_price := int(item_data.get("diamond_price", 0))
	if mode == Mode.SHOP:
		if is_heirloom:
			if diamond_price > 0:
				currencies.append("diamond")
		else:
			if diamond_price > 0:
				currencies.append("diamond")
			if money_price > 0:
				currencies.append("money")
	return {
		"mode": Mode.keys()[mode],
		"item_reference": get_item_reference(),
		"rarity": str(item_data.get("rarity", "common")).to_lower(),
		"is_heirloom": is_heirloom,
		"crown_inside_badge": rarity_crown != null and rarity_crown.visible,
		"durability_visible": durability_row != null and durability_row.visible,
		"durability_space_reserved": durability_slot != null and durability_slot.custom_minimum_size.y > 0.0,
		"durability_percent": int(round(float(item_data.get("durability_percent", -1.0)))),
		"currencies": currencies,
		"category": _resolve_category(),
		"action": _action_text(),
		"action_y": action_button.position.y if action_button != null else -1.0,
	}


func _build_interface() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_stylebox_override("panel", _make_style(COLOR_CARD, 24, COLOR_BORDER, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title := _make_label(
		str(item_data.get("display_name", "Item")).to_upper(),
		30,
		FONT_EXTRA_BOLD,
		COLOR_TEXT
	)
	title.custom_minimum_size = Vector2(0.0, 42.0)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(title)

	var image_panel := PanelContainer.new()
	image_panel.custom_minimum_size = Vector2(440.0, 328.0)
	image_panel.clip_contents = true
	image_panel.add_theme_stylebox_override("panel", _make_style(Color("#F3E8DF"), 17, Color.TRANSPARENT, 0))
	column.add_child(image_panel)
	var item_image := TextureRect.new()
	var image_path := str(item_data.get("image_path", ""))
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		item_image.texture = load(image_path) as Texture2D
	item_image.custom_minimum_size = Vector2(440.0, 328.0)
	item_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	item_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_panel.add_child(item_image)

	var category_badge_row := HBoxContainer.new()
	category_badge_row.add_theme_constant_override("separation", 10)
	column.add_child(category_badge_row)
	_add_category(category_badge_row)
	var category_spacer := Control.new()
	category_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_badge_row.add_child(category_spacer)
	_add_rarity_badge(category_badge_row)

	var lifestyle_row := HBoxContainer.new()
	lifestyle_row.add_theme_constant_override("separation", 8)
	column.add_child(lifestyle_row)
	var lifestyle_icon := _make_texture(ICON_FOLDER + "lifestyle_star.svg", Vector2(32.0, 32.0))
	lifestyle_row.add_child(lifestyle_icon)
	var lifestyle_value := int(item_data.get("lifestyle_value", 0))
	lifestyle_row.add_child(_make_label("+%d" % lifestyle_value, 28, FONT_BOLD, COLOR_TEXT))

	_add_durability(column)
	_add_price(column)

	action_button = Button.new()
	action_button.name = "%sButton" % _action_text()
	action_button.text = _action_text()
	action_button.custom_minimum_size = Vector2(0.0, 60.0)
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.add_theme_font_override("font", load(FONT_BOLD) as Font)
	action_button.add_theme_font_size_override("font_size", 24)
	var action_color := Color.WHITE if mode != Mode.EQUIPPED else COLOR_BROWN
	action_button.add_theme_color_override("font_color", action_color)
	action_button.add_theme_color_override("font_hover_color", action_color)
	action_button.add_theme_color_override("font_pressed_color", action_color)
	var action_style := (
		_make_style(COLOR_GREEN, 12, Color.TRANSPARENT, 0)
		if mode != Mode.EQUIPPED
		else _make_style(COLOR_CARD, 12, COLOR_BORDER, 1)
	)
	action_button.add_theme_stylebox_override("normal", action_style)
	action_button.add_theme_stylebox_override("hover", action_style)
	action_button.add_theme_stylebox_override("pressed", action_style)
	action_button.add_theme_stylebox_override("focus", action_style)
	action_button.add_theme_stylebox_override("disabled", action_style)
	action_button.disabled = mode == Mode.SHOP and not bool(item_data.get("purchase_available", true))
	action_button.pressed.connect(request_action)
	column.add_child(action_button)


func _add_category(parent: HBoxContainer) -> void:
	var category := _resolve_category()
	var icon_file := ""
	match category:
		"ring", "glasses", "watch", "necklace":
			icon_file = "%s-icon.svg" % category
		"outfit":
			icon_file = "outfit-icon.svg"
		"vehicle":
			icon_file = "vehicle-icon.svg"
	if not icon_file.is_empty():
		parent.add_child(_make_texture(ICON_FOLDER + icon_file, Vector2(28.0, 28.0)))
	parent.add_child(_make_label(category.capitalize() if not category.is_empty() else "Item", 24, FONT_REGULAR, COLOR_TEXT))


func _add_rarity_badge(parent: HBoxContainer) -> void:
	var rarity := str(item_data.get("rarity", "common")).to_lower()
	rarity_badge = PanelContainer.new()
	rarity_badge.add_theme_stylebox_override(
		"panel",
		_make_style(RARITY_COLORS.get(rarity, RARITY_COLORS["common"]), 9, Color.TRANSPARENT, 0)
	)
	parent.add_child(rarity_badge)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	rarity_badge.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	margin.add_child(row)
	rarity_crown = _make_texture(ICON_FOLDER + "heirloom_rarity_icon.svg", Vector2(20.0, 20.0))
	rarity_crown.visible = bool(item_data.get("is_heirloom", false))
	row.add_child(rarity_crown)
	rarity_label = _make_label(rarity.to_upper(), 18, FONT_BOLD, Color.WHITE)
	row.add_child(rarity_label)


func _add_durability(parent: VBoxContainer) -> void:
	durability_slot = MarginContainer.new()
	durability_slot.name = "DurabilitySlot"
	durability_slot.custom_minimum_size = Vector2(0.0, 32.0)
	durability_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(durability_slot)
	durability_row = HBoxContainer.new()
	durability_row.name = "DurabilityContent"
	durability_row.add_theme_constant_override("separation", 12)
	durability_slot.add_child(durability_row)
	var is_heirloom := bool(item_data.get("is_heirloom", false))
	var percent := float(item_data.get("durability_percent", -1.0))
	durability_row.visible = not is_heirloom and percent >= 0.0
	if not durability_row.visible:
		return
	var durability_title := _make_label("Durability", 22, FONT_REGULAR, COLOR_BROWN)
	durability_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	durability_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	durability_row.add_child(durability_title)
	durability_label = _make_label("%d/100" % int(round(percent)), 22, FONT_REGULAR, COLOR_BROWN)
	durability_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	durability_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	durability_row.add_child(durability_label)
	durability_bar = ProgressBar.new()
	durability_bar.custom_minimum_size = Vector2(0.0, 15.0)
	durability_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	durability_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	durability_bar.max_value = 100.0
	durability_bar.value = clampf(percent, 0.0, 100.0)
	durability_bar.show_percentage = false
	durability_bar.add_theme_stylebox_override("background", _make_style(COLOR_PROGRESS_BG, 8, Color.TRANSPARENT, 0))
	durability_bar.add_theme_stylebox_override("fill", _make_style(COLOR_GREEN, 8, Color.TRANSPARENT, 0))
	durability_row.add_child(durability_bar)


func _add_price(parent: VBoxContainer) -> void:
	price_row = HBoxContainer.new()
	price_row.name = "PriceSlot"
	price_row.custom_minimum_size = Vector2(0.0, 32.0)
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 24)
	parent.add_child(price_row)
	price_row.visible = mode == Mode.SHOP
	if not price_row.visible:
		return
	var is_heirloom := bool(item_data.get("is_heirloom", false))
	var money_price := int(item_data.get("money_price", 0))
	var diamond_price := int(item_data.get("diamond_price", 0))
	if is_heirloom:
		if diamond_price > 0:
			_add_currency(price_row, "diamond.png", diamond_price)
		return
	if diamond_price > 0:
		_add_currency(price_row, "diamond.png", diamond_price)
	if money_price > 0:
		_add_currency(price_row, "coin.png", money_price)


func _add_currency(parent: HBoxContainer, icon_file: String, value: int) -> void:
	var entry := HBoxContainer.new()
	entry.add_theme_constant_override("separation", 8)
	parent.add_child(entry)
	entry.add_child(_make_texture(CURRENCY_FOLDER + icon_file, Vector2(32.0, 32.0)))
	entry.add_child(_make_label(_format_number(value), 27, FONT_REGULAR, COLOR_BROWN))


func _resolve_category() -> String:
	var explicit_category := str(item_data.get("conceptual_category", "")).to_lower()
	if not explicit_category.is_empty():
		return explicit_category
	var slot := str(item_data.get("slot", "")).to_lower()
	if slot == "accessory":
		return AccessoryCategoryClassifier.classify(item_data)
	return slot


func _action_text() -> String:
	match mode:
		Mode.SHOP:
			return "Buy"
		Mode.EQUIPPED:
			return "Unequip"
		_:
			return "Wear"


func _format_number(value: int) -> String:
	var raw := str(absi(value))
	var result := ""
	while raw.length() > 3:
		result = "," + raw.right(3) + result
		raw = raw.left(raw.length() - 3)
	return ("-" if value < 0 else "") + raw + result


func _make_texture(path: String, minimum_size: Vector2) -> TextureRect:
	var texture := TextureRect.new()
	if ResourceLoader.exists(path):
		texture.texture = load(path) as Texture2D
	texture.custom_minimum_size = minimum_size
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture


func _make_label(text_value: String, font_size: int, font_path: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", load(font_path) as Font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


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
